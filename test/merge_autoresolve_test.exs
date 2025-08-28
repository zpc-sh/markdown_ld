defmodule MarkdownLd.MergeAutoresolveTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Diff

  test "auto-resolves identical result updates" do
    base = Diff.patch("rev0", "rev0", [], %{})
    ours = Diff.patch("rev0", "rev1", [Diff.change(:update_block, [0], %{type: :paragraph, before: "Hello", after: "Hello!"})], %{})
    theirs = Diff.patch("rev0", "rev2", [Diff.change(:update_block, [0], %{type: :paragraph, before: "Hello", after: "Hello!"})], %{})
    res = Diff.three_way_merge(base, ours, theirs)
    assert res.conflicts == []
    assert %Diff.Patch{} = res.merged
  end

  test "auto-resolves superset case by preferring longer result" do
    base = Diff.patch("rev0", "rev0", [], %{})
    ours = Diff.patch("rev0", "rev1", [Diff.change(:update_block, [0], %{type: :paragraph, before: "Hello", after: "Hello!"})], %{})
    theirs = Diff.patch("rev0", "rev2", [Diff.change(:update_block, [0], %{type: :paragraph, before: "Hello", after: "Hello! :)"})], %{})
    res = Diff.three_way_merge(base, ours, theirs)
    # unresolved conflicts lead to merged=nil; autoresolved ones should merge
    assert res.conflicts == []
    assert String.contains?(Enum.find(res.merged.changes, &(&1.kind == :update_block)).payload[:after], ":)")
  end
end

