defmodule QCPStreamTest do
  use ExUnit.Case, async: true

  test "process emits channel tuples in order" do
    lines = [
      "```task\n",
      "Analyze flow\n",
      "```\n",
      "```diagnostics\n",
      "Recursion_depth: 2\n",
      "```\n"
    ]

    events = QCP.Stream.process(lines) |> Enum.to_list()
    assert events == [
      {:task, "Analyze flow"},
      {:diagnostics, "Recursion_depth: 2"}
    ]
  end

  test "unknown channel type is marked unknown" do
    lines = ["```weird\n", "X\n", "```\n"]
    [{ch, body}] = QCP.Stream.process(lines) |> Enum.to_list()
    assert ch == :unknown
    assert body == "X"
  end
end

