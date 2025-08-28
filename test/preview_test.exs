defmodule MarkdownLd.PreviewTest do
  use ExUnit.Case, async: true

  test "renders inline ops with markers" do
    ops = [{:keep, "Hello"}, {:delete, "brave"}, {:insert, "bold"}, {:keep, "world"}]
    out = MarkdownLd.Diff.Preview.render_ops(ops)
    assert out == "Hello {-brave-} {+bold+} world"
  end
end

