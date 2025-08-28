defmodule MarkdownLd.HeadingChunkingTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Diff.Stream

  test "chunks by headings and assigns stable ids" do
    md = """
    Intro paragraph before heading

    # First Section
    Content A

    ## Sub Section
    Content B

    # Second Section
    Content C
    """

    chunks = Stream.chunk(md, chunk_strategy: :headings)
    # Expect 3 chunks: preface, first section (incl. sub), and second section
    assert length(chunks) >= 3
    assert Enum.all?(chunks, fn {_i, _c, sid} -> is_binary(sid) and byte_size(sid) > 0 end)
    # The heading-based IDs should be deterministic: same doc -> same IDs
    chunks2 = Stream.chunk(md, chunk_strategy: :headings)
    assert Enum.zip(chunks, chunks2) |> Enum.all?(fn {{i1, _, sid1}, {i2, _, sid2}} -> i1 == i2 and sid1 == sid2 end)
  end
end

