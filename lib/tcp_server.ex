defmodule TcpServer do
require Logger

  def accept(port) do
    {:ok, socket}
      = :gen_tcp.listen(
        port,
        [:binary, packet: :raw, active: false, reuseaddr: true, send_timeout: 5000, send_timeout_close: true])

    Logger.info("Accepting connctions on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    Logger.info("waiting for connection")
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("waiting for data")
    data = :gen_tcp.recv(client, 0)
    case Message.decode_message(data) do
      {:register, register} ->
        DeviceRegistry.register_device(register)

        accepted = if register.needs_config do
          Logger.info("sending config")
          config = DeviceRegistry.get(register.id).config
          %{
            time: DateTime.utc_now(:milisecond),
            config_following: true,
            config: config
          }
        else
          Logger.info("sending no config")
          %{
            time: DateTime.utc_now(:milisecond),
            config_following: false,
          }

        end
        message = Message.encode_message({:accepted, accepted})
        :gen_tcp.send(client, message)
        :gen_tcp.close(client)

        loop_acceptor(socket)
      _ ->
        Logger.info("got bad heartbeat")
        loop_acceptor(socket)
    end
  end

end
