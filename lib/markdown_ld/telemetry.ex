defmodule MarkdownLd.Telemetry do
  @moduledoc """
  Lightweight telemetry wrapper. Uses :telemetry if available and
  `config :markdown_ld, track_performance: true`.
  """

  @enabled Application.compile_env(:markdown_ld, :track_performance, false)

  @doc "Execute a telemetry event with measurements and metadata"
  def exec(event, measurements, metadata \\ %{}) do
    if @enabled and Code.ensure_loaded?(:telemetry) do
      :telemetry.execute(List.wrap(event), measurements, metadata)
    end
    :ok
  end

  @doc "Measure a fun and emit a telemetry event with duration_us"
  def measure(event, metadata \\ %{}, fun) when is_function(fun, 0) do
    {us, result} = :timer.tc(fun)
    exec(event, %{duration_us: us}, metadata)
    {us, result}
  end
end

