defmodule MarkdownLd.JSONLDExpandTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD.Expand
  alias MarkdownLd.JSONLD

  test "expands terms with prefix and vocab" do
    data = %{
      "@context" => %{
        "@vocab" => "http://example.com/vocab#",
        "schema" => "http://schema.org/",
        "name" => "schema:name",
        "author" => %{"@id" => "schema:author", "@type" => "@id"}
      },
      "@type" => "schema:Article",
      "name" => "Hello",
      "author" => "person:alice",
      "tag" => ["alpha", "beta"]
    }

    exp = Expand.expand(data)
    assert exp["http://schema.org/name"] == "Hello"
    assert exp["http://schema.org/author"]["@id"] == "person:alice"
    assert exp["@type"] == "http://schema.org/Article"
    # vocab expansion
    assert exp["http://example.com/vocab#tag"] == ["alpha", "beta"]
  end

  test "triple extraction uses expanded IRIs" do
    md = """
    ```json
    {"@context":{"schema":"http://schema.org/","name":"schema:name"},"@id":"post:1","name":"Hello"}
    ```
    """
    triples = JSONLD.extract_triples(md)
    assert Enum.any?(triples, &(&1.p == "http://schema.org/name"))
  end
end

