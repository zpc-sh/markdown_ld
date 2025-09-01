defmodule MarkdownLd.TermCache do
  @moduledoc """
  Cache term resolution results for JSON-LD expansion.

  Keys are (ctx_hash, term). Enable by default; safe because values derive
  from immutable ctx snapshots. Disable by setting `cache_contexts: false`.
  """

  alias MarkdownLd.JCS

  @cache_enabled Application.compile_env(:markdown_ld, :cache_contexts, true)

  def get_or_put(ctx, term, fun) when is_function(fun, 0) do
    if @cache_enabled do
      key = {:markdown_ld, :term, ctx_hash(ctx), term}
      case :persistent_term.get(key, :undefined) do
        :undefined ->
          val = fun.()
          :persistent_term.put(key, val)
          val
        val -> val
      end
    else
      fun.()
    end
  end

  defp ctx_hash(%{vocab: v, prefixes: p, terms: t, base: b}) do
    JCS.encode(%{"@vocab" => v, "prefixes" => p, "terms" => t, "@base" => b})
    |> :erlang.phash2()
  end
  defp ctx_hash(_other), do: :erlang.phash2(0)
end

