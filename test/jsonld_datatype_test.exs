defmodule MarkdownLd.JSONLDDatatypeTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "inline ld:value typed literal emits o_datatype" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/", "xsd": "http://www.w3.org/2001/XMLSchema#"}
    ld: {"subject": "post:1"}
    ---

    Price: [ignored](#){ld:prop schema:price ld:value "3.14"^^xsd:decimal}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, fn t ->
      t.s == "post:1" and String.contains?(t.p, "http://schema.org/price") and t.o == "3.14" and
        String.ends_with?(to_string(Map.get(t, :o_datatype, "")), "#decimal")
    end)
  end

  test "table typed literal emits o_datatype" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/", "xsd": "http://www.w3.org/2001/XMLSchema#"}
    ld: {"subject": "post:1"}
    ---

    | @id   | schema:price |
    | ----- | ------------ |
    | post:1 | "42"^^xsd:integer |

    {ld:table=properties}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, fn t ->
      t.s == "post:1" and String.contains?(t.p, "http://schema.org/price") and t.o == "42" and
        String.ends_with?(to_string(Map.get(t, :o_datatype, "")), "#integer")
    end)
  end
end

