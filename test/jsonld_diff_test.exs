defmodule MarkdownLd.JSONLDDiffTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD
  alias MarkdownLd.Diff

  test "extracts JSONLD stub triples" do
    md = """
    Intro
    JSONLD: post:1, schema:name, Hello
    JSONLD: post:1, schema:author, Alice
    """
    ts = JSONLD.extract_triples(md)
    assert length(ts) == 2
    assert Enum.any?(ts, &(&1.p == "schema:author"))
  end

  test "diffs add/remove/update" do
    a = """
    JSONLD: post:1, schema:name, Hello
    JSONLD: post:1, schema:author, Alice
    """
    b = """
    JSONLD: post:1, schema:name, Hello World
    JSONLD: post:1, schema:published, 2025-01-01
    """
    changes = JSONLD.diff(a, b)
    kinds = Enum.map(changes, & &1.kind) |> MapSet.new()
    assert MapSet.subset?(MapSet.new([:jsonld_update, :jsonld_remove, :jsonld_add]), kinds)
  end

  test "extracts from json-ld code fence" do
    md = """
    ```json-ld
    {"@id":"post:1","@type":"BlogPosting","schema:name":"Hello","schema:author":{"@id":"person:alice"}}
    ```
    """
    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, &(&1.p == "schema:name" and &1.o == "Hello"))
    assert Enum.any?(ts, &(&1.p == "rdf:type" and &1.o == "BlogPosting"))
    assert Enum.any?(ts, &(&1.p == "schema:author" and &1.o == "person:alice"))
  end

  test "extracts from frontmatter jsonld block" do
    md = """
    ---
    title: Test
    jsonld: {"@id":"post:1","schema:name":"Hello"}
    ---
    Body
    """
    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, &(&1.p == "schema:name" and &1.o == "Hello"))
  end
end
