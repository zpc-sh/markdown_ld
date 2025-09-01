defmodule MarkdownLd.JSONLDInlineExtractTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "heading inline attrs emit rdf:type with expanded IRI" do
    md = """
    ---
    "@context":
      schema: "http://schema.org/"
    ---

    # Page {ld:@id post:1 ld:@type schema:Article}
    """

    triples = JSONLD.extract_triples(md)
    assert Enum.any?(triples, &(&1.s == "post:1" and &1.p == "rdf:type" and String.contains?(&1.o, "http://schema.org/Article")))
  end

  test "link with ld:prop attaches to current subject and expands property" do
    md = """
    ---
    "@context":
      schema: "http://schema.org/"
    ld:
      subject: post:1
    ---

    See [site](https://example.com){ld:prop schema:url}
    """

    triples = JSONLD.extract_triples(md)
    assert Enum.any?(triples, &(&1.s == "post:1" and String.contains?(&1.p, "http://schema.org/url") and String.contains?(&1.o, "https://example.com")))
  end

  test "link with ld:prop and ld:value literal string" do
    md = """
    ---
    "@context":
      schema: "http://schema.org/"
    ld:
      subject: post:1
    ---

    Title: [ignored](#){ld:prop schema:name ld:value Hello}
    """

    triples = JSONLD.extract_triples(md)
    assert Enum.any?(triples, &(&1.s == "post:1" and String.contains?(&1.p, "http://schema.org/name") and &1.o == "Hello"))
  end

  test "attribute object in list item emits triples" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/"}
    ---

    - {@id: post:1, schema:name: "Hello"}
    """

    triples = JSONLD.extract_triples(md)
    assert Enum.any?(triples, &(&1.s == "post:1" and String.contains?(&1.p, "http://schema.org/name") and &1.o == "Hello"))
  end

  test "properties table with marker emits triples" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/"}
    ld: {"subject": "post:1"}
    ---

    | @id   | schema:name |
    | ----- | ----------- |
    | post:1 | "Hi"       |

    {ld:table=properties}
    """

    triples = JSONLD.extract_triples(md)
    assert Enum.any?(triples, &(&1.s == "post:1" and String.contains?(&1.p, "http://schema.org/name") and &1.o == "Hi"))
  end
end

