defmodule HttpEndpoint.Apiv1.Command do
  require Logger
  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  post "/forcestate" do
    id = conn.params["id"]

    # verify that state and time are present and valid
    %{"state" => state, "time" => time} = conn.body_params
    true = ["idle", "clean", "fill"] |> Enum.member?(state)
    true = is_integer(time)

    command = %{
      command_type: :force_state,
      payload: %{
        state: state,
        time: time
      }
    }

    DeviceRegistry.set_command(id, command)
    send_resp(conn, 200, "")
  end

  post "/setconfig" do
    id = conn.params["id"]

    %{
      "waterlevel_fill_start" => water_fill_start,
      "waterlevel_fill_end" => water_fill_end,
      "clean_before_fill_duration" => clean_before_fill_duration,
      "clean_after_fill_duration" => clean_after_fill_duration,
      "leak_protection" => leak_protection
    } = conn.body_params

    true = is_integer(water_fill_start)
    true = is_integer(water_fill_end)
    true = is_integer(clean_before_fill_duration)
    true = is_integer(clean_after_fill_duration)
    true = is_boolean(leak_protection)

    config = %{
      waterlevel_fill_start: water_fill_start,
      waterlevel_fill_end: water_fill_end,
      clean_before_fill_duration: clean_before_fill_duration,
      clean_after_fill_duration: clean_after_fill_duration,
      leak_protection: leak_protection
    }

    command = %{
      command_type: :update_config,
      payload: config
    }

    DeviceRegistry.set_command(id, command)

    send_resp(conn, 200, "")
  end
end
