defmodule MarkdownLd.AST do
  @moduledoc """
  Abstract Syntax Tree representation and operations for Markdown documents.

  Provides a comprehensive AST structure optimized for:
  - Tree traversal and manipulation (Avici use cases)
  - Indexing operations (B+ tree, trigram, graph, semantic)
  - Filesystem storage of whole codebases
  - Performance-critical operations

  ## Architecture

  The AST uses a hybrid approach:
  - **Performance path**: Direct extraction for simple operations
  - **Structure path**: Full AST for complex tree operations
  - **Index path**: Optimized node structures for indexing

  ## Node Types

  - `Document` - Root container with metadata
  - `Block` nodes - Paragraphs, headings, lists, code blocks
  - `Inline` nodes - Text, links, emphasis, code spans
  - `Container` nodes - Sections, list items, table cells

  ## Examples

      # Parse to AST
      {:ok, ast} = MarkdownLd.AST.parse("# Hello\\n\\nWorld")

      # Traverse nodes
      MarkdownLd.AST.walk(ast, &process_node/1)

      # Query structure
      headings = MarkdownLd.AST.select(ast, type: :heading)
      links = MarkdownLd.AST.select(ast, type: :link)

      # Transform tree
      new_ast = MarkdownLd.AST.transform(ast, fn
        %{type: :heading, level: 1} = node ->
          %{node | level: 2}
        node -> node
      end)
  """

  alias __MODULE__.{Node, Walker, Query, Transform, Index}

  @type node_type ::
          :document
          | :heading
          | :paragraph
          | :list
          | :list_item
          | :code_block
          | :blockquote
          | :table
          | :table_row
          | :table_cell
          | :text
          | :link
          | :emphasis
          | :strong
          | :code_span
          | :break
          | :image
          | :strikethrough
          | :task_item

  @type node_id :: binary()
  @type position :: {line :: non_neg_integer(), column :: non_neg_integer()}
  @type range :: {start :: position(), stop :: position()}

  @type node :: %Node{
          id: node_id(),
          type: node_type(),
          content: any(),
          attributes: map(),
          children: [node()],
          parent_id: node_id() | nil,
          position: range() | nil,
          metadata: map()
        }

  @type document :: %Node{
          type: :document,
          content: binary(),
          attributes: %{
            title: binary() | nil,
            frontmatter: map(),
            word_count: non_neg_integer(),
            file_path: binary() | nil
          },
          children: [node()],
          metadata: %{
            parse_time_us: non_neg_integer(),
            size_bytes: non_neg_integer(),
            checksum: binary(),
            created_at: DateTime.t(),
            indexes: map()
          }
        }

  # Core parsing API

  @doc """
  Parse markdown text into a complete AST.

  Options:
  - `:include_positions` - Track line/column positions (default: true)
  - `:file_path` - File path for filesystem indexing (default: nil)
  - `:parse_metadata` - Extract frontmatter and metadata (default: true)
  - `:generate_ids` - Generate unique node IDs (default: true)
  - `:build_indexes` - Pre-build search indexes (default: false)
  """
  @spec parse(binary(), keyword()) :: {:ok, document()} | {:error, term()}
  def parse(content, opts \\ []) when is_binary(content) do
    opts = Keyword.merge(default_options(), opts)
    start_time = System.monotonic_time(:microsecond)

    case parse_with_pulldown(content, opts) do
      {:ok, ast} ->
        parse_time = System.monotonic_time(:microsecond) - start_time
        ast = add_document_metadata(ast, content, parse_time, opts)

        ast =
          if Keyword.get(opts, :build_indexes, false) do
            Index.build_all(ast)
          else
            ast
          end

        {:ok, ast}

      error ->
        error
    end
  end

  @doc """
  Parse multiple markdown documents into ASTs efficiently.

  Uses parallel processing and shared parsing resources.
  """
  @spec parse_batch([{binary(), binary()}], keyword()) ::
          {:ok, [document()]} | {:error, term()}
  def parse_batch(content_path_pairs, opts \\ []) do
    opts = Keyword.merge(default_options(), opts)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

    content_path_pairs
    |> Task.async_stream(
      fn {content, path} ->
        parse(content, Keyword.put(opts, :file_path, path))
      end,
      max_concurrency: max_concurrency,
      timeout: :infinity
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, ast}}, {:ok, acc} -> {:cont, {:ok, [ast | acc]}}
      {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
      {:exit, reason}, _acc -> {:halt, {:error, {:task_exit, reason}}}
    end)
    |> case do
      {:ok, asts} -> {:ok, Enum.reverse(asts)}
      error -> error
    end
  end

  # Tree traversal and manipulation

  @doc """
  Walk the AST depth-first, calling the function on each node.

  Returns `:halt` to stop traversal early.
  """
  @spec walk(document(), (node() -> any() | :halt)) :: :ok
  def walk(ast, fun) when is_function(fun, 1) do
    Walker.depth_first(ast, fun)
  end

  @doc """
  Walk the AST breadth-first, calling the function on each node.
  """
  @spec walk_breadth(document(), (node() -> any() | :halt)) :: :ok
  def walk_breadth(ast, fun) when is_function(fun, 1) do
    Walker.breadth_first(ast, fun)
  end

  @doc """
  Select nodes matching the given criteria.

  Examples:
      select(ast, type: :heading)
      select(ast, type: :link, fn node -> String.contains?(node.content.url, "github") end)
  """
  @spec select(document(), keyword() | (node() -> boolean())) :: [node()]
  def select(ast, criteria) do
    Query.select(ast, criteria)
  end

  @doc """
  Find the first node matching criteria.
  """
  @spec find(document(), keyword() | (node() -> boolean())) :: node() | nil
  def find(ast, criteria) do
    Query.find_first(ast, criteria)
  end

  @doc """
  Transform the AST by applying a function to each node.

  The function should return the modified node or the original node.
  """
  @spec transform(document(), (node() -> node())) :: document()
  def transform(ast, fun) when is_function(fun, 1) do
    Transform.map_tree(ast, fun)
  end

  @doc """
  Get all children of a specific node by ID.
  """
  @spec get_children(document(), node_id()) :: [node()]
  def get_children(ast, node_id) do
    case find(ast, fn node -> node.id == node_id end) do
      nil -> []
      node -> node.children
    end
  end

  @doc """
  Get the parent of a node by ID.
  """
  @spec get_parent(document(), node_id()) :: node() | nil
  def get_parent(ast, node_id) do
    case find(ast, fn node -> node.id == node_id end) do
      nil -> nil
      %{parent_id: nil} -> nil
      %{parent_id: parent_id} -> find(ast, fn node -> node.id == parent_id end)
    end
  end

  # Indexing support for search operations

  @doc """
  Build search indexes for the AST.

  Indexes:
  - `:btree` - B+ tree for path-based queries
  - `:trigram` - Full-text search with fuzzy matching
  - `:graph` - Document relationship graph
  - `:semantic` - Vector embeddings for semantic search
  """
  @spec build_indexes(document(), [atom()]) :: document()
  def build_indexes(ast, index_types \\ [:btree, :trigram]) do
    Index.build_specific(ast, index_types)
  end

  @doc """
  Query the AST using index-optimized searches.

  Examples:
      # Path-based queries (B+ tree)
      query(ast, :path, "/docs/api/**")

      # Full-text search (Trigram)
      query(ast, :text, "performance optimization", fuzzy: 0.8)

      # Semantic search (Vector)
      query(ast, :semantic, "machine learning concepts", top_k: 10)
  """
  @spec query(document(), atom(), term(), keyword()) :: [node()]
  def query(ast, index_type, query_term, opts \\ []) do
    Index.query(ast, index_type, query_term, opts)
  end

  # Serialization and storage

  @doc """
  Convert AST to a compact binary format for storage.

  Uses efficient binary encoding optimized for large codebases.
  """
  @spec to_binary(document()) :: binary()
  def to_binary(ast) do
    :erlang.term_to_binary(ast, [:compressed, :deterministic])
  end

  @doc """
  Load AST from binary format.
  """
  @spec from_binary(binary()) :: {:ok, document()} | {:error, term()}
  def from_binary(binary) when is_binary(binary) do
    try do
      ast = :erlang.binary_to_term(binary, [:safe])
      {:ok, ast}
    rescue
      error -> {:error, {:decode_error, error}}
    end
  end

  @doc """
  Export AST to JSON for external tools.
  """
  @spec to_json(document()) :: {:ok, binary()} | {:error, term()}
  def to_json(ast) do
    Jason.encode(ast)
  end

  # Statistics and analysis

  @doc """
  Get comprehensive statistics about the AST.
  """
  @spec stats(document()) :: map()
  def stats(ast) do
    %{
      total_nodes: count_nodes(ast),
      node_types: count_by_type(ast),
      depth: max_depth(ast),
      word_count: ast.attributes.word_count,
      size_bytes: ast.metadata.size_bytes,
      parse_time_us: ast.metadata.parse_time_us,
      indexes: Map.keys(ast.metadata.indexes)
    }
  end

  @doc """
  Extract all text content from the AST.
  """
  @spec to_text(document()) :: binary()
  def to_text(ast) do
    ast
    |> select(type: :text)
    |> Enum.map(& &1.content)
    |> Enum.join("")
  end

  @doc """
  Get outline structure (headings hierarchy).
  """
  @spec outline(document()) :: [map()]
  def outline(ast) do
    ast
    |> select(type: :heading)
    |> Enum.map(fn node ->
      %{
        level: node.attributes.level,
        text: extract_text_content(node),
        id: node.id,
        position: node.position
      }
    end)
  end

  # Private implementation

  defp default_options do
    [
      include_positions: true,
      file_path: nil,
      parse_metadata: true,
      generate_ids: true,
      build_indexes: false,
      max_concurrency: System.schedulers_online()
    ]
  end

  defp parse_with_pulldown(content, opts) do
    # Convert pulldown_cmark events to our AST structure
    try do
      ast = build_ast_from_events(content, opts)
      {:ok, ast}
    rescue
      error -> {:error, {:parse_error, error}}
    end
  end

  defp build_ast_from_events(content, opts) do
    lines = String.split(content, "\n")
    events = get_pulldown_events(content)

    {ast, _state} =
      events
      |> Enum.with_index()
      |> Enum.reduce({nil, %{stack: [], line: 1, col: 1, ids: MapSet.new()}}, fn
        {event, _idx}, {current_ast, state} ->
          process_event(event, current_ast, state, opts, lines)
      end)

    ast || create_empty_document(content, opts)
  end

  defp get_pulldown_events(content) do
    # Hypothetical - we'd use pulldown_cmark via NIF
    import Pulldown, only: [parse: 1]
    parse(content)
  end

  defp process_event(event, ast, state, opts, lines) do
    # This would be a comprehensive event processor
    # For now, return a basic structure
    case event do
      {:start, :document} ->
        {create_document_node(opts), state}

      {:start, {:heading, level}} ->
        node = create_heading_node(level, state, opts)
        {add_child_to_current(ast, node, state), push_stack(state, node)}

      {:end, {:heading, _level}} ->
        {ast, pop_stack(state)}

      {:text, text} ->
        node = create_text_node(text, state, opts)
        {add_child_to_current(ast, node, state), state}

      _ ->
        {ast, state}
    end
  end

  defp create_document_node(opts) do
    %Node{
      id: generate_id(opts),
      type: :document,
      content: "",
      attributes: %{
        title: nil,
        frontmatter: %{},
        word_count: 0,
        file_path: Keyword.get(opts, :file_path)
      },
      children: [],
      parent_id: nil,
      position: nil,
      metadata: %{
        parse_time_us: 0,
        size_bytes: 0,
        checksum: "",
        created_at: DateTime.utc_now(),
        indexes: %{}
      }
    }
  end

  defp create_heading_node(level, state, opts) do
    %Node{
      id: generate_id(opts),
      type: :heading,
      content: "",
      attributes: %{level: level},
      children: [],
      parent_id: get_current_parent_id(state),
      position: get_current_position(state),
      metadata: %{}
    }
  end

  defp create_text_node(text, state, opts) do
    %Node{
      id: generate_id(opts),
      type: :text,
      content: text,
      attributes: %{},
      children: [],
      parent_id: get_current_parent_id(state),
      position: get_current_position(state),
      metadata: %{}
    }
  end

  defp add_child_to_current(ast, child, _state) do
    # Simplified - in real implementation would properly manage tree structure
    if ast do
      %{ast | children: ast.children ++ [child]}
    else
      child
    end
  end

  defp push_stack(state, node) do
    %{state | stack: [node | state.stack]}
  end

  defp pop_stack(state) do
    %{state | stack: tl(state.stack)}
  end

  defp get_current_parent_id(%{stack: [current | _]}), do: current.id
  defp get_current_parent_id(_), do: nil

  defp get_current_position(%{line: line, col: col}) do
    {{line, col}, {line, col}}
  end

  defp generate_id(opts) do
    if Keyword.get(opts, :generate_ids, true) do
      :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    else
      nil
    end
  end

  defp create_empty_document(content, opts) do
    %Node{
      id: generate_id(opts),
      type: :document,
      content: content,
      attributes: %{
        title: nil,
        frontmatter: %{},
        word_count: length(String.split(content)),
        file_path: Keyword.get(opts, :file_path)
      },
      children: [],
      parent_id: nil,
      position: nil,
      metadata: %{
        parse_time_us: 0,
        size_bytes: byte_size(content),
        checksum: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower),
        created_at: DateTime.utc_now(),
        indexes: %{}
      }
    }
  end

  defp add_document_metadata(ast, content, parse_time, opts) do
    %{
      ast
      | content: content,
        attributes:
          Map.merge(ast.attributes, %{
            word_count: length(String.split(content)),
            file_path: Keyword.get(opts, :file_path)
          }),
        metadata:
          Map.merge(ast.metadata, %{
            parse_time_us: parse_time,
            size_bytes: byte_size(content),
            checksum: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
          })
    }
  end

  defp count_nodes(ast) do
    # Count self
    count = 1
    count + Enum.sum(Enum.map(ast.children, &count_nodes/1))
  end

  defp count_by_type(ast) do
    counts = %{ast.type => 1}

    child_counts =
      Enum.reduce(ast.children, %{}, fn child, acc ->
        child_counts = count_by_type(child)
        Map.merge(acc, child_counts, fn _k, v1, v2 -> v1 + v2 end)
      end)

    Map.merge(counts, child_counts, fn _k, v1, v2 -> v1 + v2 end)
  end

  defp max_depth(ast, current_depth \\ 0) do
    if ast.children == [] do
      current_depth
    else
      ast.children
      |> Enum.map(&max_depth(&1, current_depth + 1))
      |> Enum.max()
    end
  end

  defp extract_text_content(node) do
    case node.type do
      :text ->
        node.content

      _ ->
        node.children
        |> Enum.map(&extract_text_content/1)
        |> Enum.join("")
    end
  end
end
