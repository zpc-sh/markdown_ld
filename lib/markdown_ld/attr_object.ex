defmodule MarkdownLd.AttrObject do
  @moduledoc """
  Parser for Attribute Objects used in list items: `- { ... }`.

  Mini grammar (subset per v0.3):
  - Entry separators: commas or whitespace (outside lists/strings)
  - Keys: `[A-Za-z_][A-Za-z0-9._:-]*` with optional `[]` suffix for ordered `@list`
  - Values:
    - Strings: "..." with JSON escapes, optional "..."@lang or "..."^^datatype
    - Numbers: integer/decimal/double per lexical form
    - Booleans: true|false
    - IRI: <...> absolute
    - CURIE/term: prefix:suffix or term (left as string; expander resolves)
    - Lists: [ v (, v)* ]
    - Nested objects: { ... }

  Returns {:ok, map} or {:error, {reason, pos}}
  """

  @type opts :: [
          strict: boolean(),
          max_depth: pos_integer(),
          max_list: pos_integer(),
          max_size: pos_integer()
        ]

  @default_opts [strict: true, max_depth: 32, max_list: 1024, max_size: 16 * 1024]

  @spec parse(String.t(), opts()) :: {:ok, map()} | {:error, {atom(), non_neg_integer()}}
  def parse(str, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    if byte_size(str) > opts[:max_size],
      do: {:error, {:limit_exceeded, 0}},
      else: do_parse(str, opts)
  end

  defp do_parse(str, opts) do
    with {:ok, tokens} <- tokenize(str),
         {:ok, map, rest} <- parse_object(tokens, 0, opts) do
      case rest do
        [] -> {:ok, map}
        _ -> {:ok, map}
      end
    end
  end

  # ——— Tokenizer (keeps structural tokens and strings) ———

  defp tokenize(str), do: {:ok, String.to_charlist(str)}

  # ——— Recursive descent ———

  defp parse_object(chars, depth, opts) do
    if(depth >= opts[:max_depth], do: {:error, {:limit_exceeded, 0}}, else: :ok)
    |> case do
      :ok -> parse_object_entries(skip_ws(chars), %{}, depth, opts)
      err -> err
    end
  end

  defp parse_object_entries([?} | rest], acc, _depth, _opts), do: {:ok, acc, rest}
  defp parse_object_entries([], acc, _depth, _opts), do: {:ok, acc, []}

  defp parse_object_entries(chars, acc, depth, opts) do
    {key, ordered?, chars1} = parse_key(chars)
    chars2 = skip_ws(expect_char(chars1, ?=))
    {val, chars3} = parse_value(chars2, depth + 1, opts)
    acc1 = Map.put(acc, key, if(ordered?, do: {:ordered_list, val}, else: val))
    chars4 = skip_separators(chars3)
    parse_object_entries(chars4, acc1, depth, opts)
  rescue
    _ -> if opts[:strict], do: {:error, {:parse_error, 0}}, else: {:ok, acc, chars}
  end

  defp parse_key(chars) do
    {token, rest} =
      take_while(chars, fn c ->
        c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c in ~c"._:-" or c == ?_
      end)

    key = to_string(token)
    {_ordered?, rest2} = if String.ends_with?(key, "[]"), do: {true, rest}, else: {false, rest}
    {String.trim_trailing(key, "[]"), skip_ws(rest2)}
  end

  defp parse_value([?" | rest], _depth, _opts) do
    {str, rest1} = take_string(rest, [])
    # Optional @lang or ^^datatype
    {annot, rest2} = parse_string_annotation(skip_ws(rest1))

    val =
      case annot do
        {:lang, lang} -> %{"@value" => str, "@language" => String.downcase(lang)}
        {:type, dt} -> %{"@value" => str, "@type" => dt}
        :none -> str
      end

    {val, skip_ws(rest2)}
  end

  defp parse_value([?< | rest], _depth, _opts) do
    {iri, rest1} = take_until(rest, ?>)
    {%{"@id" => to_string(iri)}, skip_ws(tl(rest1))}
  end

  defp parse_value([?{ | rest], depth, opts) do
    {:ok, obj, rest1} = parse_object(rest, depth, opts)
    {obj, skip_ws(rest1)}
  end

  defp parse_value([?[ | rest], depth, opts) do
    {list, rest1} = parse_list_items(skip_ws(rest), depth, opts, [])
    {list, skip_ws(rest1)}
  end

  defp parse_value(chars, _depth, _opts) do
    {tok, rest} = take_while(chars, fn c -> c not in ~c" \t\n,]}" end)
    str = to_string(tok)

    val =
      case String.downcase(str) do
        "true" ->
          true

        "false" ->
          false

        _ ->
          cond do
            Regex.match?(~r/^[-+]?(0|[1-9][0-9]*)\.[0-9]+$/u, str) -> String.to_float(str)
            Regex.match?(~r/^[-+]?(0|[1-9][0-9]*)$/u, str) -> String.to_integer(str)
            # CURIE or term: left for expander
            Regex.match?(~r/^[^\s]+:[^\s]+$/u, str) -> str
            true -> str
          end
      end

    {val, skip_ws(rest)}
  end

  defp parse_list_items([?] | rest], _depth, _opts, acc), do: {Enum.reverse(acc), rest}

  defp parse_list_items(chars, depth, opts, acc) do
    {val, rest} = parse_value(chars, depth + 1, opts)
    rest2 = skip_ws(rest)
    rest3 = if match?([?, | _], rest2), do: skip_ws(tl(rest2)), else: rest2
    parse_list_items(rest3, depth, opts, [val | acc])
  end

  # ——— helpers ———
  defp skip_ws([c | rest]) when c in ~c"\s\t\n\r", do: skip_ws(rest)
  defp skip_ws(chars), do: chars

  defp skip_separators(chars) do
    chars
    |> skip_ws()
    |> (fn
          [?, | rest] -> skip_ws(rest)
          other -> other
        end).()
  end

  defp expect_char([c | rest], c), do: rest
  defp expect_char(chars, _), do: chars

  defp take_while(chars, fun), do: do_take_while(chars, fun, [])

  defp do_take_while([c | rest], fun, acc) do
    if fun.(c), do: do_take_while(rest, fun, [c | acc]), else: {Enum.reverse(acc), [c | rest]}
  end

  defp do_take_while([], _fun, acc), do: {Enum.reverse(acc), []}

  defp take_until([c | rest], stop, acc \\ []) do
    if c == stop, do: {Enum.reverse(acc), [c | rest]}, else: take_until(rest, stop, [c | acc])
  end

  defp take_string([?" | rest], acc), do: {acc |> Enum.reverse() |> to_string(), rest}
  defp take_string([?\\, c | rest], acc), do: take_string(rest, [c | acc])
  defp take_string([c | rest], acc), do: take_string(rest, [c | acc])

  defp parse_string_annotation([?@ | rest]) do
    {lang, rest1} = take_while(rest, fn c -> c in ?a..?z or c in ?A..?Z or c in ~c"-_" end)
    {{:lang, to_string(lang)}, rest1}
  end

  defp parse_string_annotation([?^, ?^ | rest]) do
    {dt, rest1} = take_while(rest, fn c -> c not in ~c" \t\n,]}" end)
    {{:type, to_string(dt)}, rest1}
  end

  defp parse_string_annotation(other), do: {:none, other}
end
