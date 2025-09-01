defmodule MarkdownLd.JSONLDBaseSubjectTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "base IRI from frontmatter ld:base composes subject for heading attrs" do
    md = """
    ---
    ld: {"base": "http://example.com/doc"}
    ---

    # Section {ld:@type schema:Thing}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, fn t -> t.p == "rdf:type" and String.starts_with?(t.s, "http://example.com/doc#") end)
  end
end

