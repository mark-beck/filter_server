defmodule HttpEndpoint.WebsockHandler do
require Logger

  def init(id) do
    DeviceRegistry.get(id)
    PubSub.subscribe(self(), "device:#{id}")
    {:ok, %{id: id}}
  end

  def handle_in({"ping", [opcode: :text]}, state) do
    {:reply, :ok, {:text, "pong"}, state}
  end

  def handle_info({:update, dev_state}, state) do
    {:reply, :ok, {:text, Poison.encode!(dev_state)}, state}
  end

  def handle_info(param, state) do
    Logger.warning("Unknown message #{inspect(param)}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("Terminating websocket handler #{inspect(state)}, reason: #{inspect(reason)}")
    {:ok, state}
  end

end
