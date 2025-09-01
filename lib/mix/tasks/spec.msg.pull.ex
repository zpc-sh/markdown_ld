defmodule Mix.Tasks.Spec.Msg.Pull do
  use Mix.Task
  @shortdoc "Pull peer outbox messages into local inbox"
  @moduledoc """
  Usage:
    mix spec.msg.pull --id <request_id> [--from /path/to/peer/work/spec_requests/<id>/outbox] [--only 'msg_*.json'] [--dry-run]

  If --from is omitted, builds it from SPEC_HANDOFF_DIR: $SPEC_HANDOFF_DIR/<id>/outbox
  """

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [id: :string, from: :string, only: :string, dry_run: :boolean])
    id = req!(opts, :id)
    from_outbox =
      case Keyword.get(opts, :from) do
        nil ->
          base = System.get_env("SPEC_HANDOFF_DIR") || Mix.raise("Provide --from or set SPEC_HANDOFF_DIR")
          Path.join([base, id, "outbox"])
        v -> v
      end

    dest_root = Path.join(["work", "spec_requests", id])
    inbox = Path.join(dest_root, "inbox")
    File.mkdir_p!(inbox)

    pattern = Keyword.get(opts, :only) || "msg_*.json"
    dry = Keyword.get(opts, :dry_run, false)

    for msg_path <- Path.wildcard(Path.join(from_outbox, pattern)) do
      dest = Path.join(inbox, Path.basename(msg_path))
      if dry, do: Mix.shell().info("DRY: copy #{msg_path} -> #{dest}"), else: File.cp!(msg_path, dest)
      Mix.shell().info((dry && "DRY pulled " || "Pulled ") <> Path.basename(msg_path))
    end
  end

  defp req!(opts, key), do: Keyword.get(opts, key) || Mix.raise("Missing --#{key}")
end
