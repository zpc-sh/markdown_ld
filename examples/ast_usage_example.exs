#!/usr/bin/env elixir

# AST Usage Examples for Large Codebase Processing
# Demonstrates the power of MarkdownLd's AST system for complex document operations

Mix.install([
  {:markdown_ld, path: "."},
  {:jason, "~> 1.4"}
])

defmodule ASTExamples do
  @moduledoc """
  Comprehensive examples showing MarkdownLd AST capabilities for:
  - Large codebase indexing and search
  - Document tree manipulation
  - Multi-index querying
  - Performance-optimized operations
  """

  alias MarkdownLd.AST
  alias MarkdownLd.AST.{Node, Query, Transform, Index, Walker}

  def run_all_examples do
    IO.puts("🚀 MarkdownLd AST Examples - Large Codebase Processing")
    IO.puts("=" |> String.duplicate(60))

    # Example codebase documents
    codebase = create_example_codebase()

    IO.puts("\n📁 Processing #{length(codebase)} documents...")

    # Parse entire codebase to AST
    {:ok, asts} = MarkdownLd.parse_ast_batch(codebase,
      build_indexes: [:btree, :trigram, :graph],
      max_concurrency: 8
    )

    # Combine into single document tree for unified operations
    combined_ast = combine_documents(asts)

    # Run examples
    basic_ast_operations(combined_ast)
    indexing_and_search_examples(combined_ast)
    tree_transformation_examples(combined_ast)
    performance_examples(combined_ast)
    avici_tree_operations(combined_ast)

    IO.puts("\n✅ All examples completed!")
  end

  # ——— Basic AST Operations ———

  def basic_ast_operations(ast) do
    IO.puts("\n🌳 Basic AST Operations")
    IO.puts("-" |> String.duplicate(30))

    # Tree statistics
    stats = AST.stats(ast)
    IO.puts("📊 Document Statistics:")
    IO.puts("  Total nodes: #{stats.total_nodes}")
    IO.puts("  Max depth: #{stats.depth}")
    IO.puts("  Word count: #{stats.word_count}")
    IO.puts("  Node types: #{inspect(stats.node_types)}")

    # Find all headings
    headings = AST.select(ast, type: :heading)
    IO.puts("📝 Found #{length(headings)} headings:")

    headings
    |> Enum.take(5)
    |> Enum.each(fn heading ->
      level_marker = String.duplicate("#", heading.attributes.level)
      text = extract_text_from_node(heading)
      IO.puts("  #{level_marker} #{text}")
    end)

    # Find all code blocks with specific languages
    elixir_code = AST.select(ast, type: :code_block, fn node ->
      node.attributes.language == "elixir"
    end)

    IO.puts("💻 Found #{length(elixir_code)} Elixir code blocks")

    # XPath-style queries
    api_headings = Query.xpath(ast, "//heading[@level=2]")
    IO.puts("🔍 Found #{length(api_headings)} level-2 headings via XPath")

    # CSS-style selectors
    code_in_lists = Query.css(ast, "list code_block")
    IO.puts("🎯 Found #{length(code_in_lists)} code blocks inside lists")
  end

  # ——— Indexing and Search Examples ———

  def indexing_and_search_examples(ast) do
    IO.puts("\n🔍 Indexing and Search Operations")
    IO.puts("-" |> String.duplicate(35))

    # B+ Tree path queries
    IO.puts("📁 B+ Tree Path Queries:")

    # Search by file pattern
    api_docs = MarkdownLd.query_ast(ast, :btree, {:glob, "**/api/**"})
    IO.puts("  API docs: #{length(api_docs)} files")

    readme_files = MarkdownLd.query_ast(ast, :btree, {:glob, "**/README.md"})
    IO.puts("  README files: #{length(readme_files)} files")

    # Trigram full-text search
    IO.puts("🔤 Full-Text Search (Trigram):")

    performance_mentions = MarkdownLd.query_ast(ast, :trigram, "performance optimization",
      fuzzy: 0.7, limit: 10)
    IO.puts("  'performance optimization': #{length(performance_mentions)} matches")

    api_references = MarkdownLd.query_ast(ast, :trigram, "API endpoint",
      fuzzy: 0.8, limit: 15)
    IO.puts("  'API endpoint': #{length(api_references)} matches")

    # Graph relationship queries
    IO.puts("🕸️ Graph Relationship Queries:")

    # Find documents that link to others
    linked_docs = MarkdownLd.query_ast(ast, :graph, {:outbound, ast.id})
    IO.puts("  Outbound links: #{length(linked_docs)} connections")

    # Semantic search (would use real embeddings in production)
    IO.puts("🧠 Semantic Search:")
    similar_docs = MarkdownLd.query_ast(ast, :semantic, "database management",
      top_k: 5)
    IO.puts("  Similar to 'database management': #{length(similar_docs)} documents")
  end

  # ——— Tree Transformation Examples ———

  def tree_transformation_examples(ast) do
    IO.puts("\n🔧 Tree Transformation Operations")
    IO.puts("-" |> String.duplicate(35))

    # Add metadata to all nodes
    IO.puts("📋 Adding processing metadata...")
    timestamped_ast = Transform.map_tree(ast, fn node ->
      %{node | metadata: Map.put(node.metadata, :processed_at, DateTime.utc_now())}
    end)

    # Normalize heading levels (prevent level skipping)
    IO.puts("📐 Normalizing heading levels...")
    normalized_ast = Transform.transform_where(timestamped_ast,
      fn node -> node.type == :heading end,
      fn node ->
        # Ensure no heading level jumps
        normalized_level = min(node.attributes.level, 6)
        put_in(node.attributes.level, normalized_level)
      end
    )

    # Remove empty paragraphs
    IO.puts("🧹 Cleaning empty paragraphs...")
    cleaned_ast = Transform.remove_nodes(normalized_ast, fn node ->
      node.type == :paragraph and node.children == []
    end)

    # Insert table of contents before first heading
    IO.puts("📑 Adding table of contents...")
    toc_node = create_table_of_contents(cleaned_ast)
    final_ast = Transform.insert_nodes(cleaned_ast,
      [type: :heading, level: 1], :before, [toc_node])

    # Validate tree integrity
    case Transform.validate_integrity(final_ast) do
      {:ok, _} -> IO.puts("✅ Tree integrity validated")
      {:error, issues} -> IO.puts("❌ Integrity issues: #{inspect(issues)}")
    end

    final_ast
  end

  # ——— Performance Examples ———

  def performance_examples(ast) do
    IO.puts("\n⚡ Performance Operations")
    IO.puts("-" |> String.duplicate(25))

    # Monitored tree walk
    {_result, stats} = Walker.monitored_walk(ast, fn node ->
      # Simulate some processing
      :timer.sleep(0)  # Minimal delay for measurement
      node.type
    end)

    IO.puts("📈 Traversal Performance:")
    IO.puts("  Nodes visited: #{stats.nodes_visited}")
    IO.puts("  Time: #{Float.round(stats.time_ms, 2)}ms")
    IO.puts("  Rate: #{Float.round(stats.traversal_rate_nodes_per_ms, 0)} nodes/ms")
    IO.puts("  Memory delta: #{stats.memory_delta_bytes} bytes")

    # Batch transformations for efficiency
    IO.puts("🔄 Batch Transformations:")

    transforms = [
      {:map, fn node -> %{node | metadata: Map.put(node.metadata, :batch_processed, true)} end},
      {:where, [type: :code_block], fn node -> add_syntax_highlighting_metadata(node) end},
      {:remove, [type: :comment]}
    ]

    start_time = System.monotonic_time(:microsecond)
    _batch_result = Transform.batch_transform(ast, transforms)
    end_time = System.monotonic_time(:microsecond)

    IO.puts("  Batch processing time: #{(end_time - start_time) / 1000}ms")

    # Large-scale node counting
    total_nodes = Walker.count_nodes(ast)
    leaf_nodes = Walker.leaf_nodes(ast) |> length()

    IO.puts("📊 Scale Metrics:")
    IO.puts("  Total nodes: #{total_nodes}")
    IO.puts("  Leaf nodes: #{leaf_nodes}")
    IO.puts("  Internal nodes: #{total_nodes - leaf_nodes}")
  end

  # ——— Avici-Style Tree Operations ———

  def avici_tree_operations(ast) do
    IO.puts("\n🎯 Avici-Style Tree Operations")
    IO.puts("-" |> String.duplicate(30))

    # Complex structural queries
    IO.puts("🏗️ Complex Structural Analysis:")

    # Find nested list structures
    nested_lists = Query.select_has_child(ast,
      type: :list,
      child_predicate: fn child -> child.type == :list end
    )
    IO.puts("  Nested lists: #{length(nested_lists)}")

    # Find code blocks inside blockquotes
    quoted_code = Query.select_has_child(ast,
      type: :blockquote,
      child_type: :code_block
    )
    IO.puts("  Code in quotes: #{length(quoted_code)}")

    # Sibling analysis
    heading_siblings = Query.select_siblings(ast, [type: :heading], :following)
    IO.puts("  Following siblings of headings: #{length(heading_siblings)}")

    # Tree assembly operations
    IO.puts("🔧 Tree Assembly Operations:")

    # Group consecutive list items
    grouped_ast = Transform.group_consecutive(ast,
      fn node -> node.type == :list_item end,
      fn items -> Node.list(:unordered, children: items) end
    )

    # Sort children by type (headings first, then content)
    sorted_ast = Transform.sort_children(grouped_ast,
      fn node -> node.type == :document end,
      fn child ->
        case child.type do
          :heading -> {0, child.attributes.level}
          :paragraph -> {1, 0}
          :list -> {2, 0}
          :code_block -> {3, 0}
          _ -> {99, 0}
        end
      end
    )

    # Path-based operations for navigation
    IO.puts("🗺️ Path Operations:")

    all_paths = Walker.all_paths(sorted_ast)
    IO.puts("  Total paths to leaves: #{length(all_paths)}")

    # Find deepest paths
    deepest_paths = all_paths
    |> Enum.max_by(&length/1, fn -> [] end)
    |> length()

    IO.puts("  Deepest path: #{deepest_paths} levels")

    # Parent-child relationship mapping
    parent_map = Walker.parent_child_map(sorted_ast)
    IO.puts("  Parent-child relationships: #{map_size(parent_map)}")

    sorted_ast
  end

  # ——— Helper Functions ———

  defp create_example_codebase do
    [
      {"README.md", """
      # Project Documentation

      This is a comprehensive project with multiple components.

      ## Features

      - High-performance parsing
      - Advanced indexing capabilities
      - Tree manipulation operations
      - API endpoint management

      ## Performance Optimization

      Our system provides significant performance improvements through:

      - SIMD vectorization
      - Memory pooling
      - Parallel processing
      """},

      {"docs/api/endpoints.md", """
      # API Endpoints

      ## User Management

      ### GET /api/users

      Retrieve user list with pagination support.

      ```elixir
      def list_users(params) do
        users = Repo.all(User)
        {:ok, users}
      end
      ```

      ### POST /api/users

      Create a new user account.

      ```elixir
      def create_user(attrs) do
        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()
      end
      ```
      """},

      {"docs/database/schema.md", """
      # Database Schema

      ## User Table

      The users table stores account information:

      ```sql
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255),
        created_at TIMESTAMP DEFAULT NOW()
      );
      ```

      ## Performance Considerations

      - Index on email for fast lookups
      - Pagination for large datasets
      - Connection pooling for scalability
      """},

      {"examples/usage.md", """
      # Usage Examples

      ## Basic Operations

      Simple parsing and extraction:

      ```elixir
      {:ok, result} = MarkdownLd.parse(content)
      headings = result.headings
      ```

      ## Advanced Features

      For complex tree operations:

      ```elixir
      {:ok, ast} = MarkdownLd.parse_ast(content)
      headings = MarkdownLd.AST.select(ast, type: :heading)
      ```

      > **Note**: The AST API provides more flexibility for
      > complex document manipulation tasks.
      """},

      {"CHANGELOG.md", """
      # Changelog

      ## [0.4.0] - 2024-01-15

      ### Added
      - Complete AST support
      - Advanced indexing (B+ tree, trigram, graph, semantic)
      - Tree transformation operations
      - Performance monitoring

      ### Performance Optimization
      - 40-80% size reduction with compression
      - SIMD vectorization for parsing
      - Parallel batch processing

      ## [0.3.0] - 2023-12-01

      ### Added
      - JSON-LD integration
      - Diff and merge operations
      - Basic extraction functions
      """}
    ]
  end

  defp combine_documents(asts) do
    # Create a root document containing all parsed documents as children
    root_content = "# Combined Codebase\n\nCombined documentation from entire codebase."

    {:ok, root_ast} = AST.parse(root_content, generate_ids: true)

    # Add all document ASTs as children
    combined_children = root_ast.children ++ asts
    updated_root = Node.set_children(root_ast, combined_children)

    # Build indexes for the combined document
    AST.build_indexes(updated_root, [:btree, :trigram, :graph])
  end

  defp extract_text_from_node(%Node{type: :text, content: content}) when is_binary(content) do
    content
  end

  defp extract_text_from_node(%Node{children: children}) do
    children
    |> Enum.map(&extract_text_from_node/1)
    |> Enum.join("")
  end

  defp extract_text_from_node(_), do: ""

  defp create_table_of_contents(ast) do
    headings = AST.select(ast, type: :heading)

    toc_items = Enum.map(headings, fn heading ->
      level = heading.attributes.level
      text = extract_text_from_node(heading)
      anchor = slugify(text)

      indent = String.duplicate("  ", level - 1)
      "#{indent}- [#{text}](##{anchor})"
    end)

    toc_content = Enum.join(toc_items, "\n")

    Node.heading("Table of Contents", 2)
    |> Node.add_child(Node.code_block(toc_content, "markdown"))
  end

  defp add_syntax_highlighting_metadata(%Node{type: :code_block} = node) do
    language = node.attributes.language

    highlighting_info = case language do
      "elixir" -> %{highlighter: "tree_sitter", theme: "github_dark"}
      "sql" -> %{highlighter: "prism", theme: "material_dark"}
      "markdown" -> %{highlighter: "markdown_it", theme: "default"}
      _ -> %{highlighter: "generic", theme: "monospace"}
    end

    %{node | metadata: Map.put(node.metadata, :syntax_highlighting, highlighting_info)}
  end

  defp add_syntax_highlighting_metadata(node), do: node

  defp slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end

# Run the examples
ASTExamples.run_all_examples()
