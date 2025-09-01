defmodule MarkdownLd.JSONLD.Backend do
  @moduledoc """
  Backend selector for JSON-LD expansion.

  Supports:
  - :internal (default): MarkdownLd.JSONLD.Expand (offline, minimal 1.1 subset)
  - :jsonld_ex (optional): Uses the jsonld_ex Hex package (module JSON.LD) when available.

  Configure via:
      config :markdown_ld, jsonld_backend: :internal | :jsonld_ex
  """

  @spec expand(any(), any(), String.t() | nil) :: any()
  def expand(data, init_ctx \\ %{}, base \\ nil) do
    backend = Application.get_env(:markdown_ld, :jsonld_backend, :internal)
    case backend do
      :jsonld_ex -> expand_jsonld_ex(data, init_ctx, base)
      _ -> expand_internal(data, init_ctx, base)
    end
  end

  defp expand_internal(data, init_ctx, base) do
    case base do
      nil -> MarkdownLd.JSONLD.Expand.expand(data, init_ctx || %{})
      _ -> MarkdownLd.JSONLD.Expand.expand(data, init_ctx || %{}, base)
    end
  end

  defp expand_jsonld_ex(data, init_ctx, base) do
    if Code.ensure_loaded?(JSON.LD) do
      # Try common jsonld_ex API: JSON.LD.expand/2 with options.
      # We pass expandContext and base if provided; rescue to internal on failure.
      opts =
        %{}
        |> maybe_put("expandContext", init_ctx)
        |> maybe_put("base", base)

      try do
        # Some versions may expect keyword opts; handle both.
        result =
          cond do
            function_exported?(JSON.LD, :expand, 2) -> JSON.LD.expand(data, opts)
            function_exported?(JSON.LD, :expand, 1) -> JSON.LD.expand(data)
            true -> raise "JSON.LD.expand/1,2 not available"
          end
        result
      rescue
        _ -> expand_internal(data, init_ctx, base)
      end
    else
      expand_internal(data, init_ctx, base)
    end
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, %{} = empty) when map_size(empty) == 0, do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end

