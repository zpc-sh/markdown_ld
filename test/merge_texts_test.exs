defmodule MarkdownLd.MergeTextsTest do
  use ExUnit.Case, async: true

  test "merges disjoint edits" do
    base = """
    # Title

    Hello
    """

    ours = """
    # Title

    Hello world
    """

    theirs = """
    # Title

    Hello

    JSONLD: post:1, schema:name, Hello
    """

    assert {:ok, merged, _patch} = MarkdownLd.Merge.merge_texts(base, ours, theirs)
    assert String.contains?(merged, "Hello world")
    assert String.contains?(merged, "JSONLD:")
  end

  test "returns conflicts on same-block divergent updates" do
    base = "Para"
    ours = "Para!"
    theirs = "Para?"
    assert {:conflict, conflicts} = MarkdownLd.Merge.merge_texts(base, ours, theirs)
    assert length(conflicts) >= 1
  end
end

