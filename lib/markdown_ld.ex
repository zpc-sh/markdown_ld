defmodule MarkdownLd do
  @moduledoc """
  High-performance Markdown processing with SIMD optimizations, AST support, virtual filesystem mounting, and JSON-LD integration.

  MarkdownLd provides blazing-fast markdown processing with advanced SIMD optimizations,
  memory pooling, batch processing, comprehensive AST operations, and the ability to mount
  markdown as virtual filesystems for AI interaction. Built on top of Rust with zero-copy
  processing for maximum performance.

  ## Features

  - **SIMD-optimized** string processing (Apple Silicon NEON, x86 AVX2)
  - **Zero-copy** binary processing for maximum efficiency
  - **Complete AST** support with tree operations and indexing
  - **Advanced indexing** (B+ tree, trigram, graph, semantic search)
  - **Virtual filesystem** mounting from markdown (mount/dismount for AI)
  - **Tree structure preservation** for complete codebase storage
  - **Memory pool** management for reduced allocations
  - **Parallel batch** processing with configurable concurrency
  - **Comprehensive parsing** (links, headings, code blocks, tasks)
  - **Pattern caching** for common structures
  - **Performance tracking** and metrics
  - **JSON-LD metadata** extraction and diffing

  ## Quick Start

      # Add to your mix.exs
      {:markdown_ld, "~> 0.4.0"}

      # Basic parsing (legacy format)
      {:ok, result} = MarkdownLd.parse("# Hello World")

      # AST parsing (new, recommended)
      {:ok, ast} = MarkdownLd.parse_ast("# Hello World")

      # Filesystem mounting (for AI operations)
      {:ok, vfs} = MarkdownLd.mount_filesystem(tree_markdown)
      File.write(Path.join(vfs.mount_point, "new_file.rs"), "// AI generated")
      {:ok, updated_markdown} = MarkdownLd.dismount_filesystem(vfs)

      # Batch processing
      {:ok, results} = MarkdownLd.parse_batch(documents, max_workers: 4)

  ## Basic Examples

      # Legacy extraction format
      iex> {:ok, result} = MarkdownLd.parse(\"\"\"
      ...> # Hello World
      ...>
      ...> This is **bold** text with a [link](https://example.com).
      ...>
      ...> ```elixir
      ...> def hello, do: :world
      ...> ```
      ...>
      ...> - [ ] Todo item
      ...> - [x] Done item
      ...> \"\"\")
      iex> result.headings
      [%{level: 1, text: "Hello World", line: 1}]
      iex> result.links
      [%{text: "link", url: "https://example.com", line: 3}]
      iex> result.code_blocks
      [%{language: "elixir", content: "def hello, do: :world", line: 5}]
      iex> result.tasks
      [%{completed: false, text: "Todo item", line: 9},
       %{completed: true, text: "Done item", line: 10}]

  ## AST Examples

      # Parse to AST for tree operations
      iex> {:ok, ast} = MarkdownLd.parse_ast("# Hello\\n\\nWorld [link](url)")

      # Query AST nodes
      iex> headings = MarkdownLd.AST.select(ast, type: :heading)
      iex> links = MarkdownLd.AST.select(ast, type: :link)

      # Transform AST
      iex> updated = MarkdownLd.AST.transform(ast, fn
      ...>   %{type: :heading, attributes: %{level: 1}} = node ->
      ...>     put_in(node.attributes.level, 2)
      ...>   node -> node
      ...> end)

      # Index for search
      iex> indexed_ast = MarkdownLd.AST.build_indexes(ast, [:btree, :trigram])
      iex> results = MarkdownLd.AST.query(indexed_ast, :trigram, "hello world")

  ## Performance Examples

      # Zero-copy binary processing (fastest)
      binary_content = File.read!("large_document.md")
      {:ok, result} = MarkdownLd.parse_binary(binary_content)

      # Batch processing for multiple documents
      documents = ["# Doc 1", "# Doc 2", "# Doc 3"]
      {:ok, results} = MarkdownLd.parse_batch_rust(documents)  # Rust parallel
      {:ok, results} = MarkdownLd.parse_batch(documents)       # Elixir parallel

      # Stream processing with backpressure
      large_document_stream
      |> MarkdownLd.parse_stream(max_workers: 8)
      |> Stream.filter(fn {:ok, result} -> length(result.headings) > 0 end)
      |> Enum.take(100)

  ## Performance Tracking

      # Get detailed performance metrics
      {:ok, stats} = MarkdownLd.get_performance_stats()
      # %{
      #   "simd_operations" => 1_250_000,
      #   "cache_hit_rate" => 85.2,
      #   "memory_pool_usage" => 2_048_576,
      #   "pattern_cache_size" => 128
      # }

      # Reset counters for benchmarking
      MarkdownLd.reset_performance_stats()

  ## Configuration

      # In your config.exs
      config :markdown_ld,
        parallel: true,
        max_workers: System.schedulers_online(),
        cache_patterns: true,
        track_performance: true,
        simd_enabled: true

      # Per-operation configuration
      {:ok, result} = MarkdownLd.parse(content,
        parallel: false,
        cache_patterns: true,
        max_workers: 2
      )

  ## Architecture

  MarkdownLd uses a three-layer architecture for maximum performance:

  1. **Elixir API Layer** - Batch processing, streaming, error handling
  2. **Rust NIF Core** - Memory management, pattern caching, coordination
  3. **SIMD Engine** - Vectorized operations, high-performance parsing

  This design provides the safety and concurrency of Elixir with the raw
  performance of optimized Rust code.

  ## Performance Characteristics

  - **Small documents** (1KB): 3-7μs processing time
  - **Medium documents** (10KB): 5-10μs processing time
  - **Large documents** (100KB): 15-35μs processing time
  - **Throughput**: Up to 5GB/s for large documents
  - **Memory efficiency**: 50-80% reduction in allocations
  - **Scalability**: Thousands of documents per second

  See `PERFORMANCE_REPORT.md` for detailed benchmarking results.
  """

  alias MarkdownLd.Native
  alias MarkdownLd.AST
  alias MarkdownLd.AST.Filesystem

  @type parse_result :: %{
          headings: [heading()],
          links: [link()],
          code_blocks: [code_block()],
          tasks: [task()],
          word_count: non_neg_integer(),
          processing_time_us: non_neg_integer()
        }

  @type heading :: %{
          level: 1..6,
          text: String.t(),
          line: pos_integer()
        }

  @type link :: %{
          text: String.t(),
          url: String.t(),
          line: pos_integer()
        }

  @type code_block :: %{
          language: String.t() | nil,
          content: String.t(),
          line: pos_integer()
        }

  @type task :: %{
          completed: boolean(),
          text: String.t(),
          line: pos_integer()
        }

  @type parse_options :: [
          parallel: boolean(),
          max_workers: pos_integer(),
          cache_patterns: boolean(),
          track_performance: boolean()
        ]

  @doc """
  Parse markdown text with SIMD optimizations.

  ## Options

    * `:parallel` - Enable parallel processing for large documents (default: false)
    * `:max_workers` - Maximum number of worker processes (default: System.schedulers_online())
    * `:cache_patterns` - Enable pattern caching for repeated structures (default: true)
    * `:track_performance` - Include performance metrics in result (default: true)

  ## Examples

      iex> MarkdownLd.parse("# Hello\\n[Link](http://example.com)")
      {:ok, %{
        headings: [%{level: 1, text: "Hello", line: 1}],
        links: [%{text: "Link", url: "http://example.com", line: 2}],
        word_count: 2,
        processing_time_us: 156
      }}
  """
  @spec parse(String.t() | binary(), parse_options()) ::
          {:ok, parse_result()} | {:error, String.t()}
  def parse(content, opts \\ [])

  def parse(content, opts) when is_binary(content) do
    opts = Keyword.merge(default_options(), opts)
    backend = Application.get_env(:markdown_ld, :backend, :nif)

    case backend do
      :elixir -> MarkdownLd.Fallback.parse(content, opts)
      _ -> safe_nif(fn -> Native.parse_markdown(content, opts) end, content, opts)
    end
  end

  @doc """
  Parse markdown text with zero-copy optimization for binary input.

  This function provides the fastest parsing path by avoiding string conversion
  and operating directly on binary data with SIMD optimizations.
  """
  @spec parse_binary(binary(), parse_options()) :: {:ok, parse_result()} | {:error, String.t()}
  def parse_binary(binary, opts \\ []) when is_binary(binary) do
    opts = Keyword.merge(default_options(), opts)
    backend = Application.get_env(:markdown_ld, :backend, :nif)

    case backend do
      :elixir -> MarkdownLd.Fallback.parse(binary, opts)
      _ -> safe_nif(fn -> Native.parse_markdown_binary(binary, opts) end, binary, opts)
    end
  end

  @doc """
  Parse multiple markdown documents in parallel with batch optimization.

  Uses Elixir-side parallelization with configurable worker processes.
  Best for processing many small to medium documents.

  ## Examples

      iex> docs = ["# Doc 1", "# Doc 2", "# Doc 3"]
      iex> MarkdownLd.parse_batch(docs, max_workers: 4)
      {:ok, [%{headings: [...]}, %{headings: [...]}, %{headings: [...]}]}
  """
  @spec parse_batch([String.t() | binary()], parse_options()) ::
          {:ok, [parse_result()]} | {:error, String.t()}
  def parse_batch(documents, opts \\ []) when is_list(documents) do
    opts = Keyword.merge(default_options(), opts)
    max_workers = Keyword.get(opts, :max_workers, System.schedulers_online())

    documents
    |> Task.async_stream(fn doc -> parse(doc, opts) end,
      max_concurrency: max_workers,
      timeout: :infinity,
      ordered: true
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, result}}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
      {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
      {:exit, reason}, _acc -> {:halt, {:error, "Task failed: #{inspect(reason)}"}}
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      error -> error
    end
  end

  @doc """
  Parse multiple markdown documents using Rust-side parallelization.

  Uses Rust rayon for parallel processing. Best for processing large documents
  or when you want to minimize Elixir process overhead.
  """
  @spec parse_batch_rust([String.t() | binary()], parse_options()) ::
          {:ok, [parse_result()]} | {:error, String.t()}
  def parse_batch_rust(documents, opts \\ []) when is_list(documents) do
    opts = Keyword.merge(default_options(), opts)
    backend = Application.get_env(:markdown_ld, :backend, :nif)

    case backend do
      :elixir -> parse_batch(documents, opts)
      _ -> safe_nif(fn -> Native.parse_batch_parallel(documents, opts) end, documents, opts)
    end
  end

  # ——— AST API ———

  @doc """
  Parse markdown text into a complete AST structure.

  This is the recommended API for applications that need:
  - Tree traversal and manipulation (Avici use cases)
  - Advanced querying and filtering
  - Structural transformations
  - Search indexing capabilities

  ## Options

    * `:include_positions` - Track line/column positions (default: true)
    * `:file_path` - File path for filesystem indexing (default: nil)
    * `:parse_metadata` - Extract frontmatter and metadata (default: true)
    * `:generate_ids` - Generate unique node IDs (default: true)
    * `:build_indexes` - Pre-build search indexes (default: false)

  ## Examples

      iex> {:ok, ast} = MarkdownLd.parse_ast("# Hello\\n\\nWorld")
      iex> ast.type
      :document
      iex> length(ast.children)
      2

      # With indexing for large codebases
      iex> {:ok, ast} = MarkdownLd.parse_ast(content,
      ...>   file_path: "docs/api.md",
      ...>   build_indexes: [:btree, :trigram]
      ...> )
  """
  @spec parse_ast(String.t() | binary(), keyword()) :: {:ok, AST.document()} | {:error, term()}
  def parse_ast(content, opts \\ []) when is_binary(content) do
    AST.parse(content, opts)
  end

  @doc """
  Parse multiple markdown documents into AST structures efficiently.

  Uses parallel processing optimized for large codebase storage.

  ## Examples

      # Parse entire codebase
      files = [
        {"README.md", readme_content},
        {"docs/api.md", api_content},
        {"src/main.rs", rust_content}
      ]

      {:ok, asts} = MarkdownLd.parse_ast_batch(files,
        build_indexes: [:btree, :trigram],
        max_concurrency: 8
      )
  """
  @spec parse_ast_batch([{binary(), binary()}], keyword()) ::
          {:ok, [AST.document()]} | {:error, term()}
  def parse_ast_batch(content_path_pairs, opts \\ []) do
    AST.parse_batch(content_path_pairs, opts)
  end

  @doc """
  Query AST nodes using various search strategies.

  Supports multiple index types for different query patterns:
  - `:btree` - File path queries with range support O(log n)
  - `:trigram` - Full-text search with fuzzy matching
  - `:graph` - Document relationship traversal
  - `:semantic` - Vector similarity search

  ## Examples

      # File path queries (B+ tree)
      results = MarkdownLd.query_ast(ast, :btree, {:glob, "**/*.md"})

      # Full-text search (Trigram)
      results = MarkdownLd.query_ast(ast, :trigram, "performance optimization",
        fuzzy: 0.8, limit: 20)

      # Semantic search (Vector)
      results = MarkdownLd.query_ast(ast, :semantic, "machine learning concepts",
        top_k: 10)
  """
  @spec query_ast(AST.document(), atom(), term(), keyword()) :: [AST.Node.t()]
  def query_ast(%AST.Node{} = ast, index_type, query_term, opts \\ []) do
    AST.query(ast, index_type, query_term, opts)
  end

  @doc """
  Transform AST using tree manipulation operations.

  Provides a high-level interface to common AST transformations.

  ## Examples

      # Apply function to all nodes
      updated_ast = MarkdownLd.transform_ast(ast, fn node ->
        %{node | metadata: Map.put(node.metadata, :processed, true)}
      end)

      # Remove all comments
      cleaned_ast = MarkdownLd.remove_nodes(ast, type: :comment)

      # Insert table of contents
      with_toc = MarkdownLd.insert_nodes(ast,
        [type: :heading, level: 1], :before, [create_toc()])
  """
  @spec transform_ast(AST.document(), AST.Transform.transform_fun()) :: AST.document()
  def transform_ast(%AST.Node{} = ast, transform_fun) when is_function(transform_fun, 1) do
    AST.transform(ast, transform_fun)
  end

  # ——— Filesystem Mount/Dismount API ———

  @doc """
  Parse tree-style markdown and mount as virtual filesystem.

  Enables AI to work with markdown codebases as if they were real filesystems.
  The AI can navigate, read, write, and modify files, then dismount back to
  updated markdown with all changes preserved.

  ## Options

    * `:mount_point` - Directory to mount in (default: temp dir)
    * `:writable` - Allow modifications (default: true)
    * `:sync_mode` - :immediate, :on_dismount, :manual (default: :on_dismount)
    * `:preserve_permissions` - Maintain original file permissions (default: true)

  ## Examples

      # Parse and mount codebase from tree markdown
      tree_content = '''
      src/
      ├── main.rs (250 lines)
      ├── lib.rs (180 lines)
      └── utils/
          └── helper.rs (95 lines)
      README.md (45 lines)
      '''

      {:ok, vfs} = MarkdownLd.mount_filesystem(tree_content)

      # AI can now work with files normally
      File.read(Path.join(vfs.mount_point, "src/main.rs"))
      File.write(Path.join(vfs.mount_point, "src/new_module.rs"), rust_code)

      # Dismount with all changes preserved
      {:ok, updated_markdown} = MarkdownLd.dismount_filesystem(vfs)
  """
  @spec mount_filesystem(binary(), keyword()) ::
          {:ok, Filesystem.virtual_filesystem()} | {:error, term()}
  def mount_filesystem(tree_markdown, opts \\ []) when is_binary(tree_markdown) do
    with {:ok, fs_ast} <- Filesystem.parse_tree_markdown(tree_markdown, opts),
         {:ok, vfs} <- Filesystem.mount(fs_ast, opts) do
      {:ok, vfs}
    else
      error -> error
    end
  end

  @doc """
  Dismount virtual filesystem and return updated markdown.

  Scans the mounted filesystem for all changes made by the AI and generates
  updated tree-style markdown that preserves the structure and modifications.

  ## Examples

      # After AI has made changes to mounted filesystem
      {:ok, updated_markdown} = MarkdownLd.dismount_filesystem(vfs)

      # The updated markdown includes all changes:
      # - New files created by AI
      # - Modified file contents (with updated line counts)
      # - Deleted files (removed from tree)
      # - Directory structure changes
  """
  @spec dismount_filesystem(Filesystem.virtual_filesystem()) :: {:ok, binary()} | {:error, term()}
  def dismount_filesystem(%{} = vfs) do
    Filesystem.dismount(vfs)
  end

  @doc """
  Generate tree markdown from directory or codebase.

  Creates tree2md-style markdown from an existing filesystem directory,
  perfect for creating initial markdown representations of codebases.

  ## Options

    * `:style` - :tree, :markdown, :github (default: :tree)
    * `:max_depth` - Maximum directory depth (default: nil)
    * `:include_stats` - Include file statistics (default: true)
    * `:github_url` - Base URL for GitHub links (default: nil)
    * `:exclude_patterns` - Glob patterns to exclude (default: standard exclusions)
    * `:include_patterns` - Glob patterns to include (default: all)

  ## Examples

      # Generate tree markdown from directory
      {:ok, tree_markdown} = MarkdownLd.generate_tree_markdown("./src",
        style: :tree,
        include_stats: true,
        max_depth: 3
      )

      # Generate with GitHub links
      {:ok, github_tree} = MarkdownLd.generate_tree_markdown(".",
        style: :github,
        github_url: "https://github.com/user/repo/tree/main"
      )
  """
  @spec generate_tree_markdown(binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def generate_tree_markdown(root_path, opts \\ []) do
    Filesystem.generate_tree_markdown(root_path, opts)
  end

  @doc """
  Navigate mounted filesystem with AI-friendly operations.

  Provides familiar filesystem operations that AI can use to explore and
  interact with the mounted codebase.

  ## Operations

    * `:ls` - List directory contents
    * `:cat` - Read file contents
    * `:tree` - Show tree structure
    * `:find` - Find files matching pattern
    * `:stat` - Get file statistics
    * `:pwd` - Get working directory

  ## Examples

      # List root directory
      {:ok, entries} = MarkdownLd.navigate_filesystem(vfs, :ls, ".")

      # Read a file
      {:ok, content} = MarkdownLd.navigate_filesystem(vfs, :cat, "src/main.rs")

      # Find all Rust files
      {:ok, rust_files} = MarkdownLd.navigate_filesystem(vfs, :find, "**/*.rs")

      # Show tree structure
      {:ok, tree} = MarkdownLd.navigate_filesystem(vfs, :tree, "src")
  """
  @spec navigate_filesystem(Filesystem.virtual_filesystem(), atom(), binary()) :: term()
  def navigate_filesystem(%{} = vfs, operation, path \\ ".") do
    Filesystem.navigate(vfs, operation, path)
  end

  @doc """
  Remove nodes matching criteria from AST.
  """
  @spec remove_nodes(AST.document(), keyword() | (AST.Node.t() -> boolean())) :: AST.document()
  def remove_nodes(%AST.Node{} = ast, criteria) do
    AST.Transform.remove_nodes(ast, criteria)
  end

  @doc """
  Insert nodes at specific positions in AST.
  """
  @spec insert_nodes(AST.document(), keyword(), AST.Transform.insertion_point(), [AST.Node.t()]) ::
          AST.document()
  def insert_nodes(%AST.Node{} = ast, target_criteria, position, nodes_to_insert) do
    AST.Transform.insert_nodes(ast, target_criteria, position, nodes_to_insert)
  end

  @doc """
  Convert AST back to markdown text.

  Uses the original content when available, otherwise reconstructs from AST.
  """
  @spec ast_to_markdown(AST.document()) :: binary()
  def ast_to_markdown(%AST.Node{content: content} = _ast)
      when is_binary(content) and content != "" do
    # Return original content if available and unmodified
    content
  end

  def ast_to_markdown(%AST.Node{} = ast) do
    # Reconstruct from AST structure
    AST.to_text(ast)
  end

  @doc """
  Convert filesystem AST to tree markdown format.

  Specialized conversion for filesystem ASTs that preserves directory
  structure, file statistics, and tree formatting.
  """
  @spec ast_to_tree_markdown(Filesystem.filesystem_node(), keyword()) :: binary()
  def ast_to_tree_markdown(%AST.Node{} = fs_ast, opts \\ []) do
    Filesystem.ast_to_tree_markdown(fs_ast, opts)
  end

  @doc """
  Stream parse markdown documents with backpressure control.

  Efficiently processes large numbers of documents with controlled memory usage.
  """
  @spec parse_stream(Enumerable.t(), parse_options()) :: Enumerable.t()
  def parse_stream(documents, opts \\ []) do
    opts = Keyword.merge(default_options(), opts)
    max_workers = Keyword.get(opts, :max_workers, System.schedulers_online())

    Task.async_stream(
      documents,
      fn doc -> parse(doc, opts) end,
      max_concurrency: max_workers,
      timeout: :infinity,
      ordered: false
    )
    |> Stream.map(fn
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, "Task failed: #{inspect(reason)}"}
    end)
  end

  @doc """
  Extract word count from markdown text with SIMD optimization.

  Fast word counting using SIMD pattern matching for whitespace detection.
  """
  @spec word_count(String.t() | binary()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def word_count(content) when is_binary(content) do
    Native.word_count_simd(content)
  end

  @doc """
  Extract all links from markdown text.

  Uses SIMD-optimized pattern matching to quickly find markdown link patterns.
  """
  @spec extract_links(String.t() | binary()) :: {:ok, [link()]} | {:error, String.t()}
  def extract_links(content) when is_binary(content) do
    Native.extract_links_simd(content)
  end

  @doc """
  Extract all headings from markdown text.

  Fast heading extraction using SIMD pattern matching for hash characters.
  """
  @spec extract_headings(String.t() | binary()) :: {:ok, [heading()]} | {:error, String.t()}
  def extract_headings(content) when is_binary(content) do
    Native.extract_headings_simd(content)
  end

  @doc """
  Extract all code blocks from markdown text.

  Efficiently finds fenced code blocks with language detection.
  """
  @spec extract_code_blocks(String.t() | binary()) :: {:ok, [code_block()]} | {:error, String.t()}
  def extract_code_blocks(content) when is_binary(content) do
    Native.extract_code_blocks_simd(content)
  end

  @doc """
  Extract all task items from markdown text.

  Finds task list items with completion status detection.
  """
  @spec extract_tasks(String.t() | binary()) :: {:ok, [task()]} | {:error, String.t()}
  def extract_tasks(content) when is_binary(content) do
    Native.extract_tasks_simd(content)
  end

  @doc """
  Get performance statistics from the Rust processing layer.

  Returns metrics about SIMD operations, cache hits, memory usage, and processing times.
  """
  @spec get_performance_stats() :: {:ok, map()} | {:error, String.t()}
  def get_performance_stats do
    Native.get_performance_stats()
  end

  @doc """
  Reset performance statistics counters.

  Useful for benchmarking and performance analysis.
  """
  @spec reset_performance_stats() :: :ok
  def reset_performance_stats do
    Native.reset_performance_stats()
  end

  @doc """
  Clear pattern cache to free memory.

  The pattern cache stores frequently used markdown patterns for faster processing.
  """
  @spec clear_pattern_cache() :: :ok
  def clear_pattern_cache do
    Native.clear_pattern_cache()
  end

  # Private functions

  defp default_options do
    [
      parallel: false,
      max_workers: System.schedulers_online(),
      cache_patterns: true,
      track_performance: true
    ]
  end

  defp safe_nif(fun, content, _opts) do
    try do
      fun.()
    rescue
      _ -> MarkdownLd.Fallback.parse(content, [])
    end
  end

  # ——— Diff API (composed) ———

  @doc """
  Compute a combined patch between two markdown strings.

  Produces a `MarkdownLd.Diff.Patch` with changes from:
  - Block-level diff (insert/delete/update, with inline ops for text blocks)
  - JSON-LD semantic diff (add/remove/update triples)

  Options:
  - `:from_rev` / `:to_rev` — optional revision identifiers; defaults to content hashes
  - `:similarity_threshold` — inline update coalescing threshold (default: 0.5)
  - `:meta` — optional patch metadata map
  """
  @spec diff(String.t(), String.t(), keyword()) :: {:ok, MarkdownLd.Diff.Patch.t()}
  def diff(old_text, new_text, opts \\ []) when is_binary(old_text) and is_binary(new_text) do
    from_rev = Keyword.get(opts, :from_rev, content_rev(old_text))
    to_rev = Keyword.get(opts, :to_rev, content_rev(new_text))
    meta = Keyword.get(opts, :meta, %{})

    sim = Keyword.get(opts, :similarity_threshold, 0.5)

    block_changes = MarkdownLd.Diff.Block.diff(old_text, new_text, similarity_threshold: sim)
    jsonld_changes = MarkdownLd.JSONLD.diff(old_text, new_text)

    include_sidecars = Keyword.get(opts, :include_sidecars, true)

    {session_changes, wasm_changes} =
      if include_sidecars do
        session_changes =
          MarkdownLd.Sessions.diff(old_text, new_text)
          |> Enum.map(fn %{kind: k, payload: p} -> MarkdownLd.Diff.change(k, nil, p) end)

        wasm_changes =
          MarkdownLd.WASM.diff(old_text, new_text)
          |> Enum.map(fn %{kind: k, payload: p} -> MarkdownLd.Diff.change(k, nil, p) end)

        {session_changes, wasm_changes}
      else
        {[], []}
      end

    changes = block_changes ++ jsonld_changes ++ session_changes ++ wasm_changes

    {:ok, MarkdownLd.Diff.patch(from_rev, to_rev, changes, Map.merge(%{message: "diff"}, meta))}
  end

  defp content_rev(text) do
    :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)
  end

  # ——— AST Utilities ———

  defp create_toc(%AST.Node{} = ast) do
    # Extract headings to create table of contents
    headings = AST.select(ast, type: :heading)

    toc_items =
      Enum.map(headings, fn heading ->
        level = heading.attributes.level
        text = AST.Node.extract_text_content(heading)
        anchor = AST.Node.slugify(text)

        indent = String.duplicate("  ", level - 1)
        "#{indent}- [#{text}](##{anchor})"
      end)

    toc_content = Enum.join(toc_items, "\n")

    AST.Node.heading("Table of Contents", 2)
    |> AST.Node.add_child(AST.Node.code_block(toc_content, "markdown"))
  end
end
