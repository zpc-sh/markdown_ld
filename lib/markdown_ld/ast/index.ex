defmodule MarkdownLd.AST.Index do
  @moduledoc """
  Comprehensive indexing system for Markdown AST nodes.

  Provides multiple index types optimized for different query patterns:

  - **B+ Tree Index**: File path queries with range support O(log n)
  - **Trigram Index**: Full-text search with fuzzy matching
  - **Graph Index**: Document relationship mapping with traversal optimization
  - **Semantic Index**: Vector embeddings using HNSW for semantic search

  Designed for large-scale codebase storage with efficient memory usage
  and fast query performance.
  """

  alias MarkdownLd.AST.Node
  require Logger
  import Bitwise

  # Index type definitions
  @type index_type :: :btree | :trigram | :graph | :semantic
  @type node_id :: binary()
  @type file_path :: binary()
  @type trigram :: binary()
  @type vector :: [float()]
  @type similarity_score :: float()

  # B+ Tree structures
  @type btree_key :: file_path()
  @type btree_value :: %{node_id: node_id(), metadata: map()}
  @type btree_node :: %{
          keys: [btree_key()],
          values: [btree_value()],
          children: [btree_node()] | nil,
          is_leaf: boolean(),
          parent: btree_node() | nil
        }

  # Trigram index structures
  @type trigram_entry :: %{
          trigram: trigram(),
          documents: MapSet.t(node_id()),
          positions: %{node_id() => [pos_integer()]}
        }

  # Graph index structures
  @type graph_edge :: %{
          from: node_id(),
          to: node_id(),
          type: atom(),
          weight: float(),
          metadata: map()
        }

  # Semantic index structures (HNSW)
  @type hnsw_node :: %{
          id: node_id(),
          vector: vector(),
          level: non_neg_integer(),
          connections: %{non_neg_integer() => [node_id()]}
        }

  @type index_state :: %{
          btree: btree_node() | nil,
          trigram: %{trigram() => trigram_entry()},
          graph: %{
            edges: [graph_edge()],
            adjacency: %{node_id() => [graph_edge()]},
            bloom_filter: binary()
          },
          semantic: %{
            nodes: %{node_id() => hnsw_node()},
            entry_point: node_id() | nil,
            level_multiplier: float(),
            max_connections: pos_integer()
          }
        }

  # Configuration constants
  @btree_order 64
  @trigram_length 3
  @semantic_dimensions 384
  @hnsw_max_connections 16
  @hnsw_level_multiplier 1.0 / :math.log(2.0)
  @bloom_filter_size 8192
  @bloom_filter_hashes 3

  ## Core Index Operations

  @doc """
  Build all indexes for an AST document.
  """
  @spec build_all(Node.t()) :: Node.t()
  def build_all(%Node{} = ast) do
    start_time = System.monotonic_time(:microsecond)

    indexes = %{
      btree: build_btree_index(ast),
      trigram: build_trigram_index(ast),
      graph: build_graph_index(ast),
      semantic: build_semantic_index(ast)
    }

    build_time = System.monotonic_time(:microsecond) - start_time

    Logger.debug("Built all indexes in #{build_time}μs")

    %{ast | metadata: Map.put(ast.metadata, :indexes, indexes)}
  end

  @doc """
  Build specific index types for an AST document.
  """
  @spec build_specific(Node.t(), [index_type()]) :: Node.t()
  def build_specific(%Node{} = ast, index_types) when is_list(index_types) do
    indexes = ast.metadata[:indexes] || %{}

    new_indexes =
      index_types
      |> Enum.reduce(indexes, fn type, acc ->
        case type do
          :btree -> Map.put(acc, :btree, build_btree_index(ast))
          :trigram -> Map.put(acc, :trigram, build_trigram_index(ast))
          :graph -> Map.put(acc, :graph, build_graph_index(ast))
          :semantic -> Map.put(acc, :semantic, build_semantic_index(ast))
          _ -> acc
        end
      end)

    %{ast | metadata: Map.put(ast.metadata, :indexes, new_indexes)}
  end

  @doc """
  Query an indexed AST using different index types.
  """
  @spec query(Node.t(), index_type(), term(), keyword()) :: [Node.t()]
  def query(%Node{metadata: %{indexes: indexes}} = ast, index_type, query_term, opts \\ []) do
    case Map.get(indexes, index_type) do
      nil ->
        Logger.warning("Index type #{index_type} not available")
        []

      index ->
        case index_type do
          :btree -> query_btree(ast, index, query_term, opts)
          :trigram -> query_trigram(ast, index, query_term, opts)
          :graph -> query_graph(ast, index, query_term, opts)
          :semantic -> query_semantic(ast, index, query_term, opts)
        end
    end
  end

  def query(%Node{}, _index_type, _query_term, _opts) do
    Logger.warning("No indexes available for query")
    []
  end

  ## B+ Tree Index Implementation

  defp build_btree_index(%Node{} = ast) do
    # Extract all file paths and create entries
    entries =
      collect_nodes_with_paths(ast)
      |> Enum.sort_by(fn {path, _node} -> path end)
      |> Enum.map(fn {path, node} ->
        {path, %{node_id: node.id, metadata: extract_btree_metadata(node)}}
      end)

    build_btree_from_entries(entries, @btree_order)
  end

  defp collect_nodes_with_paths(%Node{attributes: %{file_path: path}} = node)
       when is_binary(path) do
    [{path, node} | collect_children_paths(node.children)]
  end

  defp collect_nodes_with_paths(%Node{} = node) do
    collect_children_paths(node.children)
  end

  defp collect_children_paths(children) do
    Enum.flat_map(children, &collect_nodes_with_paths/1)
  end

  defp extract_btree_metadata(%Node{} = node) do
    %{
      type: node.type,
      size: calculate_node_size(node),
      modified: node.metadata[:created_at] || DateTime.utc_now(),
      checksum: calculate_node_checksum(node)
    }
  end

  defp build_btree_from_entries(entries, order) do
    if length(entries) <= order do
      # Leaf node
      {keys, values} = Enum.unzip(entries)

      %{
        keys: keys,
        values: values,
        children: nil,
        is_leaf: true,
        parent: nil
      }
    else
      # Internal node - split entries and build children
      chunks = Enum.chunk_every(entries, order)
      children = Enum.map(chunks, &build_btree_from_entries(&1, order))
      keys = Enum.map(children, fn child -> List.first(child.keys) end)

      %{
        keys: keys,
        values: [],
        children: children,
        is_leaf: false,
        parent: nil
      }
    end
  end

  defp query_btree(%Node{} = ast, btree, path_pattern, opts) do
    case path_pattern do
      {:range, start_path, end_path} ->
        btree_range_query(ast, btree, start_path, end_path)

      {:prefix, prefix} ->
        btree_prefix_query(ast, btree, prefix)

      {:glob, pattern} ->
        btree_glob_query(ast, btree, pattern)

      path when is_binary(path) ->
        case btree_exact_lookup(btree, path) do
          nil -> []
          node_id -> [find_node_by_id(ast, node_id)]
        end
    end
    |> Enum.reject(&is_nil/1)
  end

  defp btree_exact_lookup(%{is_leaf: true, keys: keys, values: values}, target_key) do
    case Enum.find_index(keys, &(&1 == target_key)) do
      nil ->
        nil

      index ->
        value = Enum.at(values, index)
        value.node_id
    end
  end

  defp btree_exact_lookup(%{is_leaf: false, keys: keys, children: children}, target_key) do
    child_index =
      keys
      |> Enum.with_index()
      |> Enum.find(fn {key, _idx} -> target_key <= key end)
      |> case do
        nil -> length(children) - 1
        {_key, idx} -> idx
      end

    child = Enum.at(children, child_index)
    btree_exact_lookup(child, target_key)
  end

  defp btree_range_query(ast, btree, start_path, end_path) do
    # Simplified range query - collect all keys in range
    all_keys = collect_btree_keys(btree)

    all_keys
    |> Enum.filter(fn key -> key >= start_path and key <= end_path end)
    |> Enum.map(fn key ->
      node_id = btree_exact_lookup(btree, key)
      find_node_by_id(ast, node_id)
    end)
  end

  defp btree_prefix_query(ast, btree, prefix) do
    all_keys = collect_btree_keys(btree)

    all_keys
    |> Enum.filter(fn key -> String.starts_with?(key, prefix) end)
    |> Enum.map(fn key ->
      node_id = btree_exact_lookup(btree, key)
      find_node_by_id(ast, node_id)
    end)
  end

  defp btree_glob_query(ast, btree, pattern) do
    # Convert glob to regex
    regex_pattern =
      pattern
      |> String.replace("*", ".*")
      |> String.replace("?", ".")
      |> then(&("^" <> &1 <> "$"))
      |> Regex.compile!()

    all_keys = collect_btree_keys(btree)

    all_keys
    |> Enum.filter(fn key -> Regex.match?(regex_pattern, key) end)
    |> Enum.map(fn key ->
      node_id = btree_exact_lookup(btree, key)
      find_node_by_id(ast, node_id)
    end)
  end

  defp collect_btree_keys(%{is_leaf: true, keys: keys}), do: keys

  defp collect_btree_keys(%{is_leaf: false, children: children}) do
    Enum.flat_map(children, &collect_btree_keys/1)
  end

  ## Trigram Index Implementation

  defp build_trigram_index(%Node{} = ast) do
    # Extract all text content and generate trigrams
    text_nodes = collect_text_nodes(ast)

    text_nodes
    |> Enum.reduce(%{}, fn {node_id, text}, acc ->
      trigrams = extract_trigrams(text)

      Enum.reduce(trigrams, acc, fn {trigram, positions}, trigram_acc ->
        entry =
          Map.get(trigram_acc, trigram, %{
            trigram: trigram,
            documents: MapSet.new(),
            positions: %{}
          })

        updated_entry = %{
          entry
          | documents: MapSet.put(entry.documents, node_id),
            positions: Map.put(entry.positions, node_id, positions)
        }

        Map.put(trigram_acc, trigram, updated_entry)
      end)
    end)
  end

  defp collect_text_nodes(%Node{} = node) do
    collect_text_nodes(node, [])
  end

  defp collect_text_nodes(%Node{type: :text, content: content, id: id}, acc)
       when is_binary(content) do
    [{id, content} | acc]
  end

  defp collect_text_nodes(%Node{children: children}, acc) do
    Enum.reduce(children, acc, &collect_text_nodes/2)
  end

  defp extract_trigrams(text) do
    # Normalize text and extract trigrams with positions
    normalized = String.downcase(text)

    normalized
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.chunk_every(@trigram_length, 1, :discard)
    |> Enum.group_by(
      fn chunk ->
        chunk |> Enum.map(fn {char, _pos} -> char end) |> Enum.join()
      end,
      fn chunk ->
        {_char, pos} = List.first(chunk)
        pos
      end
    )
  end

  defp query_trigram(%Node{} = ast, trigram_index, query_text, opts) do
    fuzzy_threshold = Keyword.get(opts, :fuzzy, 0.0)
    max_results = Keyword.get(opts, :limit, 100)

    query_trigrams = extract_trigrams(String.downcase(query_text))
    query_trigram_set = MapSet.new(Map.keys(query_trigrams))

    # Find documents containing query trigrams
    matching_docs =
      query_trigram_set
      |> Enum.reduce(MapSet.new(), fn trigram, acc ->
        case Map.get(trigram_index, trigram) do
          nil -> acc
          entry -> MapSet.union(acc, entry.documents)
        end
      end)

    # Score documents by trigram overlap and fuzzy similarity
    scored_results =
      matching_docs
      |> Enum.map(fn node_id ->
        node = find_node_by_id(ast, node_id)
        text = extract_node_text(node)

        trigram_score = calculate_trigram_similarity(query_trigrams, extract_trigrams(text))

        fuzzy_score =
          if fuzzy_threshold > 0.0 do
            calculate_levenshtein_similarity(query_text, text)
          else
            0.0
          end

        final_score = max(trigram_score, fuzzy_score)

        {node, final_score}
      end)
      |> Enum.filter(fn {_node, score} -> score >= fuzzy_threshold end)
      |> Enum.sort_by(fn {_node, score} -> score end, :desc)
      |> Enum.take(max_results)
      |> Enum.map(fn {node, _score} -> node end)

    scored_results
  end

  defp calculate_trigram_similarity(query_trigrams, doc_trigrams) do
    query_set = MapSet.new(Map.keys(query_trigrams))
    doc_set = MapSet.new(Map.keys(doc_trigrams))

    intersection_size = MapSet.intersection(query_set, doc_set) |> MapSet.size()
    union_size = MapSet.union(query_set, doc_set) |> MapSet.size()

    if union_size == 0, do: 0.0, else: intersection_size / union_size
  end

  defp calculate_levenshtein_similarity(str1, str2) do
    max_len = max(String.length(str1), String.length(str2))
    if max_len == 0, do: 1.0, else: 1.0 - levenshtein_distance(str1, str2) / max_len
  end

  defp levenshtein_distance(str1, str2) do
    # Simplified Levenshtein distance calculation
    len1 = String.length(str1)
    len2 = String.length(str2)

    cond do
      len1 == 0 -> len2
      len2 == 0 -> len1
      true -> levenshtein_matrix(String.graphemes(str1), String.graphemes(str2))
    end
  end

  defp levenshtein_matrix(chars1, chars2) do
    len1 = length(chars1)
    len2 = length(chars2)

    # Initialize matrix
    matrix =
      0..len1
      |> Enum.reduce(%{}, fn i, acc ->
        0..len2
        |> Enum.reduce(acc, fn j, inner_acc ->
          cond do
            i == 0 -> Map.put(inner_acc, {i, j}, j)
            j == 0 -> Map.put(inner_acc, {i, j}, i)
            true -> Map.put(inner_acc, {i, j}, 0)
          end
        end)
      end)

    # Fill matrix
    chars1_indexed = Enum.with_index(chars1, 1)
    chars2_indexed = Enum.with_index(chars2, 1)

    Enum.reduce(chars1_indexed, matrix, fn {char1, i}, acc ->
      Enum.reduce(chars2_indexed, acc, fn {char2, j}, inner_acc ->
        cost = if char1 == char2, do: 0, else: 1

        deletion = Map.get(inner_acc, {i - 1, j}) + 1
        insertion = Map.get(inner_acc, {i, j - 1}) + 1
        substitution = Map.get(inner_acc, {i - 1, j - 1}) + cost

        min_cost = Enum.min([deletion, insertion, substitution])
        Map.put(inner_acc, {i, j}, min_cost)
      end)
    end)
    |> Map.get({len1, len2})
  end

  ## Graph Index Implementation

  defp build_graph_index(%Node{} = ast) do
    edges = extract_graph_edges(ast)
    adjacency = build_adjacency_list(edges)
    bloom_filter = build_bloom_filter(edges)

    %{
      edges: edges,
      adjacency: adjacency,
      bloom_filter: bloom_filter
    }
  end

  defp extract_graph_edges(%Node{} = node) do
    extract_graph_edges(node, [])
  end

  defp extract_graph_edges(%Node{type: :link, attributes: %{url: url}, id: id}, acc) do
    # Create edges for links
    edge = %{
      from: id,
      # This could be resolved to actual node IDs
      to: url,
      type: :link,
      weight: 1.0,
      metadata: %{link_type: :external}
    }

    [edge | acc]
  end

  defp extract_graph_edges(%Node{children: children}, acc) do
    Enum.reduce(children, acc, &extract_graph_edges/2)
  end

  defp build_adjacency_list(edges) do
    Enum.reduce(edges, %{}, fn edge, acc ->
      from_edges = Map.get(acc, edge.from, [])
      Map.put(acc, edge.from, [edge | from_edges])
    end)
  end

  defp build_bloom_filter(edges) do
    # Simple bloom filter implementation
    filter = :binary.copy(<<0>>, @bloom_filter_size)

    Enum.reduce(edges, filter, fn edge, acc ->
      set_bloom_bits(acc, edge.from <> edge.to)
    end)
  end

  defp set_bloom_bits(filter, data) do
    hash1 = :erlang.phash2(data, @bloom_filter_size * 8)
    hash2 = :erlang.phash2(data <> "salt", @bloom_filter_size * 8)
    hash3 = :erlang.phash2("salt" <> data, @bloom_filter_size * 8)

    filter
    |> set_bit(hash1)
    |> set_bit(hash2)
    |> set_bit(hash3)
  end

  defp set_bit(binary, bit_position) do
    byte_pos = div(bit_position, 8)
    bit_pos = rem(bit_position, 8)

    <<prefix::binary-size(byte_pos), byte::8, suffix::binary>> = binary
    new_byte = bor(byte, bsl(1, bit_pos))
    <<prefix::binary, new_byte::8, suffix::binary>>
  end

  defp query_graph(%Node{} = ast, graph_index, query, opts) do
    case query do
      {:outbound, node_id} ->
        get_outbound_connections(ast, graph_index, node_id)

      {:inbound, node_id} ->
        get_inbound_connections(ast, graph_index, node_id)

      {:path, from_id, to_id} ->
        find_path(ast, graph_index, from_id, to_id, opts)

      {:connected_component, node_id} ->
        find_connected_component(ast, graph_index, node_id)
    end
  end

  defp get_outbound_connections(%Node{} = ast, %{adjacency: adjacency}, node_id) do
    case Map.get(adjacency, node_id) do
      nil ->
        []

      edges ->
        edges
        |> Enum.map(& &1.to)
        |> Enum.map(&find_node_by_id(ast, &1))
        |> Enum.reject(&is_nil/1)
    end
  end

  defp get_inbound_connections(%Node{} = ast, %{edges: edges}, node_id) do
    edges
    |> Enum.filter(&(&1.to == node_id))
    |> Enum.map(& &1.from)
    |> Enum.map(&find_node_by_id(ast, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp find_path(%Node{} = ast, graph_index, from_id, to_id, opts) do
    max_depth = Keyword.get(opts, :max_depth, 10)

    # Simple BFS path finding
    bfs_path(ast, graph_index, from_id, to_id, max_depth)
  end

  defp bfs_path(%Node{} = ast, graph_index, from_id, to_id, max_depth) do
    queue = [{from_id, [from_id], 0}]
    visited = MapSet.new([from_id])

    bfs_path_loop(ast, graph_index, queue, visited, to_id, max_depth)
  end

  defp bfs_path_loop(_ast, _graph_index, [], _visited, _to_id, _max_depth), do: []

  defp bfs_path_loop(
         %Node{} = ast,
         graph_index,
         [{current, path, depth} | rest],
         visited,
         to_id,
         max_depth
       ) do
    if current == to_id do
      Enum.map(path, &find_node_by_id(ast, &1)) |> Enum.reject(&is_nil/1)
    else
      if depth >= max_depth do
        bfs_path_loop(ast, graph_index, rest, visited, to_id, max_depth)
      else
        neighbors = get_outbound_connections(ast, graph_index, current)

        new_queue_items =
          neighbors
          |> Enum.map(& &1.id)
          |> Enum.reject(&MapSet.member?(visited, &1))
          |> Enum.map(fn neighbor_id ->
            {neighbor_id, path ++ [neighbor_id], depth + 1}
          end)

        new_visited =
          neighbors
          |> Enum.map(& &1.id)
          |> Enum.reduce(visited, &MapSet.put(&2, &1))

        bfs_path_loop(ast, graph_index, rest ++ new_queue_items, new_visited, to_id, max_depth)
      end
    end
  end

  defp find_connected_component(%Node{} = ast, graph_index, node_id) do
    # DFS to find all connected nodes
    visited = MapSet.new()
    component = dfs_component(ast, graph_index, node_id, visited, [])

    component
    |> Enum.map(&find_node_by_id(ast, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp dfs_component(%Node{} = ast, graph_index, node_id, visited, component) do
    if MapSet.member?(visited, node_id) do
      component
    else
      new_visited = MapSet.put(visited, node_id)
      new_component = [node_id | component]

      neighbors = get_outbound_connections(ast, graph_index, node_id)

      Enum.reduce(neighbors, new_component, fn neighbor, acc ->
        dfs_component(ast, graph_index, neighbor.id, new_visited, acc)
      end)
    end
  end

  ## Semantic Index Implementation (HNSW)

  defp build_semantic_index(%Node{} = ast) do
    # Extract text content and generate embeddings
    text_nodes = collect_text_nodes(ast)

    # This would typically call an embedding service
    # For now, we'll create random vectors as placeholders
    nodes_with_vectors =
      text_nodes
      |> Enum.map(fn {node_id, text} ->
        # Placeholder
        vector = generate_embedding(text)
        level = determine_hnsw_level()

        {node_id,
         %{
           id: node_id,
           vector: vector,
           level: level,
           connections: %{}
         }}
      end)
      |> Enum.into(%{})

    # Build HNSW structure
    entry_point =
      nodes_with_vectors
      |> Map.values()
      |> Enum.max_by(& &1.level)
      |> Map.get(:id)

    # Connect nodes in HNSW structure
    connected_nodes = build_hnsw_connections(nodes_with_vectors)

    %{
      nodes: connected_nodes,
      entry_point: entry_point,
      level_multiplier: @hnsw_level_multiplier,
      max_connections: @hnsw_max_connections
    }
  end

  defp generate_embedding(_text) do
    # Placeholder: generate random vector
    # In production, this would call OpenAI, Cohere, or local embedding model
    for _ <- 1..@semantic_dimensions, do: :rand.normal()
  end

  defp determine_hnsw_level do
    # Exponential decay probability for HNSW levels
    determine_hnsw_level_recursive(0)
  end

  defp determine_hnsw_level_recursive(level) do
    if :rand.uniform() < @hnsw_level_multiplier do
      determine_hnsw_level_recursive(level + 1)
    else
      level
    end
  end

  defp build_hnsw_connections(nodes) do
    # Simplified HNSW connection building
    # In production, this would implement proper HNSW construction algorithm

    node_list = Map.values(nodes)

    Enum.reduce(node_list, nodes, fn node, acc ->
      # Find closest nodes for connections
      closest_nodes =
        node_list
        |> Enum.reject(&(&1.id == node.id))
        |> Enum.map(fn other ->
          distance = cosine_distance(node.vector, other.vector)
          {other.id, distance}
        end)
        |> Enum.sort_by(fn {_id, distance} -> distance end)
        |> Enum.take(@hnsw_max_connections)
        |> Enum.map(fn {id, _distance} -> id end)

      connections =
        0..node.level
        |> Enum.reduce(%{}, fn level, level_acc ->
          level_connections =
            closest_nodes
            |> Enum.take(max(1, div(@hnsw_max_connections, level + 1)))

          Map.put(level_acc, level, level_connections)
        end)

      updated_node = %{node | connections: connections}
      Map.put(acc, node.id, updated_node)
    end)
  end

  defp cosine_distance(vector1, vector2) do
    dot_product = Enum.zip(vector1, vector2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
    norm1 = :math.sqrt(Enum.map(vector1, &(&1 * &1)) |> Enum.sum())
    norm2 = :math.sqrt(Enum.map(vector2, &(&1 * &1)) |> Enum.sum())

    1.0 - dot_product / (norm1 * norm2)
  end

  defp query_semantic(%Node{} = ast, semantic_index, query_text, opts) do
    top_k = Keyword.get(opts, :top_k, 10)

    # Generate query vector
    query_vector = generate_embedding(query_text)

    # Search HNSW structure
    candidates = search_hnsw(semantic_index, query_vector, top_k * 2)

    # Score and rank results
    candidates
    |> Enum.map(fn node_id ->
      node = find_node_by_id(ast, node_id)
      hnsw_node = Map.get(semantic_index.nodes, node_id)
      similarity = 1.0 - cosine_distance(query_vector, hnsw_node.vector)

      {node, similarity}
    end)
    |> Enum.sort_by(fn {_node, similarity} -> similarity end, :desc)
    |> Enum.take(top_k)
    |> Enum.map(fn {node, _similarity} -> node end)
  end

  defp search_hnsw(semantic_index, query_vector, num_closest) do
    # Simplified HNSW search - start from entry point and greedily descend
    entry_point = semantic_index.entry_point

    if entry_point do
      search_level(semantic_index, query_vector, entry_point, num_closest)
    else
      []
    end
  end

  defp search_level(semantic_index, query_vector, start_node_id, num_closest) do
    start_node = Map.get(semantic_index.nodes, start_node_id)

    # Greedy search from start node
    visited = MapSet.new([start_node_id])
    candidates = [start_node_id]

    greedy_search(semantic_index, query_vector, candidates, visited, num_closest)
  end

  defp greedy_search(semantic_index, query_vector, candidates, visited, num_closest) do
    # Score all candidates by distance to query
    scored_candidates =
      candidates
      |> Enum.map(fn node_id ->
        node = Map.get(semantic_index.nodes, node_id)
        distance = cosine_distance(query_vector, node.vector)
        {node_id, distance}
      end)
      |> Enum.sort_by(fn {_id, distance} -> distance end)
      |> Enum.take(num_closest)

    # Return the closest candidates
    Enum.map(scored_candidates, fn {node_id, _distance} -> node_id end)
  end

  ## Utility Functions

  defp calculate_node_size(%Node{content: content, children: children}) do
    content_size = if is_binary(content), do: byte_size(content), else: 0
    children_size = Enum.reduce(children, 0, fn child, acc -> acc + calculate_node_size(child) end)
    content_size + children_size
  end

  defp calculate_node_checksum(%Node{} = node) do
    content = inspect(node, limit: :infinity)
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  defp find_node_by_id(%Node{id: id} = node, target_id) when id == target_id, do: node

  defp find_node_by_id(%Node{children: children}, target_id) do
    Enum.find_value(children, &find_node_by_id(&1, target_id))
  end

  defp find_node_by_id(_, _), do: nil

  defp extract_node_text(%Node{type: :text, content: content}) when is_binary(content) do
    content
  end

  defp extract_node_text(%Node{children: children}) do
    children
    |> Enum.map(&extract_node_text/1)
    |> Enum.join(" ")
  end

  defp extract_node_text(_), do: ""
end
