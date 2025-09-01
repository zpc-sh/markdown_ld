defmodule MarkdownLd.CDFM do
  @moduledoc """
  Helpers for CDFM-style handoff payloads (manifest, hashes, and safe path ops).

  This is a file-based transport abstraction designed to be API-ready later.
  """

  @type entry :: %{
          required(:path) => String.t(),
          required(:dest) => String.t(),
          required(:size_bytes) => non_neg_integer(),
          required(:sha256) => String.t()
        }

  def request_root!(id) do
    root = Path.join([File.cwd!(), "work", "spec_requests", id])
    File.dir?(root) || Mix.raise("Request folder not found: #{root}")
    root
  end

  def list_outbox_msgs!(root, pattern \\ "msg_*.json") do
    outbox = Path.join(root, "outbox")
    for path <- Path.wildcard(Path.join(outbox, pattern)), File.regular?(path) do
      %{path: path, dest: Path.join("inbox", Path.basename(path))}
    end
  end

  def list_referenced_attachments!(root, msg_paths) do
    Enum.flat_map(msg_paths, fn m ->
      mjson = Jason.decode!(File.read!(m.path))
      for rel <- mjson["attachments"] || [] do
        with {:ok, abs} <- safe_join(root, rel) do
          %{path: abs, dest: rel}
        else
          _ -> []
        end
      end
    end)
    |> uniq_by(:dest)
  end

  def entries_with_hashes(entries) do
    Enum.map(entries, fn e ->
      size = file_size!(e.path)
      sha = sha256!(e.path)
      Map.merge(e, %{size_bytes: size, sha256: sha})
    end)
  end

  def build_manifest!(id, pattern \\ "msg_*.json") do
    root = request_root!(id)
    msgs = list_outbox_msgs!(root, pattern)
    atts = list_referenced_attachments!(root, msgs)
    %{
      request_id: id,
      source_root: Path.relative_to(root, File.cwd!()),
      messages: entries_with_hashes(msgs),
      attachments: entries_with_hashes(atts),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  def safe_join(root, rel) do
    cond do
      Path.type(rel) == :absolute -> {:error, :absolute}
      String.contains?(rel, "..") ->
        expanded_root = Path.expand(root)
        expanded = Path.expand(Path.join(expanded_root, rel))
        if String.starts_with?(expanded, expanded_root <> "/") or expanded == expanded_root, do: {:ok, expanded}, else: {:error, :escape}
      true ->
        {:ok, Path.expand(Path.join(root, rel))}
    end
  end

  defp uniq_by(list, key), do: list |> Enum.uniq_by(&Map.get(&1, key))

  defp file_size!(path) do
    case :file.read_file_info(String.to_charlist(path)) do
      {:ok, info} -> info.size
      _ -> 0
    end
  end

  defp sha256!(path) do
    {:ok, bin} = File.read(path)
    :crypto.hash(:sha256, bin) |> Base.encode16(case: :lower)
  end
end

