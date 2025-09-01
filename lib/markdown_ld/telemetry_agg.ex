defmodule MarkdownLd.TelemetryAgg do
  @moduledoc """
  Optional in-process telemetry aggregator for MarkdownLd performance metrics.

  Usage:
    {:ok, _pid} = MarkdownLd.TelemetryAgg.start_link()
    MarkdownLd.TelemetryAgg.attach()
    # run workload
    IO.inspect(MarkdownLd.TelemetryAgg.summary())
  """

  use GenServer

  # Client API
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  def attach do
    :telemetry.attach_many(
      'markdown_ld_agg',
      [
        [:markdown_ld, :jsonld, :single_pass],
        [:markdown_ld, :jsonld, :extract],
        [:markdown_ld, :jsonld, :expand],
        [:markdown_ld, :jsonld, :skip],
        [:markdown_ld, :cache, :context],
        [:markdown_ld, :cache, :term]
      ],
      &__MODULE__.handle_event/4,
      %{}
    )
  end
  def detach, do: :telemetry.detach('markdown_ld_agg')
  def summary, do: GenServer.call(__MODULE__, :summary)
  def reset, do: GenServer.call(__MODULE__, :reset)

  # Server
  @impl true
  def init(_), do: {:ok, %{counters: %{}, hist: []}}

  @impl true
  def handle_call(:summary, _from, %{counters: c, hist: h} = s) do
    {:reply, %{counters: c, samples: length(h), p95_us: p95(h)}, s}
  end
  def handle_call(:reset, _from, _s), do: {:reply, :ok, %{counters: %{}, hist: []}}

  @impl true
  def handle_info(_msg, s), do: {:noreply, s}

  @impl true
  def handle_cast({:inc, key, n}, %{counters: c} = s) do
    {:noreply, %{s | counters: Map.update(c, key, n, &(&1 + n))}}
  end
  def handle_cast({:obs, us}, %{hist: h} = s) do
    {:noreply, %{s | hist: [us | h]}}
  end

  # Telemetry handler
  def handle_event([:markdown_ld, :jsonld, :single_pass], meas, _meta, _config) do
    # Track distribution of single-pass durations
    safe_cast({:obs, meas[:duration_us] || 0})
  end
  def handle_event([:markdown_ld, :jsonld, :skip], meas, _meta, _config) do
    safe_cast({:inc, :skip, meas[:skipped] || 1})
  end
  def handle_event([:markdown_ld, :cache, :context], meas, _meta, _config) do
    if meas[:hit], do: safe_cast({:inc, :ctx_hit, 1})
    if meas[:miss], do: safe_cast({:inc, :ctx_miss, 1})
  end
  def handle_event([:markdown_ld, :cache, :term], meas, _meta, _config) do
    if meas[:hit], do: safe_cast({:inc, :term_hit, 1})
    if meas[:miss], do: safe_cast({:inc, :term_miss, 1})
  end
  def handle_event(_ev, _meas, _meta, _config), do: :ok

  defp safe_cast(msg) do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.cast(pid, msg)
    end
  end

  defp p95(list) when is_list(list) and list != [] do
    sorted = Enum.sort(list)
    idx = Float.ceil(0.95 * length(sorted)) |> trunc() |> max(1)
    Enum.at(sorted, idx - 1)
  end
  defp p95(_), do: 0
end

