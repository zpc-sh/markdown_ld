defmodule MarkdownLd.DiffModelTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Diff

  describe "conflict detection" do
    test "no conflict on different paths" do
      a = Diff.change(:update_block, [0, 1], %{text: "A"})
      b = Diff.change(:update_block, [0, 2], %{text: "B"})
      assert [] == Diff.detect_conflicts([a], [b])
    end

    test "conflict on same path, both modifying" do
      a = Diff.change(:update_block, [1, 0], %{text: "ours"})
      b = Diff.change(:update_block, [1, 0], %{text: "theirs"})
      [c] = Diff.detect_conflicts([a], [b])
      assert c.path == [1, 0]
      assert c.reason in [:same_segment_edit, :delete_vs_edit, :move_vs_edit, :jsonld_semantic]
    end

    test "delete vs edit is flagged" do
      a = Diff.change(:delete_block, [2, 3], %{})
      b = Diff.change(:update_block, [2, 3], %{text: "keep"})
      [c] = Diff.detect_conflicts([a], [b])
      assert c.reason == :delete_vs_edit
    end
  end

  describe "three-way merge" do
    test "auto-merges when no conflicts" do
      base = Diff.patch("rev-base", "rev-a", [], %{})
      ours = Diff.patch("rev-a", "rev-a1", [Diff.change(:insert_block, [0], %{text: "hello"})], %{})
      theirs = Diff.patch("rev-a", "rev-b1", [Diff.change(:insert_block, [1], %{text: "world"})], %{})

      result = Diff.three_way_merge(base, ours, theirs)
      assert result.conflicts == []
      assert %Diff.Patch{} = result.merged
      assert length(result.merged.changes) == 2
    end

    test "reports conflicts when needed" do
      base = Diff.patch("rev-base", "rev-a", [], %{})
      ours = Diff.patch("rev-a", "rev-a1", [Diff.change(:update_block, [0, 0], %{text: "ours"})], %{})
      theirs = Diff.patch("rev-a", "rev-b1", [Diff.change(:update_block, [0, 0], %{text: "theirs"})], %{})

      result = Diff.three_way_merge(base, ours, theirs)
      assert result.merged == nil
      assert length(result.conflicts) == 1
      [%Diff.Conflict{path: [0, 0]}] = result.conflicts
    end
  end
end

