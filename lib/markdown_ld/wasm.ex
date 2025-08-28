defmodule MarkdownLd.WASM do
  @moduledoc """
  Extract and diff WASM module fences from Markdown.

  Fences:
  - ```application/wasm {ldw:module=ID ldw:entry=_start ldw:wasi=true|false}
     <base64>
    ```
  - ```application/wasm+json {ldw:config-for=ID}
     { ... }
    ```
  """

  alias MarkdownLd.JCS

  @type module :: %{
          kind: :module | :config,
          id: String.t(),
          hash: String.t() | nil,
          attrs: map(),
          line: non_neg_integer()
        }

  @spec extract(String.t()) :: [module()]
  def extract(text) when is_binary(text) do
    lines = String.split(text, "\n", trim: false)
    do_extract(lines, 1, [], nil, nil)
  end

  defp do_extract([], _ln, acc, _mode, _buf), do: Enum.reverse(acc)
  defp do_extract([line | rest], ln, acc, nil, _buf) do
    cond do
      m = Regex.run(~r/^```\s*application\/wasm\s*(\{[^}]*\})?\s*$/, line, capture: :all_but_first) ->
        do_extract(rest, ln + 1, acc, {:module, ln, parse_attrs_opt(m)}, [])
      m = Regex.run(~r/^```\s*application\/wasm\+json\s*(\{[^}]*\})?\s*$/, line, capture: :all_but_first) ->
        do_extract(rest, ln + 1, acc, {:config, ln, parse_attrs_opt(m)}, [])
      true -> do_extract(rest, ln + 1, acc, nil, nil)
    end
  end
  defp do_extract([line | rest], ln, acc, {:module, start_ln, attrs}, buf) do
    if String.match?(line, ~r/^```\s*$/) do
      b64 = Enum.reverse(buf) |> Enum.join("") |> String.trim()
      hash = hash_b64(b64)
      id = attrs["ldw:module"] || short_id(%{"entry" => attrs["ldw:entry"], "wasi" => attrs["ldw:wasi"], "hash" => hash})
      mod = %{kind: :module, id: id, hash: hash, attrs: attrs, line: start_ln}
      do_extract(rest, ln + 1, [mod | acc], nil, nil)
    else
      do_extract(rest, ln + 1, acc, {:module, start_ln, attrs}, [String.trim(line) | buf])
    end
  end
  defp do_extract([line | rest], ln, acc, {:config, start_ln, attrs}, buf) do
    if String.match?(line, ~r/^```\s*$/) do
      json = Enum.reverse(buf) |> Enum.join("\n")
      hash = case Jason.decode(json) do
        {:ok, data} -> sha256_hex(JCS.encode(data))
        _ -> nil
      end
      id = attrs["ldw:config-for"] || ""
      cfg = %{kind: :config, id: id, hash: hash, attrs: attrs, line: start_ln}
      do_extract(rest, ln + 1, [cfg | acc], nil, nil)
    else
      do_extract(rest, ln + 1, acc, {:config, start_ln, attrs}, [line | buf])
    end
  end

  defp parse_attrs_opt([]), do: %{}
  defp parse_attrs_opt([attrs]), do: parse_attrs(attrs)
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

  defp hash_b64(b64) do
    case Base.decode64(b64) do
      {:ok, bin} -> sha256_hex(bin)
      _ -> nil
    end
  end

  defp short_id(map), do: JCS.encode(map) |> sha256_hex() |> binary_part(0, 12)
  defp sha256_hex(bin), do: :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)

  @doc """
  Diff two markdown texts for WASM modules/configs.
  Returns list of maps: :wasm_add, :wasm_remove, :wasm_update.
  """
  @spec diff(String.t(), String.t()) :: [map()]
  def diff(a, b) do
    aa = index_by_id(extract(a))
    bb = index_by_id(extract(b))
    removed =
      for {id, s} <- aa, Map.get(bb, id) == nil, s.kind == :module do
        %{kind: :wasm_remove, payload: s}
      end
    added =
      for {id, s} <- bb, Map.get(aa, id) == nil, s.kind == :module do
        %{kind: :wasm_add, payload: s}
      end
    updated =
      for {id, sa} <- aa, sb = Map.get(bb, id), sb != nil, sa.hash != sb.hash do
        %{kind: :wasm_update, payload: %{before: sa, after: sb}}
      end
    removed ++ updated ++ added
  end

  defp index_by_id(list) do
    list
    |> Enum.filter(&(&1.id && &1.id != ""))
    |> Map.new(fn s -> {s.id, s} end)
  end
end
