defmodule MarkdownLd.Determinism do
  @moduledoc """
  Deterministic helpers for Markdown-LD:
  - Slug generation (Appendix A)
  - Text normalization for hashing (Appendix B)
  - Stable chunk IDs per spec v0.3
  """

  alias MarkdownLd.JCS

  @doc """
  Compute a stable slug from heading text (Appendix A).

  Steps:
  - Lowercase and trim
  - NFKD then strip diacritics (combining marks)
  - Remove punctuation except '-' and '_'
  - Collapse all whitespace to single '-'
  - Collapse multiple '-' and trim leading/trailing '-'
  """
  @spec slug(String.t()) :: String.t()
  def slug(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> :unicode.characters_to_nfd_binary()
    |> remove_combining_marks()
    |> keep_allowed_chars()
    |> collapse_space_to_hyphen()
    |> collapse_hyphens()
    |> String.trim("-")
  end

  @doc """
  Normalize block text for hashing (Appendix B).
  - Normalize line endings to "\n"
  - Trim trailing spaces on each line
  - Collapse runs of spaces/tabs to a single space
  - Remove trailing blank lines
  """
  @spec text_norm(String.t()) :: String.t()
  def text_norm(text) when is_binary(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n", trim: false)
    |> Enum.map(&trim_trailing_spaces/1)
    |> Enum.map(&collapse_space_tab/1)
    |> drop_trailing_blank_lines()
    |> Enum.join("\n")
  end

  @doc """
  Compute stable chunk ID per v0.3:
  id = sha256(jcs({heading_path, block_index, text_hash}))[:12]
  Returns the lowercase hex string of length 12.
  """
  @spec chunk_id([String.t()], non_neg_integer(), String.t()) :: String.t()
  def chunk_id(heading_path, block_index, text) do
    payload = %{
      "heading_path" => heading_path,
      "block_index" => block_index,
      "text_hash" => sha256_hex(text_norm(text))
    }

    payload
    |> JCS.encode()
    |> sha256_hex()
    |> binary_part(0, 12)
  end

  # ——— internals ———

  defp remove_combining_marks(nfd) do
    Regex.replace(~r/\p{Mn}+/u, nfd, "")
  end

  # Keep letters, digits, whitespace, '-' and '_' ; drop other punctuation
  defp keep_allowed_chars(str) do
    str
    |> String.replace(~r/[^a-z0-9_\-\s]+/u, "")
  end

  defp collapse_space_to_hyphen(str) do
    str
    |> String.replace(~r/[\s\t]+/u, "-")
  end

  defp collapse_hyphens(str) do
    String.replace(str, ~r/-{2,}/, "-")
  end

  defp trim_trailing_spaces(line), do: String.replace(line, ~r/[ \t]+$/u, "")

  defp collapse_space_tab(line), do: String.replace(line, ~r/[ \t]+/u, " ")

  defp drop_trailing_blank_lines(lines) do
    Enum.reverse(lines)
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.reverse()
  end

  defp sha256_hex(data) when is_binary(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end
end

