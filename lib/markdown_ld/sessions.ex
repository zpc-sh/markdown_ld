defmodule MarkdownLd.Sessions do
  @moduledoc """
  Extract and diff terminal session embeds from Markdown without raw control codes.

  Supports:
  - Recorded sessions: `application/asciinema+json`, `application/terminal-session+json`
  - Live session refs: `session` fences with `lds:*` attributes (L3 Optional)
  """

  alias MarkdownLd.JCS

  @type session :: %{
          kind: :asciinema | :terminal_session | :live,
          id: String.t() | nil,
          hash: String.t() | nil,
          proto: String.t() | nil,
          attrs: map(),
          line: non_neg_integer()
        }

  @spec extract(String.t()) :: [session()]
  def extract(text) when is_binary(text) do
    lines = String.split(text, "\n", trim: false)
    do_extract(lines, 1, [], nil, nil)
  end

  defp do_extract([], _ln, acc, _mode, _buf), do: Enum.reverse(acc)
  defp do_extract([line | rest], ln, acc, nil, _buf) do
    cond do
      m = Regex.run(~r/^```\s*(application\/asciinema\+json)\s*(\{[^}]*\})?\s*$/, line, capture: :all_but_first) ->
        [mt | _] = m
        do_extract(rest, ln + 1, acc, {:rec, :asciinema, ln, parse_attrs_opt(m)}, [])
      m = Regex.run(~r/^```\s*(application\/terminal-session\+json)\s*(\{[^}]*\})?\s*$/, line, capture: :all_but_first) ->
        [mt | _] = m
        do_extract(rest, ln + 1, acc, {:rec, :terminal_session, ln, parse_attrs_opt(m)}, [])
      m = Regex.run(~r/^```\s*session\s*(\{[^}]*\})\s*$/, line, capture: :all_but_first) ->
        [attrs] = m
        attrs_map = parse_attrs(attrs)
        sess = %{
          kind: :live,
          id: attrs_map["lds:session"],
          hash: nil,
          proto: attrs_map["lds:proto"],
          attrs: attrs_map,
          line: ln
        }
        do_extract(rest, ln + 1, [sess | acc], {:live, ln}, [])
      true -> do_extract(rest, ln + 1, acc, nil, nil)
    end
  end
  defp do_extract([line | rest], ln, acc, {:rec, kind, start_ln, attrs}, buf) do
    if String.match?(line, ~r/^```\s*$/) do
      json = Enum.reverse(buf) |> Enum.join("\n")
      sess = record_session(kind, json, attrs, start_ln)
      do_extract(rest, ln + 1, [sess | acc], nil, nil)
    else
      do_extract(rest, ln + 1, acc, {:rec, kind, start_ln, attrs}, [line | buf])
    end
  end
  defp do_extract([line | rest], ln, acc, {:live, _start_ln}, buf) do
    # Live session payload is opaque; consume until closing fence
    if String.match?(line, ~r/^```\s*$/) do
      do_extract(rest, ln + 1, acc, nil, nil)
    else
      do_extract(rest, ln + 1, acc, {:live, ln}, buf)
    end
  end

  defp parse_attrs_opt([_mt]), do: %{}
  defp parse_attrs_opt([_mt, attrs]), do: parse_attrs(attrs)

  defp parse_attrs("{" <> rest) do
    rest
    |> String.trim_trailing("}")
    |> String.trim()
    |> String.split(~r/[\s]+/u, trim: true)
    |> Enum.reduce(%{}, fn tok, acc ->
      case String.split(tok, "=", parts: 2) do
        [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
        _ -> acc
      end
    end)
  end
  defp parse_attrs(_), do: %{}

  defp record_session(:asciinema, json, attrs, ln) do
    case Jason.decode(json) do
      {:ok, data} ->
        cols = data["width"] || data["cols"]
        rows = data["height"] || data["rows"]
        events = data["stdout"] || data["events"] || []
        events_hash = sha256_hex(JCS.encode(events))
        id = short_id(%{"kind" => "asciinema", "cols" => cols, "rows" => rows, "started_at" => data["timestamp"] || data["started_at"], "events_hash" => events_hash})
        hash = sha256_hex(JCS.encode(data))
        %{kind: :asciinema, id: id, hash: hash, proto: nil, attrs: attrs, line: ln}
      _ -> %{kind: :asciinema, id: nil, hash: nil, proto: nil, attrs: attrs, line: ln}
    end
  end
  defp record_session(:terminal_session, json, attrs, ln) do
    case Jason.decode(json) do
      {:ok, data} ->
        cols = data["cols"]
        rows = data["rows"]
        events_b64 = data["events_b64"]
        events_fmt = data["events_fmt"] || "raw"
        events_hash = if is_binary(events_b64), do: sha256_hex(events_b64), else: sha256_hex(JCS.encode(data["events"]))
        id = short_id(%{"kind" => "terminal", "cols" => cols, "rows" => rows, "started_at" => data["started_at"], "events_hash" => events_hash})
        hash = data["hash"] || sha256_hex(JCS.encode(%{"events_fmt" => events_fmt, "events_hash" => events_hash}))
        %{kind: :terminal_session, id: id, hash: hash, proto: nil, attrs: attrs, line: ln}
      _ -> %{kind: :terminal_session, id: nil, hash: nil, proto: nil, attrs: attrs, line: ln}
    end
  end

  defp short_id(map) do
    JCS.encode(map) |> sha256_hex() |> binary_part(0, 12)
  end

  defp sha256_hex(bin), do: :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)

  @doc """
  Diff two markdown texts for session embeds. Returns a list of maps with :kind and :payload.
  Kinds: :session_add, :session_remove, :session_update
  """
  @spec diff(String.t(), String.t()) :: [map()]
  def diff(a, b) do
    aa = index_by_id(extract(a))
    bb = index_by_id(extract(b))
    removed =
      for {id, s} <- aa, Map.get(bb, id) == nil do
        %{kind: :session_remove, payload: s}
      end
    added =
      for {id, s} <- bb, Map.get(aa, id) == nil do
        %{kind: :session_add, payload: s}
      end
    updated =
      for {id, sa} <- aa, sb = Map.get(bb, id), sb != nil, sa.hash != sb.hash do
        %{kind: :session_update, payload: %{before: sa, after: sb}}
      end
    removed ++ updated ++ added
  end


  @doc """
  Map extracted sessions to JSON-LD nodes using the sess/ and schema/ contexts.
  This is a lightweight projection for graph consumers.
  """
  @spec to_jsonld(String.t()) :: [map()]
  def to_jsonld(text) do
    extract(text)
    |> Enum.map(fn s ->
      %{
        "@id" => (s.id || "_:#" <> Integer.to_string(s.line)),
        "@type" => "sess:Session",
        "schema:encodingFormat" => enc_fmt(s.kind),
        "sess:hash" => s.hash,
        "sess:line" => s.line,
        "sess:mode" => Map.get(s.attrs, "ldt:mode"),
        "sess:cap" => caps_from_attrs(s.attrs)
      }
    end)
  end

  defp enc_fmt(:asciinema), do: "application/asciinema+json"
  defp enc_fmt(:terminal_session), do: "application/terminal-session+json"
  defp enc_fmt(:live), do: "session/live"

  defp caps_from_attrs(attrs) do
    case Map.get(attrs, "ldt:cap") do
      nil -> []
      caps -> caps |> String.split(",") |> Enum.map(&String.trim/1)
    end
  end

  defp index_by_id(list) do
    list
    |> Enum.filter(& &1.id)
    |> Map.new(fn s -> {s.id, s} end)
  end
end

