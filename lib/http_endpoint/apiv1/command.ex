defmodule HttpEndpoint.Apiv1.Command do
  require Logger
  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison
  plug :dispatch

  post "/forcestate" do
    id = conn.params["id"]

    case conn.body_params do
      %{"state" => state, "time" => time} ->
        true = ["idle", "clean", "fill"] |> Enum.member?(state)
        time = String.to_integer(time)
        command = %{
          command_type: :force_state,
          payload: %{
            state: state,
            time: time
          }
        }
        DeviceRegistry.set_command(id, command)
        send_resp(conn, 200, "")
      _ ->
        send_resp(conn, 400, "Bad request")
      end
  end
end
