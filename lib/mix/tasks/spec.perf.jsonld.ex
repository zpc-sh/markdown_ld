defmodule Mix.Tasks.Spec.Perf.Jsonld do
  use Mix.Task
  @shortdoc "Quick microbench: JSON-LD extract_triples over a corpus"
  @moduledoc """
  Usage:
    mix spec.perf.jsonld [--dir path] [--glob '**/*.md'] [--repeat 3]

  Runs JSON-LD extraction over all matching files, reporting total docs, total time,
  mean per doc, and 95th percentile.
  """

  alias MarkdownLd.JSONLD

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [dir: :string, glob: :string, repeat: :integer])
    dir = Keyword.get(opts, :dir, File.cwd!())
    glob = Keyword.get(opts, :glob, "**/*.md")
    repeat = Keyword.get(opts, :repeat, 3)

    files = Path.wildcard(Path.join([dir, glob]), match_dot: false)
    if files == [], do: Mix.raise("No files matched #{glob} under #{dir}")

    times =
      for _ <- 1..repeat, file <- files do
        doc = File.read!(file)
        {us, _} = :timer.tc(fn -> JSONLD.extract_triples(doc) end)
        us
      end

    stats = stats(times)
    IO.puts("docs=#{length(files)} runs=#{length(times)} total_ms=#{stats.total_ms} mean_us=#{stats.mean_us} p95_us=#{stats.p95_us}")
  end

  defp stats(times) do
    total_us = Enum.sum(times)
    n = max(length(times), 1)
    mean_us = div(total_us, n)
    p95_us = percentile(times, 95)
    %{total_ms: Float.round(total_us / 1000, 2), mean_us: mean_us, p95_us: p95_us}
  end

  defp percentile(list, p) do
    sorted = Enum.sort(list)
    idx = Float.ceil(p / 100 * length(sorted)) |> trunc() |> max(1)
    Enum.at(sorted, idx - 1)
  end
end

