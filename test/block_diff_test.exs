defmodule MarkdownLd.BlockDiffTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Diff.Block
  alias MarkdownLd.Diff

  describe "segment" do
    test "splits headings, paragraphs, and tasks" do
      md = """
      # Title

      First para line 1
      line 2

      - [ ] todo one
      - [x] todo two
      """

      blocks = Block.segment(md)
      assert Enum.map(blocks, & &1.type) == [:heading, :paragraph, :list_item, :list_item]
    end

    test "captures code fences" do
      md = """
      ```elixir
      IO.puts("hi")
      ```
      """
      [b] = Block.segment(md)
      assert b.type == :code_block
      assert b.attrs[:language] == "elixir"
      assert String.contains?(b.text, "IO.puts")
    end
  end

  describe "diff" do
    test "insert paragraph" do
      a = "# T\n\nhello"
      b = "# T\n\nhello\n\nworld"
      changes = Block.diff(a, b)
      assert Enum.any?(changes, &(&1.kind == :insert_block))
    end

    test "delete paragraph" do
      a = "# T\n\nhello\n\nworld"
      b = "# T\n\nhello"
      changes = Block.diff(a, b)
      assert Enum.any?(changes, &(&1.kind == :delete_block))
    end

    test "update paragraph when similar" do
      a = "# T\n\nhello brave new world"
      b = "# T\n\nhello new world!"
      changes = Block.diff(a, b, similarity_threshold: 0.4)
      assert Enum.any?(changes, &(&1.kind == :update_block))
    end
  end
end

