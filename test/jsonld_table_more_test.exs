defmodule MarkdownLd.JSONLDTableMoreTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "properties table with multiple rows and @type" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/"}
    ld: {"subject": "post:1"}
    ---

    | @id    | @type           | schema:name |
    | ------ | --------------- | ----------- |
    | post:1 | schema:Article  | "A"        |
    | post:2 | schema:Article  | "B"        |

    {ld:table=properties}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, &(&1.s == "post:1" and &1.p == "rdf:type" and String.contains?(&1.o, "schema:Article")))
    assert Enum.any?(ts, &(&1.s == "post:2" and String.contains?(&1.p, "http://schema.org/name") and &1.o == "B"))
  end
end

