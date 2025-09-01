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
    {opts, _, _} = OptionParser.parse(argv, switches: [
      dir: :string,
      glob: :string,
      repeat: :integer,
      backend: :string,
      telemetry: :boolean,
      sources: :string
    ])
    dir = Keyword.get(opts, :dir, File.cwd!())
    glob = Keyword.get(opts, :glob, "**/*.md")
    repeat = Keyword.get(opts, :repeat, 3)
    backend = Keyword.get(opts, :backend)
    sources = Keyword.get(opts, :sources)
    use_tel = Keyword.get(opts, :telemetry, false)

    if backend do
      case backend do
        "internal" -> Application.put_env(:markdown_ld, :jsonld_backend, :internal)
        "jsonld_ex" -> Application.put_env(:markdown_ld, :jsonld_backend, :jsonld_ex)
        other -> Mix.raise("Unknown --backend #{other} (expected internal|jsonld_ex)")
      end
    end

    if sources do
      set =
        sources
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_atom/1)
      Application.put_env(:markdown_ld, :jsonld_sources, set)
    end

    if use_tel do
      Application.put_env(:markdown_ld, :track_performance, true)
      if Code.ensure_loaded?(MarkdownLd.TelemetryAgg) do
        {:ok, _} = MarkdownLd.TelemetryAgg.start_link()
        MarkdownLd.TelemetryAgg.attach()
      end
    end

    files = Path.wildcard(Path.join([dir, glob]), match_dot: false)
    if files == [], do: Mix.raise("No files matched #{glob} under #{dir}")

    times =
      for _ <- 1..repeat, file <- files do
        doc = File.read!(file)
        {us, _} = :timer.tc(fn -> JSONLD.extract_triples(doc) end)
        us
      end

    stats = stats(times)
    summary = %{
      docs: length(files),
      runs: length(times),
      total_ms: stats.total_ms,
      mean_us: stats.mean_us,
      p95_us: stats.p95_us,
      backend: (backend || Application.get_env(:markdown_ld, :jsonld_backend, :internal)),
      sources: (sources || (Application.get_env(:markdown_ld, :jsonld_sources, [:fences,:frontmatter,:stubs,:inline,:tables,:attr_objects])
                 |> Enum.map(&to_string/1) |> Enum.join(",")))
    }
    IO.puts(Jason.encode!(summary))
    if use_tel and Code.ensure_loaded?(MarkdownLd.TelemetryAgg) do
      IO.puts(Jason.encode!(%{telemetry: MarkdownLd.TelemetryAgg.summary()}))
    end
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
