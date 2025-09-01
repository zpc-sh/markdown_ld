defmodule MarkdownLd.TelemetryLogger do
  @moduledoc """
  Optional telemetry console logger for MarkdownLd performance events.

  Usage:
    if Code.ensure_loaded?(MarkdownLd.TelemetryLogger), do: MarkdownLd.TelemetryLogger.attach()
  """

  def attach do
    :telemetry.attach_many(
      'markdown_ld_logger',
      [
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

  def handle_event([:markdown_ld, :jsonld, :extract], meas, meta, _config) do
    IO.puts("[jsonld.extract] total=#{meas.total_triples} us(fences=#{meas.fences_us} fm=#{meas.frontmatter_us} stubs=#{meas.stubs_us} attr=#{meas.attr_us} inline=#{meas.inline_us} tables=#{meas.tables_us}) bytes=#{meta[:bytes]}")
  end
  def handle_event([:markdown_ld, :jsonld, :expand], meas, meta, _config) do
    IO.puts("[jsonld.expand] us=#{meas.duration_us} source=#{meta[:source]}")
  end
  def handle_event([:markdown_ld, :jsonld, :skip], meas, meta, _config) do
    IO.puts("[jsonld.skip] skipped=#{meas.skipped} bytes=#{meta[:bytes]}")
  end
  def handle_event([:markdown_ld, :cache, :context], meas, _meta, _config) do
    if meas[:hit], do: IO.puts("[cache.context] hit=1")
    if meas[:miss], do: IO.puts("[cache.context] miss=1")
  end
  def handle_event([:markdown_ld, :cache, :term], meas, _meta, _config) do
    if meas[:hit], do: IO.puts("[cache.term] hit=1")
    if meas[:miss], do: IO.puts("[cache.term] miss=1")
  end
  def handle_event(_event, _meas, _meta, _config), do: :ok
end

