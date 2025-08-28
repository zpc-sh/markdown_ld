defmodule MarkdownLd.TopLevelDiffTest do
  use ExUnit.Case, async: true

  test "combined patch includes block and JSON-LD changes" do
    a = """
    # Title

    Hello world

    JSONLD: post:1, schema:name, Hello
    """

    b = """
    # Title

    Hello brave new world

    JSONLD: post:1, schema:name, Hello World
    JSONLD: post:1, schema:author, Alice
    """

    {:ok, patch} = MarkdownLd.diff(a, b, similarity_threshold: 0.4)
    kinds = patch.changes |> Enum.map(& &1.kind) |> MapSet.new()
    assert MapSet.member?(kinds, :update_block)
    assert MapSet.member?(kinds, :jsonld_update)
    assert MapSet.member?(kinds, :jsonld_add)
  end
end

