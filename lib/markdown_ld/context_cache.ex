defmodule MarkdownLd.ContextCache do
  @moduledoc """
  Optional cache for JSON-LD context building to reduce repeated merges.

  Uses :persistent_term for near-constant-time reads. Enable via:

      config :markdown_ld, cache_contexts: true

  Keys are derived from a canonical JSON of the provided context term.
  """

  alias MarkdownLd.JCS

  @cache_enabled Application.compile_env(:markdown_ld, :cache_contexts, true)

  @doc "Return cached value for context term or compute and store it."
  def get_or_put(ctx_term, fun) when is_function(fun, 0) do
    if @cache_enabled do
      key = {:markdown_ld, :ctx, :erlang.phash2(JCS.encode(ctx_term))}
      case :persistent_term.get(key, :undefined) do
        :undefined ->
          val = fun.()
          :persistent_term.put(key, val)
          MarkdownLd.Telemetry.exec([:markdown_ld, :cache, :context], %{miss: 1}, %{})
          val
        val ->
          MarkdownLd.Telemetry.exec([:markdown_ld, :cache, :context], %{hit: 1}, %{})
          val
      end
    else
      fun.()
    end
  end

  @doc "Best-effort clear (no-op if not present)."
  def clear(ctx_term) do
    key = {:markdown_ld, :ctx, :erlang.phash2(JCS.encode(ctx_term))}
    try do
      :persistent_term.erase(key)
      :ok
    catch
      _, _ -> :ok
    end
  end
end
