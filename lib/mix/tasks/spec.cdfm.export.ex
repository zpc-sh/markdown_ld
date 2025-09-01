defmodule Mix.Tasks.Spec.Cdfm.Export do
  use Mix.Task
  @shortdoc "Export a CDFM manifest (messages + attachments)"
  @moduledoc """
  Usage:
    mix spec.cdfm.export --id <request_id> [--only 'msg_*.json'] [--out work/spec_requests/<id>/handoff_manifest.json]

  Generates a JSON manifest containing outbox messages and referenced attachments,
  with sizes and sha256 checksums, ready to POST to a CDFM service or to share offline.
  """

  alias MarkdownLd.CDFM

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [id: :string, only: :string, out: :string])
    id = req!(opts, :id)
    pattern = Keyword.get(opts, :only, "msg_*.json")
    out = Keyword.get(opts, :out)

    manifest = CDFM.build_manifest!(id, pattern)
    json = Jason.encode_to_iodata!(manifest, pretty: true)

    case out do
      nil -> IO.binwrite(json)
      path ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, json)
        Mix.shell().info("Wrote CDFM manifest: #{path}")
    end
  end

  defp req!(opts, key), do: Keyword.get(opts, key) || Mix.raise("Missing --#{key}")
end

