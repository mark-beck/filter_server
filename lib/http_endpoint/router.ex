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

  match _ do
    send_resp(conn, 404, "not found")
  end
end
