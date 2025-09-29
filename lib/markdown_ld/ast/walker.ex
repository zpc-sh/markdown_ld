defmodule MarkdownLd.AST.Walker do
  @moduledoc """
  Tree traversal operations for Markdown AST nodes.

  Provides efficient depth-first and breadth-first traversal algorithms
  optimized for large document trees and codebase navigation.

  Supports:
  - Early termination with `:halt` returns
  - State accumulation during traversal
  - Conditional traversal with predicates
  - Performance monitoring for large trees
  """

  alias MarkdownLd.AST.Node
  require Logger

  @type traversal_result :: :ok | :halt
  @type visitor_fun :: (Node.t() -> any() | :halt)
  @type accumulator_fun :: (Node.t(), acc :: any() -> {any(), :cont | :halt})
  @type predicate_fun :: (Node.t() -> boolean())

  ## Depth-First Traversal

  @doc """
  Walk the AST depth-first, calling the function on each node.

  Returns `:ok` when traversal completes, or `:halt` if stopped early.

  Examples:
      # Print all node types
      MarkdownLd.AST.Walker.depth_first(ast, &process_node/1)

      # Stop at first code block
      MarkdownLd.AST.Walker.depth_first(ast, fn
        %{type: :code_block} -> :halt
        _node -> :ok
      end)
  """
  @spec depth_first(Node.t(), visitor_fun()) :: traversal_result()
  def depth_first(%Node{} = node, fun) when is_function(fun, 1) do
    case fun.(node) do
      :halt ->
        :halt

      _result ->
        case traverse_children_depth_first(node.children, fun) do
          :halt -> :halt
          :ok -> :ok
        end
    end
  end

  @doc """
  Walk the AST depth-first with an accumulator.

  The function receives the current node and accumulator, returning
  `{new_acc, :cont}` to continue or `{final_acc, :halt}` to stop.

  Examples:
      # Count nodes by type
      {counts, :cont} = MarkdownLd.AST.Walker.depth_first_reduce(ast, %{}, fn n, acc ->
        count = Map.get(acc, n.type, 0)
        {Map.put(acc, n.type, count + 1), :cont}
      end)
  """
  @spec depth_first_reduce(Node.t(), acc :: any(), accumulator_fun()) :: {any(), :cont | :halt}
  def depth_first_reduce(%Node{} = node, acc, fun) when is_function(fun, 2) do
    case fun.(node, acc) do
      {new_acc, :halt} ->
        {new_acc, :halt}

      {new_acc, :cont} ->
        reduce_children_depth_first(node.children, new_acc, fun)
    end
  end

  @doc """
  Walk the AST depth-first, visiting only nodes that match the predicate.

  Examples:
      # Visit only heading nodes
      MarkdownLd.AST.Walker.depth_first_where(ast,
        &(&1.type == :heading),
        &IO.puts("Found heading")
      )
  """
  @spec depth_first_where(Node.t(), predicate_fun(), visitor_fun()) :: traversal_result()
  def depth_first_where(%Node{} = node, predicate, fun)
      when is_function(predicate, 1) and is_function(fun, 1) do
    # Always traverse children regardless of predicate
    children_result = traverse_children_depth_first_where(node.children, predicate, fun)

    # Visit this node if it matches predicate
    if predicate.(node) do
      case fun.(node) do
        :halt -> :halt
        _result -> children_result
      end
    else
      children_result
    end
  end

  ## Breadth-First Traversal

  @doc """
  Walk the AST breadth-first, calling the function on each node.

  More memory intensive than depth-first but useful for level-by-level
  processing or finding nodes at specific depths.

  Examples:
      # Process nodes level by level
      MarkdownLd.AST.Walker.breadth_first(ast, &IO.puts("Processing node"))
  """
  @spec breadth_first(Node.t(), visitor_fun()) :: traversal_result()
  def breadth_first(%Node{} = root, fun) when is_function(fun, 1) do
    breadth_first_with_queue([root], fun)
  end

  @doc """
  Walk the AST breadth-first with an accumulator.
  """
  @spec breadth_first_reduce(Node.t(), acc :: any(), accumulator_fun()) :: {any(), :cont | :halt}
  def breadth_first_reduce(%Node{} = root, acc, fun) when is_function(fun, 2) do
    breadth_first_reduce_with_queue([root], acc, fun)
  end

  @doc """
  Walk the AST breadth-first, visiting only nodes that match the predicate.
  """
  @spec breadth_first_where(Node.t(), predicate_fun(), visitor_fun()) :: traversal_result()
  def breadth_first_where(%Node{} = root, predicate, fun)
      when is_function(predicate, 1) and is_function(fun, 1) do
    breadth_first_where_with_queue([root], predicate, fun)
  end

  ## Level-Order Operations

  @doc """
  Get all nodes at a specific depth level.

  Examples:
      # Get all level-1 headings
      level_1_nodes = MarkdownLd.AST.Walker.nodes_at_level(ast, 1)
      headings = Enum.filter(level_1_nodes, &(&1.type == :heading))
  """
  @spec nodes_at_level(Node.t(), non_neg_integer()) :: [Node.t()]
  def nodes_at_level(%Node{} = root, target_level)
      when is_integer(target_level) and target_level >= 0 do
    nodes_at_level_with_queue([{root, 0}], target_level, [])
  end

  @doc """
  Get nodes grouped by their depth level.

  Returns a map where keys are depth levels and values are lists of nodes.

  Examples:
      levels = MarkdownLd.AST.Walker.nodes_by_level(ast)
      # %{0 => [root], 1 => [child1, child2], 2 => [grandchild1, ...]}
  """
  @spec nodes_by_level(Node.t()) :: %{non_neg_integer() => [Node.t()]}
  def nodes_by_level(%Node{} = root) do
    nodes_by_level_with_queue([{root, 0}], %{})
  end

  @doc """
  Calculate the maximum depth of the tree.

  Examples:
      depth = MarkdownLd.AST.Walker.max_depth(ast)
      IO.puts("Tree has depth levels")
  """
  @spec max_depth(Node.t()) :: non_neg_integer()
  def max_depth(%Node{children: []}) do
    0
  end

  def max_depth(%Node{children: children}) do
    1 + (children |> Enum.map(&max_depth/1) |> Enum.max(fn -> 0 end))
  end

  ## Path Operations

  @doc """
  Find all paths from root to leaves.

  Returns a list of node paths, where each path is a list of nodes
  from root to leaf.

  Examples:
      paths = MarkdownLd.AST.Walker.all_paths(ast)
      text_paths = Enum.filter(paths, fn path ->
        List.last(path).type == :text
      end)
  """
  @spec all_paths(Node.t()) :: [[Node.t()]]
  def all_paths(%Node{} = root) do
    find_all_paths(root, [])
  end

  @doc """
  Find the path from root to a specific node ID.

  Returns the path as a list of nodes, or `nil` if not found.

  Examples:
      case MarkdownLd.AST.Walker.path_to_node(ast, target_id) do
        nil -> IO.puts("Node not found")
        path -> IO.puts("Path found")
      end
  """
  @spec path_to_node(Node.t(), Node.node_id()) :: [Node.t()] | nil
  def path_to_node(%Node{} = root, target_id) do
    find_path_to_node(root, target_id, [])
  end

  @doc """
  Find all nodes that match a predicate, returning their paths.

  Examples:
      # Find paths to all code blocks
      code_paths = MarkdownLd.AST.Walker.paths_where(ast, fn n ->
        n.type == :code_block
      end)
  """
  @spec paths_where(Node.t(), predicate_fun()) :: [[Node.t()]]
  def paths_where(%Node{} = root, predicate) when is_function(predicate, 1) do
    find_paths_where(root, predicate, [])
  end

  ## Performance Monitoring

  @doc """
  Walk the tree with performance monitoring enabled.

  Returns `{result, stats}` where stats includes timing and memory usage.

  Examples:
      {result, stats} = MarkdownLd.AST.Walker.monitored_walk(ast, fn n ->
        # Expensive operation
        process_node(n)
      end)

      IO.puts("Traversed nodes with stats")
  """
  @spec monitored_walk(Node.t(), visitor_fun()) :: {traversal_result(), map()}
  def monitored_walk(%Node{} = root, fun) when is_function(fun, 1) do
    start_time = System.monotonic_time(:microsecond)
    start_memory = get_memory_usage()

    {result, nodes_visited} = monitored_depth_first(root, fun, 0)

    end_time = System.monotonic_time(:microsecond)
    end_memory = get_memory_usage()

    stats = %{
      nodes_visited: nodes_visited,
      time_us: end_time - start_time,
      time_ms: (end_time - start_time) / 1000,
      memory_delta_bytes: end_memory - start_memory,
      traversal_rate_nodes_per_ms: nodes_visited / max((end_time - start_time) / 1000, 1)
    }

    {result, stats}
  end

  ## Private Implementation

  # Depth-first traversal helpers
  defp traverse_children_depth_first([], _fun), do: :ok

  defp traverse_children_depth_first([child | rest], fun) do
    case depth_first(child, fun) do
      :halt -> :halt
      :ok -> traverse_children_depth_first(rest, fun)
    end
  end

  defp reduce_children_depth_first([], acc, _fun), do: {acc, :cont}

  defp reduce_children_depth_first([child | rest], acc, fun) do
    case depth_first_reduce(child, acc, fun) do
      {new_acc, :halt} -> {new_acc, :halt}
      {new_acc, :cont} -> reduce_children_depth_first(rest, new_acc, fun)
    end
  end

  defp traverse_children_depth_first_where([], _predicate, _fun), do: :ok

  defp traverse_children_depth_first_where([child | rest], predicate, fun) do
    case depth_first_where(child, predicate, fun) do
      :halt -> :halt
      :ok -> traverse_children_depth_first_where(rest, predicate, fun)
    end
  end

  # Breadth-first traversal helpers
  defp breadth_first_with_queue([], _fun), do: :ok

  defp breadth_first_with_queue([node | rest], fun) do
    case fun.(node) do
      :halt ->
        :halt

      _result ->
        new_queue = rest ++ node.children
        breadth_first_with_queue(new_queue, fun)
    end
  end

  defp breadth_first_reduce_with_queue([], acc, _fun), do: {acc, :cont}

  defp breadth_first_reduce_with_queue([node | rest], acc, fun) do
    case fun.(node, acc) do
      {new_acc, :halt} ->
        {new_acc, :halt}

      {new_acc, :cont} ->
        new_queue = rest ++ node.children
        breadth_first_reduce_with_queue(new_queue, new_acc, fun)
    end
  end

  defp breadth_first_where_with_queue([], _predicate, _fun), do: :ok

  defp breadth_first_where_with_queue([node | rest], predicate, fun) do
    result =
      if predicate.(node) do
        fun.(node)
      else
        :ok
      end

    case result do
      :halt ->
        :halt

      _result ->
        new_queue = rest ++ node.children
        breadth_first_where_with_queue(new_queue, predicate, fun)
    end
  end

  # Level-order operation helpers
  defp nodes_at_level_with_queue([], _target_level, acc), do: Enum.reverse(acc)

  defp nodes_at_level_with_queue([{node, level} | rest], target_level, acc) do
    cond do
      level == target_level ->
        # Found a node at target level
        nodes_at_level_with_queue(rest, target_level, [node | acc])

      level < target_level ->
        # Haven't reached target level yet, add children
        child_items = Enum.map(node.children, &{&1, level + 1})
        nodes_at_level_with_queue(rest ++ child_items, target_level, acc)

      level > target_level ->
        # Past target level, skip
        nodes_at_level_with_queue(rest, target_level, acc)
    end
  end

  defp nodes_by_level_with_queue([], acc), do: acc

  defp nodes_by_level_with_queue([{node, level} | rest], acc) do
    # Add node to its level group
    level_nodes = Map.get(acc, level, [])
    new_acc = Map.put(acc, level, [node | level_nodes])

    # Add children to queue
    child_items = Enum.map(node.children, &{&1, level + 1})
    nodes_by_level_with_queue(rest ++ child_items, new_acc)
  end

  # Path operation helpers
  defp find_all_paths(%Node{children: []} = leaf, path) do
    [Enum.reverse([leaf | path])]
  end

  defp find_all_paths(%Node{children: children} = node, path) do
    new_path = [node | path]
    Enum.flat_map(children, &find_all_paths(&1, new_path))
  end

  defp find_path_to_node(%Node{id: target_id} = node, target_id, path) do
    Enum.reverse([node | path])
  end

  defp find_path_to_node(%Node{children: children} = node, target_id, path) do
    new_path = [node | path]

    children
    |> Enum.find_value(fn child ->
      find_path_to_node(child, target_id, new_path)
    end)
  end

  defp find_paths_where(%Node{} = node, predicate, path) do
    new_path = [node | path]

    # Check if this node matches
    node_paths =
      if predicate.(node) do
        [Enum.reverse(new_path)]
      else
        []
      end

    # Check children
    child_paths = Enum.flat_map(node.children, &find_paths_where(&1, predicate, new_path))

    node_paths ++ child_paths
  end

  # Performance monitoring helpers
  defp monitored_depth_first(%Node{} = node, fun, count) do
    result = fun.(node)
    new_count = count + 1

    case result do
      :halt ->
        {:halt, new_count}

      _result ->
        {final_result, final_count} = monitored_traverse_children(node.children, fun, new_count)
        {final_result, final_count}
    end
  end

  defp monitored_traverse_children([], _fun, count), do: {:ok, count}

  defp monitored_traverse_children([child | rest], fun, count) do
    case monitored_depth_first(child, fun, count) do
      {:halt, new_count} -> {:halt, new_count}
      {:ok, new_count} -> monitored_traverse_children(rest, fun, new_count)
    end
  end

  defp get_memory_usage do
    :erlang.memory(:total)
  end

  ## Utility Functions

  @doc """
  Count total nodes in the tree.
  """
  @spec count_nodes(Node.t()) :: non_neg_integer()
  def count_nodes(%Node{} = root) do
    {_result, count} =
      depth_first_reduce(root, 0, fn _node, acc ->
        {acc + 1, :cont}
      end)

    count
  end

  @doc """
  Check if the tree contains a node with the given ID.
  """
  @spec contains_node?(Node.t(), Node.node_id()) :: boolean()
  def contains_node?(%Node{} = root, target_id) do
    result =
      depth_first(root, fn
        %{id: ^target_id} -> :halt
        _node -> :ok
      end)

    result == :halt
  end

  @doc """
  Get all leaf nodes (nodes with no children).
  """
  @spec leaf_nodes(Node.t()) :: [Node.t()]
  def leaf_nodes(%Node{} = root) do
    {leaves, _result} =
      depth_first_reduce(root, [], fn
        %{children: []} = node, acc -> {[node | acc], :cont}
        _node, acc -> {acc, :cont}
      end)

    Enum.reverse(leaves)
  end

  @doc """
  Get the parent-child relationships as a map.

  Returns `%{child_id => parent_id}` mapping.
  """
  @spec parent_child_map(Node.t()) :: %{Node.node_id() => Node.node_id()}
  def parent_child_map(%Node{} = root) do
    {map, _result} =
      depth_first_reduce(root, %{}, fn node, acc ->
        child_mappings =
          node.children
          |> Enum.reduce(%{}, fn child, child_acc ->
            Map.put(child_acc, child.id, node.id)
          end)

        {Map.merge(acc, child_mappings), :cont}
      end)

    map
  end
end
