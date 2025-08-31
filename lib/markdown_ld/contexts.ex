defmodule MarkdownLd.Contexts do
  @moduledoc "Load published JSON-LD contexts for sidecars and methods."

  @contexts %{
    "lang" => "priv/contexts/lang.context.jsonld",
    "sess" => "priv/contexts/sess.context.jsonld",
    "tgx" => "priv/contexts/tgx.context.jsonld",
    "wasm" => "priv/contexts/wasm.context.jsonld"
  }

  @spec get(String.t()) :: {:ok, map()} | {:error, term()}
  def get(name) do
    with path when is_binary(path) <- Map.get(@contexts, name),
         full <- Application.app_dir(:markdown_ld, path),
         {:ok, bin} <- File.read(full),
         {:ok, map} <- Jason.decode(bin) do
      {:ok, map}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec list() :: [String.t()]
  def list, do: Map.keys(@contexts)
end
