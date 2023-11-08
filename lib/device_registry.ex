defmodule DeviceRegistry do
  use GenServer

  ## Types

  @type device_state :: %{
          time: integer(),
          filter_state: Message.filter_state(),
          forced_time_left: integer(),
          last_state_change: integer(),
          waterlevel: integer(),
          measurement_error: boolean(),
          measurement_error_occured: integer(),
          measurement_error_count: integer(),
          leak: boolean(),
          leak_occured: integer()
        }

  @type device_map :: %{
          id: String.t(),
          name: String.t() | nil,
          baseline: integer() | nil,
          token: String.t(),
          type: Integer.t(),
          firmware_version: Integer.t(),
          state_history: [device_state()],
          last_seen: integer,
          config: Message.config(),
          command: Message.heartbeat_response()
        }

  ## API

  @spec get_device_ids() :: [integer()]
  def get_device_ids() do
    :ets.tab2list(:device_registry) |> Enum.map(fn {id, _} -> id end)
  end

  @spec add_device(device_map()) :: true
  def add_device(device) do
    :ets.insert(:device_registry, {device.id, device})
  end

  @spec register_device(Message.register()) :: true
  def register_device(message) do
    current_timestamp = DateTime.utc_now(:millisecond) |> DateTime.to_unix(:millisecond)

    # check if device is already known
    device =
      case :ets.lookup(:device_registry, message.id) do
        [{_id, device}] ->
          # TODO: check if tokens match
          %{device | firmware_version: message.firmware_version, last_seen: current_timestamp}

        [] ->
          # TODO: validate token
          %{
            id: message.id,
            name: nil,
            baseline: nil,
            token: message.token,
            type: message.type,
            firmware_version: message.firmware_version,
            state_history: [],
            last_seen: current_timestamp,
            config: default_conf(),
            command: %{command_type: :none}
          }
      end

    :ets.insert(:device_registry, {message.id, device})
  end

  @spec heartbeat_device(Message.heartbeat()) :: Message.heartbeat_response()
  def heartbeat_device(message) do
    current_timestamp = DateTime.utc_now(:millisecond) |> DateTime.to_unix(:millisecond)

    # raise if device is not known
    # otherwise update
    case :ets.lookup(:device_registry, message.id) do
      [{_id, device}] ->
        # send pubsub message
        PubSub.publish("device:#{message.id}", {:update, message})

        command = device.command

        device = %{
          device
          | last_seen: current_timestamp,
            state_history: [
              %{
                time: current_timestamp,
                waterlevel: message.waterlevel,
                filter_state: message.filter_state,
                last_state_change: message.last_state_change,
                measurement_error: message.measurement_error,
                measurement_error_occured: message.measurement_error_occured,
                measurement_error_count: message.measurement_error_count,
                leak: message.leak,
                leak_occured: message.leak_occured
              }
              | device.state_history
            ],
            command: %{command_type: :none}
        }

        :ets.insert(:device_registry, {message.id, device})
        command

      [] ->
        raise "Device not known"
    end
  end

  @spec set_name(String.t(), String.t()) :: true
  def set_name(id, name) do
    case :ets.lookup(:device_registry, id) do
      [{_id, device}] ->
        device = %{device | name: name}

        :ets.insert(:device_registry, {id, device})

      [] ->
        raise "Device not known"
    end
  end

  @spec set_baseline(String.t(), integer()) :: true
  def set_baseline(id, baseline) do
    case :ets.lookup(:device_registry, id) do
      [{_id, device}] ->
        device = %{device | baseline: baseline}

        :ets.insert(:device_registry, {id, device})

      [] ->
        raise "Device not known"
    end
  end

  @spec set_command(String.t(), Message.heartbeat_response()) :: true
  def set_command(id, command) do
    case :ets.lookup(:device_registry, id) do
      [{_id, device}] ->
        device = %{device | command: command}

        :ets.insert(:device_registry, {id, device})

      [] ->
        raise "Device not known"
    end
  end

  @spec get(String.t()) :: device_map()
  def get(id) do
    case :ets.lookup(:device_registry, id) do
      [{_id, device}] ->
        device

      [] ->
        raise "Device not known"
    end
  end

  @spec default_conf() :: Message.config()
  def default_conf() do
    %{
      waterlevel_fill_start: 500,
      waterlevel_fill_end: 50,
      clean_before_fill_duration: 10000,
      clean_after_fill_duration: 10000,
      leak_protection: true
    }
  end

  ## GenServer callbacks

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  @impl true
  def init(state) do
    case SaveRegistry.restore_registry() do
      {:ok, _} ->
        :ok

      {:error, _} ->
        :ets.new(:device_registry, [:named_table, :public])
    end

    {:ok, state}
  end
end
