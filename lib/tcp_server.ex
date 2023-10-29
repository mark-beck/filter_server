defmodule TcpServer do
  require Logger

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [
          :binary,
          packet: :raw,
          active: false,
          reuseaddr: true,
          send_timeout: 5000,
          send_timeout_close: true
        ]
      )

    Logger.info("Accepting connctions on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} = Task.Supervisor.start_child(TcpServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(client) do
    Logger.debug("waiting for data")
    {:ok, data} = :gen_tcp.recv(client, 0)

    case Message.decode_message(data) do
      {:register, register} ->
        Logger.info("Registering device #{register.id}")
        DeviceRegistry.register_device(register)

        accepted =
          if register.needs_config do
            config = DeviceRegistry.get(register.id).config

            %{
              time: DateTime.utc_now(:millisecond) |> DateTime.to_unix(:millisecond),
              config_following: true,
              config: config
            }
          else

            %{
              time: DateTime.utc_now(:milisecond) |> DateTime.to_unix(:millisecond),
              config_following: false
            }
          end

        message = Message.encode_message({:accepted, accepted})
        :ok = :gen_tcp.send(client, message)
        :gen_tcp.close(client)

      {:heartbeat, heartbeat} ->
        Logger.info("Heartbeat from device #{heartbeat.id}")
        command = DeviceRegistry.heartbeat_device(heartbeat)

        message = {:heartbeat_response, command} |> Message.encode_message

        :gen_tcp.send(client, message)

        :gen_tcp.close(client)
    end
  end
end
