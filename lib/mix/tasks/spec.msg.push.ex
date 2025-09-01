defmodule Mix.Tasks.Spec.Msg.Push do
  use Mix.Task
  @shortdoc "Push outbox messages (and referenced attachments) to a peer's inbox"
  @moduledoc """
  Usage:
    mix spec.msg.push --id <request_id> [--dest /path/to/peer/work/spec_requests/<id>/inbox] [--only 'msg_*.json'] [--dry-run]

  If --dest is omitted, builds it from SPEC_HANDOFF_DIR: $SPEC_HANDOFF_DIR/<id>/inbox
  """

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [id: :string, dest: :string, only: :string, dry_run: :boolean])
    id = req!(opts, :id)
    dest_inbox =
      case Keyword.get(opts, :dest) do
        nil ->
          base = System.get_env("SPEC_HANDOFF_DIR") || Mix.raise("Provide --dest or set SPEC_HANDOFF_DIR")
          Path.join([base, id, "inbox"])
        v -> v
      end

    src_root = Path.join(["work", "spec_requests", id])
    outbox = Path.join(src_root, "outbox")
    File.dir?(outbox) || Mix.raise("Outbox not found: #{outbox}")

    File.mkdir_p!(dest_inbox)

    pattern = Keyword.get(opts, :only) || "msg_*.json"
    dry = Keyword.get(opts, :dry_run, false)

    dest_req_root = dest_inbox |> Path.expand("..")

    for msg_path <- Path.wildcard(Path.join(outbox, pattern)) do
      msg = Jason.decode!(File.read!(msg_path))
      msg_basename = Path.basename(msg_path)
      dest_msg = Path.join(dest_inbox, msg_basename)
      if dry do
        Mix.shell().info("DRY: copy #{msg_path} -> #{dest_msg}")
      else
        File.cp!(msg_path, dest_msg)
      end
      # copy attachments referenced by this message with path containment checks
      Enum.each(msg["attachments"] || [], fn rel_path ->
        with {:ok, src} <- safe_join(src_root, rel_path),
             {:ok, target} <- safe_join(dest_req_root, rel_path) do
          File.mkdir_p!(Path.dirname(target))
          if dry, do: Mix.shell().info("DRY: copy #{src} -> #{target}"), else: File.cp!(src, target)
        else
          {:error, reason} -> Mix.shell().error("Skip attachment '#{rel_path}': #{reason}")
        end
      end)
      Mix.shell().info((dry && "DRY pushed " || "Pushed ") <> msg_basename)
    end
  end

  defp req!(opts, key), do: Keyword.get(opts, key) || Mix.raise("Missing --#{key}")
  defp safe_join(root, rel) do
    if Path.type(rel) == :absolute, do: {:error, "absolute path not allowed"},
      else: begin
        expanded_root = Path.expand(root)
        expanded = Path.expand(Path.join(expanded_root, rel))
        if String.starts_with?(expanded, expanded_root <> "/") or expanded == expanded_root do
          {:ok, expanded}
        else
          {:error, "path escapes root"}
        end
      end
  end
end
