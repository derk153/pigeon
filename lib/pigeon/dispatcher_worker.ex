defmodule Pigeon.DispatcherWorker do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(opts) do
    opts[:adapter] || raise "adapter is not specified"
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    Logger.info("Starting Pigeon.DispatcherWorker...")

    case opts[:adapter].init(opts) do
      {:ok, state} ->
        Process.flag(:trap_exit, true)
        Pigeon.Registry.register(opts[:supervisor])
        {:ok, %{adapter: opts[:adapter], state: state}}

      {:error, reason} ->
        {:error, reason}

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_info({:"$push", notification}, %{adapter: adapter, state: state}) do
    case adapter.handle_push(notification, state) do
      {:noreply, new_state} ->
        {:noreply, %{adapter: adapter, state: new_state}}

      {:stop, reason, new_state} ->
        Logger.warning("Pigeon.DispatcherWorker stopped: #{inspect(reason)}")

        {:stop, reason, %{adapter: adapter, state: new_state}}
    end
  end

  def handle_info({:EXIT, _from, reason} = msg, state) do
    Logger.warning("Pigeon.DispatcherWorker exited: #{inspect(msg)}")

    {:stop, reason, state}
  end

  def handle_info(msg, %{adapter: adapter, state: state}) do
    case adapter.handle_info(msg, state) do
      {:noreply, new_state} ->
        {:noreply, %{adapter: adapter, state: new_state}}

      {:stop, reason, new_state} ->
        Logger.warning("Pigeon.DispatcherWorker stopped: #{inspect(reason)}")

        {:stop, reason, %{adapter: adapter, state: new_state}}
    end
  end
end
