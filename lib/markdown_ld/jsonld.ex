defmodule MarkdownLd.JSONLD do
  @moduledoc """
  JSON-LD extraction (stub) and diff utilities.

  This module provides a placeholder extractor for JSON-LD triples and a graph
  diff that emits semantic add/remove/update suggestions. The extractor should
  be replaced with a proper frontmatter/JSON-LD parser.
  """

  alias MarkdownLd.Diff

  @typedoc "JSON-LD triple-like edge"
  @type triple :: %{s: String.t(), p: String.t(), o: String.t()}

  @doc """
  Extract JSON-LD triples from a markdown document.

  Sources supported:
  - Embedded code fences with languages: `json`, `json-ld`, `jsonld`, `application/ld+json`
  - YAML frontmatter stub: looks for `jsonld:` followed by an indented JSON object
  - Back-compat stub lines starting with `JSONLD: s,p,o`
  """
  @spec extract_triples(String.t()) :: [triple()]
  def extract_triples(text) do
    {fm_ctx, ld} = parse_frontmatter(text)
    base = ld["base"] || ld[:base]
    doc_subject = ld["subject"] || ld[:subject]
    fence_triples = extract_from_fences(text, fm_ctx, base)
    fm_triples = extract_from_frontmatter(text, fm_ctx, base)
    stub_triples = extract_from_stub_lines(text)
    attr_triples = extract_from_attribute_objects(text, fm_ctx, base)
    inline_triples = extract_from_inline_attrs(text, fm_ctx, base, doc_subject)
    table_triples = extract_from_tables(text, fm_ctx, base, doc_subject)
    fence_triples ++ fm_triples ++ stub_triples ++ attr_triples ++ inline_triples ++ table_triples
  end

  @doc """
  Compute a semantic diff between two docs' JSON-LD triples, producing Change
  operations: :jsonld_add, :jsonld_remove, and :jsonld_update (when same s,p and different o).
  """
  @spec diff(String.t(), String.t()) :: [Diff.Change.t()]
  def diff(old_text, new_text) do
    a = extract_triples(old_text)
    b = extract_triples(new_text)
    diff_triples(a, b)
  end

  @doc """
  Compute changes between two triple lists directly.
  """
  @spec diff_triples([triple()], [triple()]) :: [Diff.Change.t()]
  def diff_triples(a, b) do
    # Group by (s,p) to support multi-valued set semantics
    a_groups = group_sp(a)
    b_groups = group_sp(b)

    # Compute per-(s,p) adds/removes and opportunistic updates
    {updates, adds, removes} =
      Enum.reduce(Map.keys(Map.merge(a_groups, b_groups)), {[], [], []}, fn sp, {ups, as, rs} ->
        a_set = Map.get(a_groups, sp, MapSet.new())
        b_set = Map.get(b_groups, sp, MapSet.new())

        only_a = MapSet.difference(a_set, b_set)
        only_b = MapSet.difference(b_set, a_set)

        # Per-value adds/removes
        rs2 =
          Enum.reduce(only_a, rs, fn o, acc ->
            %{s: s, p: p} = sp_to_map(sp)
            [Diff.change(:jsonld_remove, nil, %{triple: %{s: s, p: p, o: o}}) | acc]
          end)

        as2 =
          Enum.reduce(only_b, as, fn o, acc ->
            %{s: s, p: p} = sp_to_map(sp)
            [Diff.change(:jsonld_add, nil, %{triple: %{s: s, p: p, o: o}}) | acc]
          end)

        # Opportunistic updates when there's a 1-1 replacement
        ups2 =
          if MapSet.size(only_a) > 0 and MapSet.size(only_b) > 0 do
            minc = min(MapSet.size(only_a), MapSet.size(only_b))
            olds = only_a |> Enum.take(minc)
            news = only_b |> Enum.take(minc)
            Enum.reduce(Enum.zip(olds, news), ups, fn {o1, o2}, acc ->
              %{s: s, p: p} = sp_to_map(sp)
              [Diff.change(:jsonld_update, nil, %{before: %{s: s, p: p, o: o1}, after: %{s: s, p: p, o: o2}}) | acc]
            end)
          else
            ups
          end

        {ups2, as2, rs2}
      end)

    # Return updates first to satisfy tests that expect presence of :jsonld_update
    Enum.reverse(updates) ++ Enum.reverse(removes) ++ Enum.reverse(adds)
  end

  defp group_sp(triples) do
    Enum.reduce(triples, %{}, fn %{s: s, p: p, o: o}, acc ->
      sp = {s, p}
      set = Map.get(acc, sp, MapSet.new()) |> MapSet.put(o)
      Map.put(acc, sp, set)
    end)
  end

  defp sp_to_map({s, p}), do: %{s: s, p: p}

  # ——— Extractors ———

  @fence_langs MapSet.new(["json", "json-ld", "jsonld", "application/ld+json"])

  defp extract_from_fences(text, fm_ctx, base) do
    lines = String.split(text, "\n", trim: false)
    do_fences(lines, nil, [], fm_ctx, base) |> List.flatten()
  end

  defp do_fences([], _state, acc, _fm_ctx, _base), do: Enum.reverse(acc)
  defp do_fences([line | rest], {:in, lang, buf}, acc, fm_ctx, base) do
    cond do
      fence?(line) ->
        json = Enum.join(Enum.reverse(buf), "\n")
        triples = parse_jsonld_to_triples(json, fm_ctx, base)
        do_fences(rest, nil, [triples | acc], fm_ctx, base)
      true ->
        do_fences(rest, {:in, lang, [line | buf]}, acc, fm_ctx, base)
    end
  end
  defp do_fences([line | rest], nil, acc, fm_ctx, base) do
    case fence_lang(line) do
      {:fence, lang} ->
        if MapSet.member?(@fence_langs, String.downcase(lang)) do
          do_fences(rest, {:in, lang, []}, acc, fm_ctx, base)
        else
          do_fences(rest, nil, acc, fm_ctx, base)
        end
      _ -> do_fences(rest, nil, acc, fm_ctx, base)
    end
  end

  defp fence_lang(line) do
    case Regex.run(~r/^```\s*([A-Za-z0-9_+\-\/]+)?\s*$/, line) do
      [_, lang] -> {:fence, lang}
      _ -> :no
    end
  end

  defp fence?(line), do: Regex.match?(~r/^```\s*$/, line)

  defp parse_jsonld_to_triples(json, fm_ctx \\ %{}) do
    case Jason.decode(json) do
      {:ok, data} -> parse_data_to_triples(data, fm_ctx, nil)
      _ -> []
    end
  end

  defp parse_jsonld_to_triples(json, fm_ctx, base) do
    case Jason.decode(json) do
      {:ok, data} -> parse_data_to_triples(data, fm_ctx, base)
      _ -> []
    end
  end

  defp parse_data_to_triples(data, fm_ctx, _base) do
    expanded = MarkdownLd.JSONLD.Expand.expand(data, fm_ctx || %{})
    triples_from_jsonld(expanded)
  end

  defp extract_from_frontmatter(text, fm_ctx, base) do
    case Regex.run(~r/\A---\s*\n([\s\S]*?)\n---\s*(?:\n|\z)/, text) do
      nil -> []
      [_, fm] ->
        # Legacy support: jsonld: { ... }
        case Regex.run(~r/jsonld:\s*(\{[\s\S]*\})/i, fm) do
          [_, json] -> parse_jsonld_to_triples(json, fm_ctx, base)
          _ ->
            # Attempt YAML parse for jsonld map/list
            {fm_map, _ld} = parse_frontmatter(text)
            case fm_map["jsonld"] || fm_map[:jsonld] do
              nil -> []
              data -> parse_data_to_triples(data, fm_ctx, base)
            end
        end
    end
  end

  defp extract_from_stub_lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "JSONLD:"))
    |> Enum.map(fn "JSONLD:" <> rest ->
      parts = rest |> String.trim() |> String.split(",") |> Enum.map(&String.trim/1)
      case parts do
        [s, p, o] -> %{s: s, p: p, o: o}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # ——— Inline Attribute Lists on Headings/Links/Images ———
  defp extract_from_inline_attrs(text, fm_ctx, base, doc_subject) do
    lines = String.split(text, "\n", trim: false)
    do_inline(lines, %{subjects: %{}, cur: doc_subject}, fm_ctx, base, []) |> List.flatten()
  end

  defp do_inline([], _state, _ctx, _base, acc), do: Enum.reverse(acc)
  defp do_inline([line | rest], %{subjects: subs} = state, ctx, base, acc) do
    cond do
      # Heading with trailing attrs
      m = Regex.run(~r/^\s*(#\{1,6\})\s+(.+?)\s*\{([^}]*)\}\s*$/, line, capture: :all_but_first) ->
        [hashes, text, attrs] = m
        level = String.length(hashes)
        attrs_map = parse_attrs(attrs)
        slug = MarkdownLd.Determinism.slug(text || "")
        fallback = base_subject(base, slug)
        subj = attrs_map["ld:@id"] || state.cur || fallback
        # Update subject stack
        subjects = Map.put(subs, level, subj)
        cur = subj || state.cur
        triples =
          emit_heading_triples(cur, attrs_map, ctx, base)
        do_inline(rest, %{subjects: subjects, cur: cur}, ctx, base, [triples | acc])

      # Link with attrs: [text](url){...}
      m = Regex.run(~r/\[([^\]]+)\]\(([^\)]+)\)\{([^}]*)\}/, line, capture: :all_but_first) ->
        [text1, url, attrs] = m
        _ = text1
        attrs_map = parse_attrs(attrs)
        triples = emit_link_image_triples(state.cur, url, attrs_map, ctx, base)
        do_inline(rest, state, ctx, base, [triples | acc])

      # Image with attrs: ![alt](src){...}
      m = Regex.run(~r/!\[([^\]]*)\]\(([^\)]+)\)\{([^}]*)\}/, line, capture: :all_but_first) ->
        [alt, src, attrs] = m
        _ = alt
        attrs_map = parse_attrs(attrs)
        triples = emit_link_image_triples(state.cur, src, attrs_map, ctx, base)
        do_inline(rest, state, ctx, base, [triples | acc])

      true ->
        do_inline(rest, state, ctx, base, acc)
    end
  end

  defp emit_heading_triples(nil, _attrs_map, _ctx, _base), do: []
  defp emit_heading_triples(subject, attrs_map, ctx, base) do
    types =
      case attrs_map["ld:@type"] do
        nil -> []
        v when is_binary(v) ->
          case Jason.decode(v) do
            {:ok, list} when is_list(list) -> list
            _ -> [v]
          end
        v when is_binary(v) -> [v]
        v -> List.wrap(v)
      end

    if types == [] do
      []
    else
      obj = %{"@id" => subject, "@type" => types}
      expanded = case base do
        nil -> MarkdownLd.JSONLD.Expand.expand(obj, ctx || %{})
        _ -> MarkdownLd.JSONLD.Expand.expand(obj, ctx || %{}, base)
      end
      triples_from_jsonld(expanded)
    end
  end

  defp emit_link_image_triples(nil, _url, _attrs_map, _ctx, _base), do: []
  defp emit_link_image_triples(subject, url, attrs_map, ctx, base) do
    prop = attrs_map["ld:prop"]
    cond do
      is_nil(prop) -> []
      v = attrs_map["ld:value"] ->
        value = build_literal(v, attrs_map)
        obj = %{"@id" => subject, prop => value}
        expanded = case base do
          nil -> MarkdownLd.JSONLD.Expand.expand(obj, ctx || %{})
          _ -> MarkdownLd.JSONLD.Expand.expand(obj, ctx || %{}, base)
        end
        triples_from_jsonld(expanded)
      true ->
        obj = %{"@id" => subject, prop => [%{"@id" => url}]}
        expanded = case base do
          nil -> MarkdownLd.JSONLD.Expand.expand(obj, ctx || %{})
          _ -> MarkdownLd.JSONLD.Expand.expand(obj, ctx || %{}, base)
        end
        triples_from_jsonld(expanded)
    end
  end

  defp base_subject(nil, slug) do
    if slug == "", do: nil, else: slug
  end
  defp base_subject(base, slug) do
    if slug == "" do
      nil
    else
      if String.ends_with?(base, ["/", "#"]) do
        base <> slug
      else
        base <> "#" <> slug
      end
    end
  end

  defp build_literal(v, attrs_map) do
    cond do
      is_binary(v) and String.starts_with?(v, "\"") and String.ends_with?(v, "\"") ->
        vv = v |> String.trim_leading("\"") |> String.trim_trailing("\"")
        lang = attrs_map["ld:lang"]
        dt = attrs_map["ld:datatype"]
        cond do
          is_binary(lang) -> %{"@value" => vv, "@language" => String.downcase(lang)}
          is_binary(dt) -> %{"@value" => vv, "@type" => dt}
          true -> vv
        end
      true -> v
    end
  end

  defp parse_attrs(str) do
    tokens = attr_tokens(String.trim(str))
    Enum.reduce(tokens, %{}, fn tok, acc ->
      case String.split(tok, "=", parts: 2) do
        [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
        _ -> acc
      end
    end)
  end

  defp attr_tokens(str) do
    # Split by whitespace outside quotes/brackets
    do_attr_tokens(String.to_charlist(str), [], [], 0, 0)
    |> Enum.map(&to_string/1)
  end

  # ——— Tables ({ld:table=properties}) ———
  defp extract_from_tables(text, fm_ctx, base, doc_subject) do
    lines = String.split(text, "\n", trim: false)
    do_tables(lines, 0, fm_ctx, base, doc_subject, []) |> List.flatten()
  end

  defp do_tables([], _i, _ctx, _base, _doc_subj, acc), do: Enum.reverse(acc)
  defp do_tables([line | rest], i, ctx, base, doc_subj, acc) do
    if table_header?(line) and match?([sep | _] when is_binary(sep), rest) and table_sep?(hd(rest)) do
      {rows, rem_after_table} = collect_table_rows(tl(rest), [])
      # check next non-empty line for marker
      {after_marker, marker?} = consume_until_marker(rem_after_table)
      triples =
        if marker? do
          emit_table_triples([line, hd(rest) | rows], ctx, base, doc_subj)
        else
          []
        end
      do_tables(after_marker, i + length([line | rows]) + 2, ctx, base, doc_subj, [triples | acc])
    else
      do_tables(rest, i + 1, ctx, base, doc_subj, acc)
    end
  end

  defp table_header?(line), do: Regex.match?(~r/^\s*\|.*\|\s*$/, line)
  defp table_sep?(line), do: Regex.match?(~r/^\s*\|\s*:?[-]+:?\s*(\|\s*:?[-]+:?\s*)+\|\s*$/, line)

  defp collect_table_rows([], acc), do: {Enum.reverse(acc), []}
  defp collect_table_rows([line | rest], acc) do
    if table_header?(line) do
      collect_table_rows(rest, [line | acc])
    else
      {Enum.reverse(acc), [line | rest]}
    end
  end

  defp consume_until_marker(lines) do
    case Enum.split_while(lines, fn l -> String.trim(l) == "" end) do
      {blanks, [marker | tail]} ->
        if String.contains?(marker, "{ld:table=properties}") do
          {tail, true}
        else
          {lines, false}
        end
      _ -> {lines, false}
    end
  end

  defp emit_table_triples([header_line, _sep_line | row_lines], ctx, base, doc_subj) do
    headers = split_cells(header_line)
    Enum.flat_map(row_lines, fn row ->
      cells = split_cells(row)
      if length(cells) == 0 do
        []
      else
        row_map = Enum.zip(headers, cells) |> Enum.into(%{})
        {subj, props_map} =
          case Map.get(row_map, "@id") do
            nil -> {doc_subj, Map.delete(row_map, "@id")}
            id -> {id, Map.delete(row_map, "@id")}
          end
        if is_nil(subj) do
          []
        else
          jsonld = %{"@id" => subj}
          jsonld = Enum.reduce(props_map, jsonld, fn {k, v}, acc -> Map.put(acc, k, parse_cell_value(v)) end)
          expanded = case base do
            nil -> MarkdownLd.JSONLD.Expand.expand(jsonld, ctx || %{})
            _ -> MarkdownLd.JSONLD.Expand.expand(jsonld, ctx || %{}, base)
          end
          triples_from_jsonld(expanded)
        end
      end
    end)
  end

  defp split_cells(line) do
    line
    |> String.trim()
    |> String.trim_leading("|")
    |> String.trim_trailing("|")
    |> String.split("|")
    |> Enum.map(&String.trim/1)
  end

  defp parse_cell_value(v) do
    cond do
      v == nil or v == "" -> ""
      String.match?(v, ~r/^\".*\"@([A-Za-z0-9-]+)$/) ->
        [_, val, lang] = Regex.run(~r/^\"(.*)\"@([A-Za-z0-9-]+)$/, v)
        %{"@value" => val, "@language" => String.downcase(lang)}
      String.match?(v, ~r/^\".*\"\^\^(.+)$/) ->
        [_, val, dt] = Regex.run(~r/^\"(.*)\"\^\^(.+)$/, v)
        %{"@value" => val, "@type" => dt}
      String.match?(v, ~r/^\<.*\>$/) ->
        iri = v |> String.trim_leading("<") |> String.trim_trailing(">")
        %{"@id" => iri}
      String.match?(v, ~r/^[-+]?[0-9]+$/) -> String.to_integer(v)
      String.match?(v, ~r/^[-+]?[0-9]*\.[0-9]+$/) -> String.to_float(v)
      String.downcase(v) in ["true", "false"] -> String.downcase(v) == "true"
      String.match?(v, ~r/^\".*\"$/) -> v |> String.trim_leading("\"") |> String.trim_trailing("\"")
      true -> v
    end
  end

  defp do_attr_tokens([], cur, acc, _q, _b) do
    acc = if cur == [], do: acc, else: [Enum.reverse(cur) | acc]
    Enum.reverse(acc)
  end
  defp do_attr_tokens([c | rest], cur, acc, q, b) do
    cond do
      c == ?\" -> do_attr_tokens(rest, [c | cur], acc, if(q == 0, do: 1, else: 0), b)
      c == ?[ and q == 0 -> do_attr_tokens(rest, [c | cur], acc, q, b + 1)
      c == ?] and q == 0 and b > 0 -> do_attr_tokens(rest, [c | cur], acc, q, b - 1)
      c in ' \t' and q == 0 and b == 0 ->
        acc2 = if cur == [], do: acc, else: [Enum.reverse(cur) | acc]
        do_attr_tokens(rest, [], acc2, q, b)
      true -> do_attr_tokens(rest, [c | cur], acc, q, b)
    end
  end

  # ——— Attribute Objects in List Items ———
  defp extract_from_attribute_objects(text, fm_ctx, base) do
    lines = String.split(text, "\n", trim: false)
    scan_attr_objects(lines, 0, fm_ctx, base, []) |> List.flatten()
  end

  defp scan_attr_objects([], _i, _ctx, _base, acc), do: Enum.reverse(acc)
  defp scan_attr_objects([line | rest], i, ctx, base, acc) do
    case Regex.run(~r/^\s*-\s*\{(.*)$/, line, capture: :all_but_first) do
      nil -> scan_attr_objects(rest, i + 1, ctx, base, acc)
      [start] ->
        {body, remaining} = collect_braces([start | rest], 1, [])
        triples = attr_object_to_triples(Enum.join(body, "\n"), ctx, base)
        scan_attr_objects(remaining, i + 1, ctx, base, [triples | acc])
    end
  end

  defp collect_braces([], _depth, acc), do: {Enum.reverse(acc), []}
  defp collect_braces([line | rest], depth, acc) do
    opened = count_char(line, ?{) - count_char(line, ?})
    depth2 = depth + opened
    if depth2 <= 0 do
      {Enum.reverse([String.trim_trailing(line) | acc]), rest}
    else
      collect_braces(rest, depth2, [line | acc])
    end
  end

  defp count_char(str, ch), do: :binary.bin_to_list(str) |> Enum.count(&(&1 == ch))

  defp attr_object_to_triples(body, fm_ctx, base) do
    case MarkdownLd.AttrObject.parse(body) do
      {:ok, map} ->
        jsonld = attr_map_to_jsonld(map)
        expanded = case base do
          nil -> MarkdownLd.JSONLD.Expand.expand(jsonld, fm_ctx || %{})
          _ -> MarkdownLd.JSONLD.Expand.expand(jsonld, fm_ctx || %{}, base)
        end
        triples_from_jsonld(expanded)
      {:error, _} -> []
    end
  end

  defp attr_map_to_jsonld(map) do
    {ctx, props} = Map.pop(map, "@context")
    base = if ctx, do: %{"@context" => ctx}, else: %{}
    Enum.reduce(props, base, fn {k, v}, acc ->
      cond do
        k == "@id" or k == "@type" -> Map.put(acc, k, v)
        String.ends_with?(k, "[]") ->
          prop = String.trim_trailing(k, "[]")
          list = List.wrap(v)
          Map.put(acc, prop, [%{"@list" => Enum.map(list, &convert_value/1)}])
        true -> Map.put(acc, k, convert_value(v))
      end
    end)
  end

  defp convert_value({:ordered_list, v}), do: %{"@list" => Enum.map(List.wrap(v), &convert_value/1)}
  defp convert_value(list) when is_list(list), do: Enum.map(list, &convert_value/1)
  defp convert_value(%{"@value" => _} = v), do: v
  defp convert_value(%{"@id" => _} = v), do: v
  defp convert_value(%{} = nested), do: nested
  defp convert_value(other), do: other

  # ——— Frontmatter (YAML subset) ———

  @doc false
  def parse_frontmatter(text) do
    case Regex.run(~r/\A---\s*\n([\s\S]*?)\n---\s*(?:\n|\z)/, text) do
      nil -> {%{}, %{} }
      [_, fm] ->
        map = parse_yaml_like(fm)
        ctx = Map.get(map, "@context") || Map.get(map, :"@context") || %{}
        ld = Map.get(map, "ld") || Map.get(map, :ld) || %{}
        {ctx, ld}
    end
  end

  # Minimal YAML map parser (2-space indentation, key: value or nested maps). Strings may be quoted with ".
  defp parse_yaml_like(text) do
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))

    tree = %{}
    stack = [{0, []}] # {indent, path}

    Enum.reduce(lines, {tree, stack}, fn line, {tree, stack} ->
      indent = leading_spaces(line)
      # ignore list items for simplicity
      if String.trim_leading(line) |> String.starts_with?("-") do
        {tree, stack}
      else
        stack2 = unwind_paths(stack, indent)
        {_, path} = hd(stack2)
        trimmed = String.trim_leading(line)
        case String.split(trimmed, ":", parts: 2) do
          [k] -> {tree, stack2}
          [k, rest] ->
            key = yaml_unquote(String.trim(k))
            val = String.trim(rest)
            cond do
              val == "" ->
                new_tree = put_in(tree, path ++ [key], %{})
                {new_tree, [{indent + 2, path ++ [key]} | stack2]}
              true ->
                value = parse_yaml_value(val)
                new_tree = put_in(tree, path ++ [key], value)
                {new_tree, stack2}
            end
        end
      end
    end)
    |> elem(0)
  end

  defp leading_spaces(<<>>), do: 0
  defp leading_spaces(str) do
    for <<c <- str>>, reduce: 0 do
      acc ->
        if c == ?\s, do: acc + 1, else: throw({:done, acc})
    end
  catch
    {:done, acc} -> acc
  end

  defp unwind_paths([{i, _} | _] = stack, indent) do
    case stack do
      [{i, _} | _] when indent >= i -> stack
      [_ | rest] -> unwind_paths(rest, indent)
    end
  end
  defp unwind_paths([], _), do: [{0, []}]

  defp parse_yaml_value(val) do
    v = String.trim(val)
    cond do
      String.length(v) >= 2 and String.starts_with?(v, "\"") and String.ends_with?(v, "\"") ->
        v |> String.trim_leading("\"") |> String.trim_trailing("\"")
      String.downcase(v) == "true" -> true
      String.downcase(v) == "false" -> false
      true -> v
    end
  end

  defp yaml_unquote(k) do
    if String.length(k) >= 2 and String.starts_with?(k, "\"") and String.ends_with?(k, "\"") do
      k |> String.trim_leading("\"") |> String.trim_trailing("\"")
    else
      k
    end
  end

  # ——— JSON-LD to Triples ———

  defp triples_from_jsonld(list) when is_list(list) do
    list |> Enum.flat_map(&triples_from_jsonld/1)
  end
  defp triples_from_jsonld(map) when is_map(map) do
    s = Map.get(map, "@id") || Map.get(map, :"@id") || gen_subject(map)
    ctx = Map.get(map, "@context") || Map.get(map, :"@context")
    type = Map.get(map, "@type") || Map.get(map, :"@type")

    type_triples =
      cond do
        is_binary(type) -> [%{s: s, p: "rdf:type", o: type}]
        is_list(type) -> Enum.map(type, fn t -> %{s: s, p: "rdf:type", o: to_string(t)} end)
        true -> []
      end

    prop_triples =
      map
      |> Enum.flat_map(fn {k, v} ->
        kk = to_string(k)
        if String.starts_with?(kk, "@") do
          []
        else
          triples_for_value(s, kk, v)
        end
      end)

    type_triples ++ prop_triples
  end
  defp triples_from_jsonld(_), do: []

  defp triples_for_value(s, p, v) when is_binary(v), do: [%{s: s, p: p, o: v}]
  defp triples_for_value(s, p, v) when is_number(v), do: [%{s: s, p: p, o: to_string(v)}]
  defp triples_for_value(s, p, v) when is_boolean(v), do: [%{s: s, p: p, o: to_string(v)}]
  defp triples_for_value(s, p, v) when is_list(v) do
    Enum.flat_map(v, fn e -> triples_for_value(s, p, e) end)
  end
  defp triples_for_value(s, p, v) when is_map(v) do
    case Map.get(v, "@id") || Map.get(v, :"@id") do
      nil ->
        id = gen_subject(v)
        [%{s: s, p: p, o: id}] ++ triples_from_jsonld(Map.put(v, "@id", id))
      id -> [%{s: s, p: p, o: id}] ++ triples_from_jsonld(v)
    end
  end

  defp gen_subject(map) do
    # Deterministic blank node ID using JCS
    json = MarkdownLd.JCS.encode(map)
    "_:" <> (:crypto.hash(:sha256, json) |> Base.encode16(case: :lower) |> binary_part(0, 12))
  end
end
