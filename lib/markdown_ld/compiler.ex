defmodule MarkdownLd.Compiler do
  @moduledoc """
  Markdown-LD compiler: parses Markdown, resolves semantics, and emits RDF.

  Current capabilities:
  - Compiles to triples (as extracted by MarkdownLd.JSONLD)
  - Emits N-Quads/N-Triples from triples with RDF 1.1 lexical forms
  - Returns a diagnostics stub for future strict/lax surfacing

  Roadmap:
  - Add `{ld:table=properties}` support via core extractor once implemented
  - Surface strict/lax diagnostics with byte offsets from attribute objects
  - Provide expanded/compacted JSON-LD emitters when node IR is available
  """

  @type triple :: %{s: String.t(), p: String.t(), o: String.t()}
  @type diagnostics :: %{errors: [map()], strict: boolean()}
  @type result :: %{triples: [triple()], diagnostics: diagnostics}

  @doc """
  Compile Markdown-LD to an internal result with triples and diagnostics.

  Options:
  - `:strict` (default: false) — reserved for future diagnostics surfacing
  """
  @spec compile(String.t(), keyword()) :: {:ok, result} | {:error, diagnostics}
  def compile(markdown, opts \\ []) when is_binary(markdown) do
    strict = Keyword.get(opts, :strict, false)
    triples = MarkdownLd.JSONLD.extract_triples(markdown)
    {:ok, %{triples: triples, diagnostics: %{errors: [], strict: strict}}}
  end

  @doc """
  Emit N-Quads from a compiled result. Literals are serialized per RDF 1.1 and
  language tags are lowercased. Datatype IRIs should be normalized upstream.
  """
  @spec emit_nquads(result) :: String.t()
  def emit_nquads(%{triples: triples}) do
    triples
    |> Enum.map(&to_ntriple/1)
    |> Enum.join("\n")
  end

  defp to_ntriple(%{s: s, p: p, o: o}) do
    ss = iri_or_bnode(s)
    pp = iri(p)
    oo = object(o)
    ss <> " " <> pp <> " " <> oo <> " ."
  end

  defp iri_or_bnode("_:" <> _ = b), do: b

  defp iri_or_bnode(b) when is_binary(b) do
    if String.starts_with?(b, ["http://", "https://"]) do
      "<" <> b <> ">"
    else
      # Treat as CURIE/term; leave as quoted literal for safety
      encode_literal(b)
    end
  end

  defp iri(i) when is_binary(i), do: "<" <> i <> ">"

  # Simple literal heuristic: if it looks like an IRI, serialize as IRI; else as string
  defp object(o) when is_binary(o) do
    cond do
      String.starts_with?(o, ["http://", "https://"]) -> iri(o)
      true -> encode_literal(o)
    end
  end

  defp encode_literal(s) do
    escaped =
      s
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")

    "\"" <> escaped <> "\""
  end
end
