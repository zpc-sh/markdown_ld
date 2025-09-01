defmodule MarkdownLd.JSONLDImageAndVocabTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "image with ld:prop attaches triple" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/"}
    ld: {"subject": "post:1"}
    ---

    ![logo](https://example.com/logo.png){ld:prop schema:image}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, &(&1.s == "post:1" and String.contains?(&1.p, "http://schema.org/image") and String.contains?(&1.o, "https://example.com/logo.png")))
  end

  test "fenced JSON with @vocab expands terms" do
    md = """
    ```json
    {"@context": {"@vocab": "http://example.com/v#"}, "@id":"post:1", "title": "Hello"}
    ```
    """
    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, &(&1.p == "http://example.com/v#title" and &1.o == "Hello"))
  end

  test "ld:value with language emits o_lang" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/"}
    ld: {"subject": "post:1"}
    ---

    [ignored](#){ld:prop schema:name ld:value "Bonjour"@fr}
    """

    ts = JSONLD.extract_triples(md)
    assert Enum.any?(ts, fn t -> t.s == "post:1" and String.contains?(t.p, "http://schema.org/name") and t.o == "Bonjour" and Map.get(t, :o_lang) == "fr" end)
  end
end

