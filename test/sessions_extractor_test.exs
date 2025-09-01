defmodule MarkdownLd.SessionsExtractorTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.Sessions

  test "extracts recorded and live sessions" do
    asciinema = ~s(\n```application/asciinema+json {lds:session=s1}\n{"width":80,"height":24,"stdout":[]}\n```\n)
    term = ~s(\n```application/terminal-session+json {lds:session=s2}\n{"cols":80,"rows":24,"events_b64":""}\n```\n)
    live = ~s(\n```session {lds:session=live-1 lds:proto=ssh lds:host=example}\n(payload)\n```\n)
    md = asciinema <> term <> live

    items = Sessions.extract(md)
    assert Enum.any?(items, &(&1.kind == :asciinema and &1.id != nil and is_binary(&1.hash)))
    assert Enum.any?(items, &(&1.kind == :terminal_session and &1.id != nil))
    assert Enum.any?(items, &(&1.kind == :live and &1.id == "live-1"))
  end

  test "diff detects session update" do
    a = ~s(\n```application/terminal-session+json {lds:session=s3}\n{"cols":80,"rows":24,"events_b64":"AAE="}\n```\n)
    b = ~s(\n```application/terminal-session+json {lds:session=s3}\n{"cols":80,"rows":24,"events_b64":"AAI="}\n```\n)
    changes = Sessions.diff(a, b)
    kinds = changes |> Enum.map(& &1.kind) |> MapSet.new()
    assert MapSet.member?(kinds, :session_update)
  end

  test "projects sessions to JSON-LD" do
    md = ~s(\n```application/asciinema+json {lds:session=s4}\n{"width":80,"height":24,"stdout":[]}\n```\n)
    nodes = Sessions.to_jsonld(md)
    assert Enum.any?(nodes, fn n -> n["@type"] == "sess:Session" and n["schema:encodingFormat"] =~ "application/" end)
  end
end
