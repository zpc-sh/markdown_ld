defmodule MarkdownLd.JSONLDTableListTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.JSONLD

  test "table list values are emitted as multiple objects" do
    md = """
    ---
    "@context": {"schema": "http://schema.org/"}
    ld: {"subject": "post:1"}
    ---

    | @id    | schema:tag        |
    | ------ | ----------------- |
    | post:1 | ["alpha","beta"] |

    {ld:table=properties}
    """

    ts = JSONLD.extract_triples(md)
    tags = Enum.filter(ts, &String.contains?(&1.p, "http://schema.org/tag"))
    assert Enum.any?(tags, &(&1.o == "alpha"))
    assert Enum.any?(tags, &(&1.o == "beta"))
  end
end

