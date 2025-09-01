defmodule Mix.Tasks.Spec.Cdfm.Import do
  use Mix.Task
  @shortdoc "Import a CDFM manifest into a local request inbox/attachments"
  @moduledoc """
  Usage:
    mix spec.cdfm.import --id <request_id> --manifest path/to/manifest.json [--dry-run]

  Reads a CDFM manifest and copies listed messages to `inbox/` and attachments under the
  request root. Verifies sha256 for integrity.
  """

  alias MarkdownLd.CDFM

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [id: :string, manifest: :string, dry_run: :boolean])
    id = req!(opts, :id)
    manifest_path = req!(opts, :manifest)
    dry = Keyword.get(opts, :dry_run, false)

    root = CDFM.request_root!(id)
    data = Jason.decode!(File.read!(manifest_path))

    Enum.each(data["messages"] || [], fn m ->
      src = Path.join([File.cwd!(), m["path"]])
      dest = Path.join(root, m["dest"])
      copy_with_checks!(src, dest, m["sha256"], m["size_bytes"], dry)
    end)

    Enum.each(data["attachments"] || [], fn a ->
      src = Path.join([File.cwd!(), a["path"]])
      dest = Path.join(root, a["dest"])
      copy_with_checks!(src, dest, a["sha256"], a["size_bytes"], dry)
    end)

    Mix.shell().info(if(dry, do: "DRY: import complete", else: "Import complete"))
  end

  defp copy_with_checks!(src, dest, sha, size, dry) do
    File.exists?(src) || Mix.raise("Source not found: #{src}")
    actual_size = file_size!(src)
    actual_sha = sha256!(src)
    if to_string(actual_size) != to_string(size), do: Mix.raise("Size mismatch for #{src}")
    if String.downcase(actual_sha) != String.downcase(sha), do: Mix.raise("SHA256 mismatch for #{src}")
    if dry do
      Mix.shell().info("DRY: copy #{src} -> #{dest}")
    else
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(src, dest)
      Mix.shell().info("Copied #{Path.basename(src)}")
    end
  end

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

  defp req!(opts, key), do: Keyword.get(opts, key) || Mix.raise("Missing --#{key}")
end

