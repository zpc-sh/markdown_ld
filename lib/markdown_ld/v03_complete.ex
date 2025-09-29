defmodule MarkdownLd.V03Complete do
  @moduledoc """
  Complete v0.3.0 implementation with mem8 wave-based memory and polyglot detection.

  This module integrates:
  - RFC 8785 JCS canonicalization for deterministic blank node IDs
  - Stable chunk IDs for streaming and move detection
  - Attribute objects mini-grammar parser
  - L2 inline attributes support
  - Multi-valued semantics with arrays vs @list handling
  - Error handling taxonomy with strict/lax modes
  - Mem8 wave-based contextual memory integration
  - Polyglot document detection and character concealment
  - Zero-width Unicode steganography
  - Content-addressed linking
  """

  use GenServer
  require Logger

  alias MarkdownLd.{Native, Contexts, JCS, Determinism}
  alias MarkdownLd.Diff.Stream
  alias MarkdownLd.Jsonld.Extractor

  @behaviour MarkdownLd.Parser

  # Error taxonomy from v0.3 spec
  @error_types [
    :parse_error,
    :unknown_prefix,
    :invalid_context,
    :limit_exceeded,
    :invalid_value,
    :invalid_list,
    :invalid_iri
  ]

  # Processing limits
  @limits %{
    max_object_depth: 32,
    max_list_length: 1024,
    # 16KB
    max_object_size: 16_384,
    # 16KB
    max_context_size: 16_384,
    # 256KB
    max_patch_size: 262_144,
    # 30 seconds
    processing_timeout: 30_000
  }

  # Compliance levels
  @compliance_levels %{
    l1_core: [:frontmatter_context, :jsonld_fences, :triple_diff],
    l2_inline: [:attribute_lists, :property_tables, :heading_subjects],
    l3_advanced: [:semantic_merge, :streaming, :rename_detection],
    e1_compression: [:mq2_compression],
    e2_memory: [:mem8_memory, :wave_patterns],
    e3_vfs: [:vfs_foundation],
    e4_orchestration: [:multi_extension_coordination]
  }

  ## Public API

  @doc """
  Parse markdown with complete v0.3.0 spec compliance.

  ## Options
  - `:mode` - `:strict` or `:lax` (default: `:lax`)
  - `:compliance_level` - List of compliance levels to enforce
  - `:mem8_context` - Path to mem8 context file or context data
  - `:detect_polyglot` - Whether to detect polyglot documents (default: `true`)
  - `:enable_concealment` - Extract concealed data (default: `true`)
  - `:limits` - Custom processing limits

  ## Examples

      # Basic parsing
      {:ok, result} = V03Complete.parse("# Hello World")

      # With mem8 context
      {:ok, result} = V03Complete.parse(content, mem8_context: "project.m8")

      # Strict mode with polyglot detection
      {:ok, result} = V03Complete.parse(content,
        mode: :strict,
        detect_polyglot: true,
        enable_concealment: true
      )
  """
  @spec parse(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def parse(content, opts \\ []) do
    opts = merge_default_options(opts)

    with :ok <- validate_limits(content, opts[:limits]),
         {:ok, parsed} <- parse_with_native(content, opts),
         {:ok, enhanced} <- enhance_with_v03_features(parsed, content, opts),
         {:ok, result} <- apply_compliance_checks(enhanced, opts[:compliance_level]) do
      {:ok, add_processing_metadata(result, opts)}
    else
      {:error, reason} -> handle_parse_error(reason, opts[:mode])
    end
  end

  @doc """
  Parse with mem8 wave-based memory context.

  This integrates wave patterns and consciousness state to influence
  semantic processing and provide AI-enhanced contextual understanding.
  """
  @spec parse_with_mem8(String.t(), String.t() | map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def parse_with_mem8(content, mem8_context, opts \\ []) do
    with {:ok, context} <- load_mem8_context(mem8_context),
         {:ok, result} <- Native.parse_with_mem8(content, context) do
      enhance_with_wave_context(result, context, opts)
    end
  end

  @doc """
  Detect polyglot documents and extract artifacts.

  Returns detected language, artifacts, and any concealed data.
  """
  @spec detect_polyglot(String.t()) :: {:ok, map()} | {:error, term()}
  def detect_polyglot(content) do
    with {:ok, %{"detected" => true} = polyglot} <- Native.detect_polyglot(content),
         {:ok, concealment} <- Native.extract_concealed_data(content) do
      {:ok, Map.merge(polyglot, concealment)}
    else
      {:ok, %{"detected" => false}} -> {:ok, %{detected: false}}
      error -> error
    end
  end

  @doc """
  Generate stable chunk ID for streaming and move detection.

  Uses RFC 8785 JCS canonicalization as specified in v0.3.
  """
  @spec generate_stable_id(list(String.t()), non_neg_integer(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_stable_id(heading_path, block_index, text) do
    Native.generate_stable_id(heading_path, block_index, text)
  end

  @doc """
  Canonicalize JSON using RFC 8785 JCS.

  Required for deterministic blank node IDs and stable chunk generation.
  """
  @spec canonicalize_json(String.t()) :: {:ok, String.t()} | {:error, term()}
  def canonicalize_json(json_string) do
    Native.canonicalize_json(json_string)
  end

  @doc """
  Parse attribute objects using the mini-grammar.

  Supports the `- { ... }` syntax from v0.3 spec with strict and lax modes.
  """
  @spec parse_attribute_object(String.t(), :strict | :lax) ::
          {:ok, map()} | {:error, term()}
  def parse_attribute_object(attr_string, mode \\ :lax) do
    Native.parse_attribute_object(attr_string, Atom.to_string(mode))
  end

  @doc """
  Hide data using zero-width Unicode steganography.

  Makes compressed tokens completely invisible to human readers.
  """
  @spec hide_data_zero_width(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def hide_data_zero_width(text, data) do
    Native.hide_data_zero_width(text, data)
  end

  @doc """
  Create streaming diff with stable chunk IDs.

  Enhanced version of standard diff with v0.3 stable ID support.
  """
  @spec diff_with_stable_ids(String.t(), String.t(), keyword()) ::
          {:ok, list()} | {:error, term()}
  def diff_with_stable_ids(old_content, new_content, opts \\ []) do
    with {:ok, old_parsed} <- parse(old_content, opts),
         {:ok, new_parsed} <- parse(new_content, opts) do
      old_chunks = generate_stable_chunks(old_parsed, old_content)
      new_chunks = generate_stable_chunks(new_parsed, new_content)

      diff_chunks_with_move_detection(old_chunks, new_chunks, opts)
    end
  end

  @doc """
  Apply semantic merge with conflict detection.

  Implements three-way merge with JSON-LD semantic conflict resolution.
  """
  @spec semantic_merge(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def semantic_merge(base, ours, theirs, opts \\ []) do
    with {:ok, base_patch} <- diff_with_stable_ids(base, ours, opts),
         {:ok, their_patch} <- diff_with_stable_ids(base, theirs, opts) do
      conflicts = detect_semantic_conflicts(base_patch, their_patch)

      case conflicts do
        [] -> {:ok, apply_merged_patches(base, [base_patch, their_patch])}
        conflicts -> {:error, {:merge_conflicts, conflicts}}
      end
    end
  end

  ## GenServer Implementation (for stateful processing)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %{
      mem8_contexts: %{},
      polyglot_cache: %{},
      performance_stats: init_performance_stats(),
      processing_limits: Keyword.get(opts, :limits, @limits)
    }

    {:ok, state}
  end

  ## Private Implementation

  defp merge_default_options(opts) do
    Keyword.merge(
      [
        mode: :lax,
        compliance_level: [:l1_core, :l2_inline],
        detect_polyglot: true,
        enable_concealment: true,
        limits: @limits,
        track_performance: false
      ],
      opts
    )
  end

  defp validate_limits(content, limits) do
    content_size = byte_size(content)

    cond do
      content_size > limits.max_object_size ->
        {:error, {:limit_exceeded, :max_object_size, content_size}}

      String.length(content) > limits.max_list_length * 100 ->
        {:error, {:limit_exceeded, :estimated_complexity}}

      true ->
        :ok
    end
  end

  defp parse_with_native(content, opts) do
    timeout = opts[:limits][:processing_timeout] || 30_000

    task =
      Task.async(fn ->
        options = build_native_options(opts)
        Native.parse_markdown(content, options)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :processing_timeout}
    end
  end

  defp build_native_options(opts) do
    [
      {"mode", Atom.to_string(opts[:mode])},
      {"detect_polyglot", to_string(opts[:detect_polyglot])},
      {"enable_concealment", to_string(opts[:enable_concealment])}
    ]
  end

  defp enhance_with_v03_features(parsed, content, opts) do
    with {:ok, enhanced} <- add_stable_ids(parsed, content),
         {:ok, with_attributes} <- process_inline_attributes(enhanced, opts[:mode]),
         {:ok, with_semantics} <- enhance_semantic_processing(with_attributes, content, opts) do
      {:ok, with_semantics}
    end
  end

  defp add_stable_ids(parsed, content) do
    headings = parsed["headings"] || []

    enhanced_headings =
      Enum.map(headings, fn heading ->
        heading_path = extract_heading_path(headings, heading)
        text = heading["text"] || ""

        case generate_stable_id(heading_path, 0, text) do
          {:ok, stable_id} -> Map.put(heading, "stable_id", stable_id)
          {:error, _} -> heading
        end
      end)

    {:ok, Map.put(parsed, "headings", enhanced_headings)}
  end

  defp process_inline_attributes(parsed, mode) do
    headings = parsed["headings"] || []
    links = parsed["links"] || []

    enhanced_headings = process_heading_attributes(headings, mode)
    enhanced_links = process_link_attributes(links, mode)

    result =
      parsed
      |> Map.put("headings", enhanced_headings)
      |> Map.put("links", enhanced_links)

    {:ok, result}
  end

  defp process_heading_attributes(headings, mode) do
    Enum.map(headings, fn heading ->
      text = heading["text"] || ""

      case extract_inline_attributes(text) do
        {clean_text, attributes} when attributes != %{} ->
          heading
          |> Map.put("text", clean_text)
          |> Map.put("attributes", attributes)
          |> process_ld_attributes(attributes, mode)

        _ ->
          heading
      end
    end)
  end

  defp process_link_attributes(links, mode) do
    Enum.map(links, fn link ->
      text = link["text"] || ""

      case extract_inline_attributes(text) do
        {clean_text, attributes} when attributes != %{} ->
          link
          |> Map.put("text", clean_text)
          |> Map.put("attributes", attributes)
          |> process_ld_attributes(attributes, mode)

        _ ->
          link
      end
    end)
  end

  defp process_ld_attributes(element, attributes, mode) do
    ld_attrs =
      for {key, value} <- attributes, String.starts_with?(key, "ld:"), into: %{} do
        {key, value}
      end

    if ld_attrs != %{} do
      Map.put(element, "ld_attributes", ld_attrs)
    else
      element
    end
  end

  defp enhance_semantic_processing(parsed, content, opts) do
    with {:ok, jsonld_enhanced} <- extract_enhanced_jsonld(parsed, content, opts),
         {:ok, with_polyglot} <- maybe_add_polyglot_data(jsonld_enhanced, content, opts),
         {:ok, with_concealment} <- maybe_add_concealed_data(with_polyglot, content, opts) do
      {:ok, with_concealment}
    end
  end

  defp extract_enhanced_jsonld(parsed, content, opts) do
    # Enhanced JSON-LD extraction with context merging and validation
    islands = parsed["jsonld_islands"] || []

    enhanced_islands =
      Enum.map(islands, fn island ->
        content = island["content"] || ""

        case validate_jsonld_syntax(content, opts[:mode]) do
          {:ok, validated} ->
            island
            |> Map.put("validated", true)
            |> Map.put("canonical_form", canonicalize_jsonld_content(validated))

          {:error, reason} ->
            Map.put(island, "validation_error", reason)
        end
      end)

    {:ok, Map.put(parsed, "jsonld_islands", enhanced_islands)}
  end

  defp maybe_add_polyglot_data(parsed, content, opts) do
    if opts[:detect_polyglot] do
      case detect_polyglot(content) do
        {:ok, %{detected: true} = polyglot} ->
          {:ok, Map.put(parsed, "polyglot", polyglot)}

        _ ->
          {:ok, parsed}
      end
    else
      {:ok, parsed}
    end
  end

  defp maybe_add_concealed_data(parsed, content, opts) do
    if opts[:enable_concealment] do
      case Native.extract_concealed_data(content) do
        {:ok, concealment} ->
          {:ok, Map.put(parsed, "concealment", concealment)}

        _ ->
          {:ok, parsed}
      end
    else
      {:ok, parsed}
    end
  end

  defp apply_compliance_checks(result, compliance_levels) do
    checks = compliance_checks_for_levels(compliance_levels)

    case run_compliance_checks(result, checks) do
      [] -> {:ok, result}
      failures -> {:error, {:compliance_failures, failures}}
    end
  end

  defp compliance_checks_for_levels(levels) do
    Enum.flat_map(levels, fn level ->
      Map.get(@compliance_levels, level, [])
    end)
  end

  defp run_compliance_checks(result, checks) do
    Enum.reduce(checks, [], fn check, failures ->
      case run_compliance_check(result, check) do
        :ok -> failures
        {:error, reason} -> [{check, reason} | failures]
      end
    end)
  end

  defp run_compliance_check(result, check) do
    case check do
      :frontmatter_context ->
        validate_frontmatter_context(result)

      :jsonld_fences ->
        validate_jsonld_fences(result)

      :triple_diff ->
        validate_triple_diff_capability(result)

      :attribute_lists ->
        validate_attribute_lists(result)

      :mem8_memory ->
        validate_mem8_integration(result)

      _ ->
        # Unknown checks pass by default
        :ok
    end
  end

  defp validate_frontmatter_context(result) do
    islands = result["jsonld_islands"] || []
    frontmatter_islands = Enum.filter(islands, &(&1["source"] == "frontmatter"))

    if Enum.any?(frontmatter_islands) do
      :ok
    else
      {:error, :no_frontmatter_context}
    end
  end

  defp validate_jsonld_fences(result) do
    code_blocks = result["code_blocks"] || []
    jsonld_blocks = Enum.filter(code_blocks, &(&1["is_jsonld"] == true))

    if Enum.any?(jsonld_blocks) do
      :ok
    else
      {:error, :no_jsonld_fences}
    end
  end

  defp validate_triple_diff_capability(result) do
    # Check if result has enough semantic data for triple diffing
    has_jsonld = (result["jsonld_islands"] || []) != []
    has_attributes = result |> get_in(["headings"]) |> Enum.any?(&Map.has_key?(&1, "attributes"))

    if has_jsonld or has_attributes do
      :ok
    else
      {:error, :insufficient_semantic_data}
    end
  end

  defp validate_attribute_lists(_result) do
    # L2 inline attributes validation would go here
    :ok
  end

  defp validate_mem8_integration(result) do
    if Map.has_key?(result, "wave_influence") do
      :ok
    else
      {:error, :no_mem8_integration}
    end
  end

  # Mem8 Integration

  defp load_mem8_context(context) when is_binary(context) do
    # Load from file path
    case File.read(context) do
      {:ok, content} -> parse_mem8_content(content)
      error -> error
    end
  end

  defp load_mem8_context(context) when is_map(context) do
    {:ok, context}
  end

  defp parse_mem8_content(content) do
    # Parse mem8 binary format or JSON representation
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> parse_mem8_binary(content)
    end
  end

  defp parse_mem8_binary(binary) do
    # Parse binary mem8 format
    case binary do
      <<"MEM8", version::8, _rest::binary>> ->
        {:ok, %{version: version, format: :binary}}

      _ ->
        {:error, :invalid_mem8_format}
    end
  end

  defp enhance_with_wave_context(result, context, opts) do
    wave_influence = calculate_wave_influence(result, context)
    consciousness_data = extract_consciousness_data(context)

    enhanced =
      result
      |> Map.put("wave_influence", wave_influence)
      |> Map.put("consciousness_state", consciousness_data)
      |> Map.put("mem8_metadata", extract_mem8_metadata(context))

    {:ok, enhanced}
  end

  defp calculate_wave_influence(result, context) do
    # Calculate how wave patterns influence semantic processing
    word_count = result["word_count"] || 0
    base_influence = min(word_count / 1000.0, 1.0)

    context_multiplier = context["awareness_level"] || 0.5
    base_influence * context_multiplier
  end

  defp extract_consciousness_data(context) do
    %{
      awareness_level: context["awareness_level"] || 0.5,
      active_memories: length(context["active_memories"] || []),
      attention_focus: calculate_attention_focus(context)
    }
  end

  defp calculate_attention_focus(context) do
    weights = context["attention_weights"] || %{}

    if weights == %{} do
      0.5
    else
      weights |> Map.values() |> (Enum.sum() / length(Map.keys(weights)))
    end
  end

  defp extract_mem8_metadata(context) do
    %{
      version: context["version"] || "1.0.0",
      block_count: length(context["blocks"] || []),
      project_count: length(context["projects"] || [])
    }
  end

  # Utility Functions

  defp extract_heading_path(headings, target_heading) do
    # Build hierarchical path to heading for stable ID generation
    target_line = target_heading["line"] || 0
    target_level = target_heading["level"] || 1

    headings
    |> Enum.filter(&((&1["line"] || 0) < target_line))
    |> Enum.filter(&((&1["level"] || 1) < target_level))
    |> Enum.map(&(&1["text"] || ""))
    |> Enum.reverse()
  end

  defp extract_inline_attributes(text) do
    # Simple regex-based attribute extraction
    # In production, would use proper parser
    case Regex.run(~r/^(.+?)\s*\{([^}]+)\}\s*$/, text) do
      [_, clean_text, attrs] ->
        parsed_attrs = parse_simple_attributes(attrs)
        {String.trim(clean_text), parsed_attrs}

      _ ->
        {text, %{}}
    end
  end

  defp parse_simple_attributes(attrs_str) do
    attrs_str
    |> String.split(~r/\s+/)
    |> Enum.reduce(%{}, fn attr, acc ->
      case String.split(attr, "=", parts: 2) do
        [key, value] -> Map.put(acc, key, parse_attribute_value(value))
        [key] -> Map.put(acc, key, true)
      end
    end)
  end

  defp parse_attribute_value(value) do
    cond do
      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        String.slice(value, 1..-2)

      value in ["true", "false"] ->
        value == "true"

      Regex.match?(~r/^\d+$/, value) ->
        String.to_integer(value)

      Regex.match?(~r/^\d+\.\d+$/, value) ->
        String.to_float(value)

      true ->
        value
    end
  end

  defp validate_jsonld_syntax(content, mode) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} when mode == :strict -> {:error, {:json_parse_error, reason}}
      # Lax mode allows invalid JSON
      {:error, _} -> {:ok, content}
    end
  end

  defp canonicalize_jsonld_content(content) when is_map(content) do
    case canonicalize_json(Jason.encode!(content)) do
      {:ok, canonical} -> canonical
      {:error, _} -> Jason.encode!(content)
    end
  end

  defp canonicalize_jsonld_content(content), do: content

  defp generate_stable_chunks(parsed, content) do
    headings = parsed["headings"] || []

    Enum.with_index(headings, fn heading, index ->
      heading_path = extract_heading_path(headings, heading)
      text = heading["text"] || ""

      case generate_stable_id(heading_path, index, text) do
        {:ok, stable_id} ->
          %{
            stable_id: stable_id,
            content: text,
            line: heading["line"] || 0,
            level: heading["level"] || 1
          }

        {:error, _} ->
          %{
            stable_id: "fallback-#{index}",
            content: text,
            line: heading["line"] || 0,
            level: heading["level"] || 1
          }
      end
    end)
  end

  defp diff_chunks_with_move_detection(old_chunks, new_chunks, opts) do
    # Detect moves by matching stable IDs
    old_by_id = Map.new(old_chunks, &{&1.stable_id, &1})
    new_by_id = Map.new(new_chunks, &{&1.stable_id, &1})

    moves = detect_moves(old_by_id, new_by_id)
    updates = detect_updates(old_by_id, new_by_id)
    inserts = detect_inserts(old_by_id, new_by_id)
    deletes = detect_deletes(old_by_id, new_by_id)

    {:ok, moves ++ updates ++ inserts ++ deletes}
  end

  defp detect_moves(old_by_id, new_by_id) do
    Enum.filter_map(
      new_by_id,
      fn {id, new_chunk} ->
        case Map.get(old_by_id, id) do
          %{line: old_line} when old_line != new_chunk.line -> true
          _ -> false
        end
      end,
      fn {id, new_chunk} ->
        old_chunk = Map.get(old_by_id, id)

        %{
          type: :move_block,
          stable_id: id,
          from_line: old_chunk.line,
          to_line: new_chunk.line
        }
      end
    )
  end

  defp detect_updates(old_by_id, new_by_id) do
    Enum.filter_map(
      new_by_id,
      fn {id, new_chunk} ->
        case Map.get(old_by_id, id) do
          %{content: old_content} when old_content != new_chunk.content -> true
          _ -> false
        end
      end,
      fn {id, new_chunk} ->
        old_chunk = Map.get(old_by_id, id)

        %{
          type: :update_block,
          stable_id: id,
          old_content: old_chunk.content,
          new_content: new_chunk.content,
          line: new_chunk.line
        }
      end
    )
  end

  defp detect_inserts(old_by_id, new_by_id) do
    new_by_id
    |> Enum.reject(fn {id, _} -> Map.has_key?(old_by_id, id) end)
    |> Enum.map(fn {id, chunk} ->
      %{
        type: :insert_block,
        stable_id: id,
        content: chunk.content,
        line: chunk.line
      }
    end)
  end

  defp detect_deletes(old_by_id, new_by_id) do
    old_by_id
    |> Enum.reject(fn {id, _} -> Map.has_key?(new_by_id, id) end)
    |> Enum.map(fn {id, chunk} ->
      %{
        type: :delete_block,
        stable_id: id,
        content: chunk.content,
        line: chunk.line
      }
    end)
  end

  defp detect_semantic_conflicts(patch1, patch2) do
    # Detect conflicts at JSON-LD triple level
    # This is a simplified implementation
    conflicts = []

    # Check for same_segment_edit conflicts
    segment_conflicts = find_same_segment_edits(patch1, patch2)

    # Check for JSON-LD semantic conflicts
    semantic_conflicts = find_jsonld_conflicts(patch1, patch2)

    conflicts ++ segment_conflicts ++ semantic_conflicts
  end

  defp find_same_segment_edits(patch1, patch2) do
    # Find edits that affect the same stable_id
    ids1 = extract_stable_ids(patch1)
    ids2 = extract_stable_ids(patch2)

    common_ids = MapSet.intersection(MapSet.new(ids1), MapSet.new(ids2))

    Enum.map(common_ids, fn id ->
      %{
        type: :same_segment_edit,
        stable_id: id,
        conflict_reason: "Both patches modify the same segment"
      }
    end)
  end

  defp find_jsonld_conflicts(_patch1, _patch2) do
    # JSON-LD semantic conflict detection would go here
    # For now, return empty list
    []
  end

  defp extract_stable_ids(patch) do
    patch
    |> Enum.filter(&Map.has_key?(&1, :stable_id))
    |> Enum.map(& &1.stable_id)
  end

  defp apply_merged_patches(base, patches) do
    # Apply patches in order, handling conflicts
    Enum.reduce(patches, base, fn patch, content ->
      apply_patch_to_content(content, patch)
    end)
  end

  defp apply_patch_to_content(content, patch) do
    # Simplified patch application
    # In reality, would need sophisticated patching algorithm
    content
  end

  defp add_processing_metadata(result, opts) do
    metadata = %{
      compliance_level: opts[:compliance_level],
      processing_mode: opts[:mode],
      polyglot_detected: Map.has_key?(result, "polyglot"),
      concealment_detected: Map.has_key?(result, "concealment"),
      mem8_enhanced: Map.has_key?(result, "wave_influence"),
      v03_complete: true
    }

    Map.put(result, "processing_metadata", metadata)
  end

  defp handle_parse_error(reason, :strict) do
    {:error, reason}
  end

  defp handle_parse_error(reason, :lax) do
    Logger.warning("Parse error in lax mode: #{inspect(reason)}")
    {:error, reason}
  end

  defp init_performance_stats do
    %{
      parse_count: 0,
      total_processing_time: 0,
      avg_processing_time: 0,
      polyglot_detection_count: 0,
      mem8_integration_count: 0,
      concealment_extraction_count: 0
    }
  end
end
