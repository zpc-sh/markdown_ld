defmodule MarkdownLd.L1ConformanceTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "frontmatter @context expands fences" do
    md = """
    ---
    "@context":
      schema: "https://schema.org/"
    ---

    ```json-ld
    {"@id":"post:1","@type":"schema:Article","schema:name":"Hello"}
    ```
    """
    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, &(&1.p == "rdf:type" and String.contains?(&1.o, "https://schema.org/")))
  end

  test "dev shorthand diff: add/remove/update" do
    a = """
    JSONLD: post:1, schema:name, Hello
    JSONLD: post:1, schema:tag, a
    JSONLD: post:1, schema:tag, b
    """
    b = """
    JSONLD: post:1, schema:name, Hello World
    JSONLD: post:1, schema:tag, b
    JSONLD: post:1, schema:tag, c
    """
    changes = JSONLD.diff(a, b)
    kinds = MapSet.new(Enum.map(changes, & &1.kind))
    assert MapSet.subset?(MapSet.new([:jsonld_add, :jsonld_remove, :jsonld_update]), kinds)
  end
end

