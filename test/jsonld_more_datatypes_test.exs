defmodule MarkdownLd.JSONLDMoreDatatypesTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "boolean and float in table" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/", "xsd": "http://www.w3.org/2001/XMLSchema#"}
    ld: {"subject": "post:1"}
    ---

    | @id    | schema:active | schema:ratio |
    | ------ | ------------- | ------------ |
    | post:1 | "true"^^xsd:boolean | "0.75"^^xsd:float |

    {ld:table=properties}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, fn t -> String.contains?(t.p, "http://schema.org/active") and to_string(Map.get(t, :o_datatype, "")) =~ ~r/#boolean$/ end)
    assert Enum.any?(ts, fn t -> String.contains?(t.p, "http://schema.org/ratio") and to_string(Map.get(t, :o_datatype, "")) =~ ~r/#float$/ end)
  end
end

