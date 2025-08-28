defmodule MarkdownLd.ConflictFormatterTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Diff
  alias MarkdownLd.Diff.Format

  test "formats conflicts to text and maps" do
    ours = Diff.change(:update_block, [0,0], %{type: :paragraph, before: "Hello", after: "Hello!"})
    theirs = Diff.change(:update_block, [0,0], %{type: :paragraph, before: "Hello", after: "Hello!!!"})
    c = %Diff.Conflict{path: [0,0], reason: :same_segment_edit, ours: ours, theirs: theirs}
    texts = Format.to_text([c])
    assert is_list(texts) and length(texts) == 1
    assert Enum.at(texts, 0) =~ "conflict same_segment_edit"
    maps = Format.to_maps([c])
    assert [%{reason: :same_segment_edit, path: [0,0], ours: %{after: "Hello!"}}] = maps
  end
end

