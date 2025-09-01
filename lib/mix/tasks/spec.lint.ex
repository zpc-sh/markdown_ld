defmodule Mix.Tasks.Spec.Lint do
  use Mix.Task
  @shortdoc "Validate request, ack, and messages; check attachments; render thread"
  @moduledoc """
  Usage:
    mix spec.lint --id <request_id>

  Performs lightweight checks:
  - request.json exists and is valid JSON
  - ack.json (if present) is valid JSON
  - messages in inbox/outbox are valid JSON and have bodies
  - attachments referenced by messages exist
  - renders thread.md successfully
  """

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [id: :string])
    id = Keyword.get(opts, :id) || Mix.raise("Missing --id")

    root = Path.join(["work", "spec_requests", id])
    req_path = Path.join(root, "request.json")
    ack_path = Path.join(root, "ack.json")

    ok =
      file_json(req_path, "request.json") and
      ack_ok?(root, ack_path) and
      messages_ok?(root) and
      render_ok?(id)

    if ok, do: Mix.shell().info("Lint OK for #{id}"), else: Mix.raise("Lint failed for #{id}")
  end

  defp file_json(path, label) do
    with true <- File.exists?(path) || (Mix.shell().error("Missing #{label}"); false),
         {:ok, _} <- decode(path) do
      true
    else
      _ -> false
    end
  end

  defp optional_json(path, _label) do
    if File.exists?(path) do
      case decode(path) do
        {:ok, _} -> true
        _ -> (Mix.shell().error("Invalid JSON: #{path}"); false)
      end
    else
      true
    end
  end

  defp decode(path) do
    try do
      {:ok, Jason.decode!(File.read!(path))}
    rescue
      _ -> {:error, :invalid}
    end
  end

  defp messages_ok?(root) do
    [Path.join(root, "inbox"), Path.join(root, "outbox")]
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "msg_*.json")))
    |> Enum.map(fn mpath ->
      case decode(mpath) do
        {:ok, m} ->
          schema_path = Path.join([File.cwd!(), "work", "spec_requests", "message.schema.json"])
          case validate_schema(m, schema_path) do
            :ok ->
              body_ok = is_binary(m["body"]) and byte_size(m["body"]) > 0
              atts_ok = Enum.all?(m["attachments"] || [], fn rel -> File.exists?(Path.join(root, rel)) end)
              if not body_ok, do: Mix.shell().error("Empty body: #{mpath}")
              if not atts_ok, do: Mix.shell().error("Missing attachment for #{mpath}")
              body_ok and atts_ok
            {:error, reason} -> Mix.shell().error("Message schema violation (#{mpath}): #{reason}"); false
          end
        _ -> Mix.shell().error("Invalid message JSON: #{mpath}"); false
      end
    end)
    |> Enum.all?()
  end

  defp ack_ok?(root, ack_path) do
    if File.exists?(ack_path) do
      case decode(ack_path) do
        {:ok, ack} ->
          schema_path = Path.join([File.cwd!(), "work", "spec_requests", "ack.schema.json"])
          case validate_schema(ack, schema_path) do
            :ok -> true
            {:error, reason} -> Mix.shell().error("Ack schema violation: #{reason}"); false
          end
        _ -> Mix.shell().error("Invalid JSON: #{ack_path}"); false
      end
    else
      true
    end
  end

  defp validate_schema(map, schema_path) when is_map(map) do
    try do
      schema = schema_path |> File.read!() |> Jason.decode!()
      do_validate(map, schema)
    rescue
      e -> {:error, "failed to read schema #{schema_path}: #{inspect(e)}"}
    end
  end

  defp do_validate(map, %{"type" => "object"} = schema) when is_map(map) do
    # required fields
    required = Map.get(schema, "required", [])
    with true <- Enum.all?(required, &Map.has_key?(map, &1)) || {:error, "missing required: #{Enum.join(required -- Map.keys(map), ", ")}"},
         :ok <- props_ok(map, Map.get(schema, "properties", %{})) do
      :ok
    else
      {:error, _} = err -> err
      false -> {:error, "object validation failed"}
    end
  end
  defp do_validate(value, %{"type" => "string", "enum" => enum}) do
    if is_binary(value) and value in enum, do: :ok, else: {:error, "expected one of #{Enum.join(enum, ", ")}"}
  end
  defp do_validate(value, %{"type" => "string"}) do
    if is_binary(value), do: :ok, else: {:error, "expected string"}
  end
  defp do_validate(value, %{"type" => "array", "items" => %{"type" => "string"}}) do
    if is_list(value) and Enum.all?(value, &is_binary/1), do: :ok, else: {:error, "expected array of strings"}
  end
  defp do_validate(value, %{"type" => "object", "required" => req, "properties" => props}) when is_map(value) do
    with true <- Enum.all?(req, &Map.has_key?(value, &1)) || {:error, "missing required: #{Enum.join(req -- Map.keys(value), ", ")}"},
         :ok <- props_ok(value, props) do
      :ok
    else
      {:error, _} = err -> err
      false -> {:error, "object validation failed"}
    end
  end
  defp do_validate(_v, _schema), do: :ok

  defp props_ok(map, props) do
    Enum.reduce_while(props, :ok, fn {k, pschema}, acc ->
      case Map.fetch(map, k) do
        :error -> {:cont, acc}
        {:ok, v} -> case do_validate(v, pschema) do
          :ok -> {:cont, acc}
          {:error, reason} -> {:halt, {:error, "#{k}: #{reason}"}}
        end
      end
    end)
  end

  defp render_ok?(id) do
    try do
      Mix.Task.run("spec.thread.render", ["--id", id])
      true
    rescue
      e -> Mix.shell().error("thread render failed: #{inspect(e)}"); false
    end
  end
end
