defmodule MarkdownLd.JCS do
  @moduledoc """
  Pragmatic JSON Canonicalization Scheme (JCS) encoder.

  This aims for RFC 8785 compatibility for common payloads by:
  - Converting map keys to strings and sorting them lexicographically
  - Recursively normalizing lists and maps
  - Using compact JSON (no whitespace)

  Notes:
  - Numbers are passed through as given; callers should provide numeric values
    with their desired lexical representation if strict control is needed.
  - This covers the majority of deterministic hashing needs in this project
    (blank node IDs, chunk payloads, JSON-literal comparisons).
  """

  @doc """
  Canonicalize an Elixir term into a JCS-style JSON string.
  """
  @spec encode(any()) :: String.t()
  def encode(term) do
    term |> normalize() |> Jason.encode!()
  end

  defp normalize(%{} = map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), normalize(v)} end)
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.into(%{}, fn {k, v} -> {k, v} end)
  end
  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(other), do: other
end

