defmodule SaveRegistry do
  require Logger
  use GenServer

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  @impl true
  def init(state) do
    :timer.send_interval(60_000 * 5, :work)
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    save_registry()
    {:noreply, state}
  end

  defp save_registry do
    :ok = :ets.tab2file(:device_registry, :device_registry)
    Logger.info("Saved registry")
  end

  def restore_registry do
    Logger.info("Restoring registry")
    :ets.file2tab(:device_registry)
  end
end
