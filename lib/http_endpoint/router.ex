defmodule HttpEndpoint.Router do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, """
    Use the JavaScript console to interact using websockets

    sock  = new WebSocket("ws://localhost:4000/websocket")
    sock.addEventListener("message", console.log)
    sock.addEventListener("open", () => sock.send("ping"))
    """)
  end

  get "/device" do
    devices = DeviceRegistry.get_device_ids()
    send_resp(conn, 200, Poison.encode!(devices))
  end

  get "/device/:id" do
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    # remove history to reduce payload size
    device = Map.delete(device, :waterlevel_history)
    send_resp(conn, 200, Poison.encode!(device))
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
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    history = device.waterlevel_history
    send_resp(conn, 200, Poison.encode!(history))
  end

  get "device/:id/history/last" do
    id = conn.params["id"]
    device = DeviceRegistry.get(id)
    history = device.waterlevel_history
    last = List.last(history)
    send_resp(conn, 200, Poison.encode!(last))
  end

  get "device/:id/history/last/:count" do
    id = conn.params["id"]
    count = String.to_integer(conn.params["count"])
    device = DeviceRegistry.get(id)
    history = device.waterlevel_history |> Enum.reverse |> Enum.take(count) |> Enum.reverse
    send_resp(conn, 200, Poison.encode!(history))
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
