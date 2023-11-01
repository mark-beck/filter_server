defmodule HttpEndpoint.Apiv1.Router do
  require Logger
  use Plug.Router

  plug :match
  plug :dispatch

  get "/device" do
    devices = DeviceRegistry.get_device_ids()
    send_resp(conn, 200, Poison.encode!(devices))
  end

  get "/device/:id" do
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    # remove unnecessary data
    device = Map.delete(device, :state_history)
    device = Map.delete(device, :config)
    device = Map.delete(device, :command)

    send_resp(conn, 200, Poison.encode!(device))
  end

  get "/device/:id/config" do
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    config = device.config
    send_resp(conn, 200, Poison.encode!(config))
  end

  get "/device/:id/ws" do
    id = conn.params["id"]
    conn
    |> WebSockAdapter.upgrade(HttpEndpoint.WebsockHandler, id, timeout: 60_000)
    |> halt()
  end

  get "/device/:id/wspage" do
    id = conn.params["id"]
    send_resp(conn, 200, """
    <!DOCTYPE html>

    <html>
      <head>
        <meta charset="utf-8">
        <title>WebSocket</title>
        <script>
          sock  = new WebSocket("ws://localhost:4000/device/#{id}/ws")
          sock.addEventListener("message", console.log)
          sock.addEventListener("open", () => sock.send("ping"))
        </script>
      </head>
      <body>
      </body>
    """
    )
  end

  get "device/:id/history" do
    conn = fetch_query_params(conn)
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    history = device.state_history

    # filter history with timestamps
    from = conn.params["from"]
    to = conn.params["to"]
    history = if from do
      from = String.to_integer(from)
      Enum.filter(history, fn x -> x.time >= from end)
    else
      history
    end

    history = if to do
      to = String.to_integer(to)
      Enum.filter(history, fn x -> x.time <= to end)
    else
      history
    end

    send_resp(conn, 200, Poison.encode!(history))
  end

  get "device/:id/history/last" do
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    history = device.device_history
    last = List.last(history)
    send_resp(conn, 200, Poison.encode!(last))
  end

  get "device/:id/history/last/:count" do
    id = conn.params["id"]
    count = String.to_integer(conn.params["count"])
    device = DeviceRegistry.get(id)
    history = device.device_history |> Enum.reverse |> Enum.take(count) |> Enum.reverse
    send_resp(conn, 200, Poison.encode!(history))
  end

  get "device/:id/setname/:name" do
    id = conn.params["id"]
    name = conn.params["name"]
    DeviceRegistry.set_name(id, name)
    send_resp(conn, 200, "")
  end

  forward "/device/:id/command", to: HttpEndpoint.Apiv1.Command

  match _ do
    send_resp(conn, 404, "not found")
  end
end
