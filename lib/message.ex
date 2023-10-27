defmodule Message do
  import Logger

  @type message_header :: %{
          magic: <<_::4, _::_*8>>,
          type: :register | :accepted | :heartbeat | :heartbeat_response,
          length: integer()
        }

  @type config :: %{
          waterlevel_fill_start: integer,
          waterlevel_fill_end: integer,
          clean_before_fill_duration: integer,
          clean_after_fill_duration: integer,
          leak_protection: boolean
        }

  @type register :: %{
          id: String.t(),
          token: String.t(),
          type: Integer.t(),
          firmware_version: Integer.t(),
          needs_config: boolean
        }

  @type accepted :: %{
          time: integer(),
          config_following: boolean(),
          config: config()
        }

  @type heartbeat :: %{
          id: integer(),
          time: integer(),
          filter_state: filter_state(),
          last_state_change: integer(),
          waterlevel: integer(),
          measurement_error: boolean(),
          measurement_error_occured: integer(),
          measurement_error_count: integer(),
          leak: boolean(),
          leak_occured: integer()
        }

  @type heartbeat_response :: %{
          command_type:
            :none
            | :force_state
            | :resync_time
            | :update_config
            | :set_reset_leak
            | :reset_measurement_error
            | :load_firmware
            | :reset_device,
          payload: force_state() | resync_time() | set_leak() | config() | none()
        }

  @type force_state :: %{
          state: :fill | :clean | :fill,
          time: integer()
        }

  @type resync_time :: %{
          time: integer()
        }

  @type set_leak :: integer()

  @type filter_state ::
          :idle
          | :cleanBeforeFill
          | :cleanAfterFill
          | :fill
          | {:forcedIdle, number}
          | {:forcedClean, number}
          | {:forcedFill, number}

  @spec decode_message(binary()) :: {:register | :heartbeat, register() | heartbeat()}
  def decode_message(bytes) do
    <<magic::binary-size(4), type, length::binary-size(4), body::binary>> = bytes

    length = :binary.decode_unsigned(length)
    Logger.debug("length field: #{length}")
    Logger.debug("length of array: #{byte_size(bytes)}")

    if length != byte_size(bytes) do
      raise "wrong_size"
    end

    if magic != <<0xFA, 0xFA, 0xFA, 0xFF>> do
      raise "wrong_magic"
    end

    result =
      case type do
        0x01 -> {:register, decode_register(body)}
        0x03 -> {:heartbeat, decode_heartbeat(body)}
        _ -> raise "wrong_type"
      end

    Logger.info("decoded #{inspect(result)}")
    result
  end

  @spec decode_register(binary()) :: register()
  def decode_register(body) do
    <<id::binary-size(32), token::binary-size(32), type::binary-size(1), firmware::binary-size(2),
      needs_config::binary-size(1), _rest::integer>> = body

    %{
      id: id,
      token: token,
      type: :binary.decode_unsigned(type),
      firmware_version: :binary.decode_unsigned(firmware),
      needs_config: 1 == :binary.decode_unsigned(needs_config)
    }
  end

  @spec decode_heartbeat(binary()) :: heartbeat()
  def decode_heartbeat(body) do
    <<id::binary-size(32), time::binary-size(8), state::binary-size(1),
      forced_time_left::binary-size(8), last_state_change::binary-size(8),
      waterlevel::binary-size(8), measurement_error::binary-size(1),
      measurement_error_occured::binary-size(8), measurement_error_count::binary-size(4),
      leak::binary-size(1), leak_occured::binary-size(8), _rest>> = body

    %{
      id: :binary.decode_unsigned(id),
      time: :binary.decode_unsigned(time),
      filter_state: decode_filter_state(state, forced_time_left),
      last_state_change: :binary.decode_unsigned(last_state_change),
      waterlevel: :binary.decode_unsigned(waterlevel),
      measurement_error: 1 == :binary.decode_unsigned(measurement_error),
      measurement_error_occured: :binary.decode_unsigned(measurement_error_occured),
      measurement_error_count: :binary.decode_unsigned(measurement_error_count),
      leak: 1 == :binary.decode_unsigned(leak),
      leak_occured: :binary.decode_unsigned(leak_occured)
    }
  end

  @spec decode_filter_state(binary(), binary()) :: filter_state()
  def decode_filter_state(state, forced_time_left) do
    case :binary.decode_unsigned(state) do
      0 -> :idle
      1 -> :cleanBeforeFill
      2 -> :cleanAfterFill
      3 -> :fill
      4 -> {:forcedFill, :binary.decode_unsigned(forced_time_left)}
      5 -> {:forcedClean, :binary.decode_unsigned(forced_time_left)}
      6 -> {:forcedIdle, :binary.decode_unsigned(forced_time_left)}
      _ -> raise "wrong_state"
    end
  end

  def encode_message(message) do
    body =
      case message do
        {:accepted, accepted} -> encode_accepted(accepted)
        {:heartbeat_response, hb_response} -> encode_response(hb_response)
        _ -> raise "Unknown message"
      end

    <<
      0xFA,
      0xFA,
      0xFA,
      0xFF,
      case message do
        {:accepted, _} -> 0x02
        {:heartbeat_response, _} -> 0x04
        _ -> raise "Unknown message"
      end,
      byte_size(body)::integer-32,
      body::binary
    >>
  end

  def encode_accepted(accepted) do
    if accepted.config_following do
      config = encode_config(accepted.config)

      <<
        accepted.time::integer-64,
        0x01,
        config::binary
      >>
    else
      <<
        accepted.time::integer-64,
        0x00
      >>
    end
  end

  @spec encode_config(config()) :: binary()
  def encode_config(config) do
    leak_protection =
      if config.leak_protection do
        1
      else
        0
      end

    <<
      config.waterlevel_fill_start::integer-64,
      config.waterlevel_fill_end::integer-64,
      config.clean_before_fill_duration::integer-64,
      config.clean_after_fill_duration::integer-64,
      leak_protection::integer-8
    >>
  end

  def encode_response(_response) do
    raise("unimplemented")
  end
end
