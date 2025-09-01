defmodule MarkdownLd.Fallback do
  @moduledoc """
  Pure-Elixir fallback parser for MarkdownLd when NIFs are unavailable or disabled.

  Provides a deterministic, reasonably fast parser that extracts headings, links,
  code blocks, tasks, and a word count. Intended for tests and environments without
  native support.
  """

  @type heading :: %{level: 1..6, text: String.t(), line: pos_integer()}
  @type link :: %{text: String.t(), url: String.t(), line: pos_integer()}
  @type code_block :: %{language: String.t() | nil, content: String.t(), line: pos_integer()}
  @type task :: %{completed: boolean(), text: String.t(), line: pos_integer()}

  @spec parse(String.t(), keyword()) :: {:ok, map()}
  def parse(content, _opts \\ []) when is_binary(content) do
    {us, result} = :timer.tc(fn -> do_parse(content) end)
    {:ok, Map.put(result, :processing_time_us, us)}
  end

  defp do_parse(content) do
    lines = String.split(content, "\n", trim: false)
    headings = headings(lines)
    links = links(lines)
    {code_blocks, _} = code_blocks(lines)
    tasks = tasks(lines)
    %{ 
      headings: headings,
      links: links,
      code_blocks: code_blocks,
      tasks: tasks,
      word_count: word_count(content)
    }
  end

  defp headings(lines) do
    Enum.with_index(lines, 1)
    |> Enum.reduce([], fn {line, ln}, acc ->
      case Regex.run(~r/^(#+)\s+(.*)$/, line) do
        [_, hashes, text] -> [%{level: min(String.length(hashes), 6), text: String.trim(text), line: ln} | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  defp links(lines) do
    Enum.with_index(lines, 1)
    |> Enum.flat_map(fn {line, ln} ->
      Regex.scan(~r/\[([^\]]+)\]\(([^\)\s]+)(?:\s+"[^"]*")?\)/, line)
      |> Enum.map(fn [_, text, url] -> %{text: text, url: url, line: ln} end)
    end)
  end

  defp code_blocks(lines), do: collect_code_blocks(lines, nil, [], [], 1)
  defp collect_code_blocks([], nil, acc, _buf, _ln), do: {Enum.reverse(acc), []}
  defp collect_code_blocks([], {:in, lang, start_ln}, acc, buf, _ln) do
    block = %{language: lang, content: Enum.reverse(buf) |> Enum.join("\n"), line: start_ln}
    {Enum.reverse([block | acc]), []}
  end
  defp collect_code_blocks([line | rest], nil, acc, _buf, ln) do
    case Regex.run(~r/^```\s*([A-Za-z0-9_+-]*)\s*$/, line) do
      [_, lang] -> collect_code_blocks(rest, {:in, blank_to_nil(lang), ln}, acc, [], ln + 1)
      _ -> collect_code_blocks(rest, nil, acc, [], ln + 1)
    end
  end
  defp collect_code_blocks([line | rest], {:in, lang, start_ln}, acc, buf, ln) do
    if Regex.match?(~r/^```\s*$/, line) do
      block = %{language: lang, content: Enum.reverse(buf) |> Enum.join("\n"), line: start_ln}
      collect_code_blocks(rest, nil, [block | acc], [], ln + 1)
    else
      collect_code_blocks(rest, {:in, lang, start_ln}, acc, [line | buf], ln + 1)
    end
  end

  defp tasks(lines) do
    Enum.with_index(lines, 1)
    |> Enum.reduce([], fn {line, ln}, acc ->
      case Regex.run(~r/^\s*[-*]\s*\[( |x|X)\]\s+(.*)$/, line) do
        [_, " ", text] -> [%{completed: false, text: String.trim(text), line: ln} | acc]
        [_, _x, text] -> [%{completed: true, text: String.trim(text), line: ln} | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  defp word_count(content) do
    Regex.scan(~r/[\p{L}\p{N}_]+/u, content) |> length()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s
end

