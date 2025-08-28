defmodule MarkdownLd.StreamDiffTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Diff.Stream

  test "emit and apply events reconstructs new text" do
    old = """
    # T

    Hello world

    JSONLD: post:1, schema:name, Hello
    """

    new = """
    # T

    Hello brave new world

    JSONLD: post:1, schema:name, Hello World
    JSONLD: post:1, schema:author, Alice
    """

    events = Stream.emit(old, new, max_paragraphs: 2)
    assert Enum.at(events, 0).type == :init_snapshot
    assert List.last(events).type == :complete
    assert Enum.any?(events, &(&1.type == :chunk_patch))
    # Ensure stable_id present in metadata
    assert events |> Enum.filter(&(&1.type == :chunk_patch)) |> Enum.all?(fn e -> is_binary(e.meta[:stable_id]) end)

    {:ok, rebuilt} = Stream.apply_events(old, events, max_paragraphs: 2)
    # Rebuilt should include key new substrings
    assert String.contains?(rebuilt, "Hello brave new world")
    assert String.contains?(rebuilt, "schema:author")
  end

  test "deletions are emitted and applied" do
    old = """
    # A

    Para A

    # B
    Para B
    """

    new = """
    # B
    Para B
    """

    events = Stream.emit(old, new, chunk_strategy: :headings)
    {:ok, rebuilt} = Stream.apply_events(old, events, chunk_strategy: :headings)
    assert String.trim(rebuilt) == String.trim(new)
  end
end
