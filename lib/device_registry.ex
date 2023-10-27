defmodule DeviceRegistry do
  use GenServer

  ## Types


  @type device_map :: %{
    id: String.t,
    token: String.t,
    type: Integer.t,
    firmware_version: Integer.t,
    waterlevel_history: [%{ time: integer, height: integer, state: Message.filter_state }],
    last_seen: integer,
    config: Message.config,
    measurement_error: boolean(),
    measurement_error_occured: integer(),
    measurement_error_count: integer(),
    leak: boolean(),
    leak_occured: integer()
  }


  ## API

  @spec add_device(device_map()) :: no_return()
  def add_device(device) do
    :ets.insert(:device_registry, {device.id, device})
  end

  @spec register_device(Message.register()) :: no_return()
  def register_device(message) do

    current_timestamp = DateTime.utc_now(:millisecond)

    # check if device is already known
    device = case :ets.lookup(:device_registry, message.id) do
      [{_id, device}] ->
        # TODO: check if tokens match
        %{ device | firmware_version: message.firmware_version, last_seen: current_timestamp}
      [] ->
        # TODO: validate token
        %{
          id: message.id,
          token: message.token,
          type: message.type,
          firmware_version: message.firmware_version,
          waterlevel_history: [],
          last_seen: current_timestamp,
          config: default_conf(),
          measurement_error: false,
          measurement_error_occured: 0,
          measurement_error_count: 0,
          leak: false,
          leak_occured: 0
        }
    end
    :ets.insert(:device_registry, {message.id, device})
  end

  def heartbeat_device(message) do
    current_timestamp = DateTime.utc_now(:milisecond)

    # raise if device is not known
    # otherwise update
    case :ets.lookup(:device_registry, message.id) do
      [{_id, device}] ->
        device = %{
          device |
          last_seen: current_timestamp,
          waterlevel_history: device.waterlevel_history ++ [%{
            time: current_timestamp,
            height: message.waterlevel,
            state: message.filter_state
          }],
          measurement_error: message.measurement_error,
          measurement_error_occured: message.measurement_error_occured,
          measurement_error_count: message.measurement_error_count,
          leak: message.leak,
          leak_occured: message.leak_occured
        }
        :ets.insert(:device_registry, {message.id, device})
      [] ->
        raise "Device not known"
    end
  end

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
    :ets.new(:device_registry, [:named_table, :public])
    {:ok, state}
  end

end
