defmodule MarkdownLd.AST.Transform do
  @moduledoc """
  Tree transformation operations for Markdown AST nodes.

  Provides comprehensive transformation capabilities for modifying AST
  structures while maintaining tree integrity and relationships.

  Supports:
  - Map transformations (apply function to all nodes)
  - Targeted transformations (modify specific node types)
  - Structural transformations (add, remove, reorder nodes)
  - Bulk operations for performance
  - Validation of tree integrity after transformations
  """

  alias MarkdownLd.AST.{Node, Walker}

  @type transform_fun :: (Node.t() -> Node.t())
  @type targeted_transform_fun :: (Node.t() -> Node.t() | :delete | {:replace_with, [Node.t()]})
  @type insertion_point :: :before | :after | :inside_start | :inside_end
  @type transform_result :: {:ok, Node.t()} | {:error, term()}

  ## Core Transformation Operations

  @doc """
  Apply a transformation function to every node in the tree.

  The function receives each node and must return the transformed node.
  Parent-child relationships are automatically updated.

  Examples:
      # Add metadata to all nodes
      transformed = Transform.map_tree(ast, fn node ->
        %{node | metadata: Map.put(node.metadata, :processed, true)}
      end)

      # Convert all emphasis to strong
      transformed = Transform.map_tree(ast, fn
        %{type: :emphasis} = node -> %{node | type: :strong}
        node -> node
      end)
  """
  @spec map_tree(Node.t(), transform_fun()) :: Node.t()
  def map_tree(%Node{} = ast, transform_fun) when is_function(transform_fun, 1) do
    transformed_node = transform_fun.(ast)

    if transformed_node.children != [] do
      transformed_children =
        transformed_node.children
        |> Enum.map(&map_tree(&1, transform_fun))
        |> Enum.map(&%{&1 | parent_id: transformed_node.id})

      %{transformed_node | children: transformed_children}
    else
      transformed_node
    end
  end

  @doc """
  Apply transformations only to nodes matching specific criteria.

  The transform function can return:
  - A transformed node
  - `:delete` to remove the node
  - `{:replace_with, [nodes]}` to replace with multiple nodes

  Examples:
      # Remove all empty paragraphs
      Transform.transform_where(ast,
        fn node -> node.type == :paragraph and node.children == [] end,
        fn _node -> :delete end
      )

      # Replace code blocks with syntax highlighting
      Transform.transform_where(ast,
        fn node -> node.type == :code_block end,
        fn node -> add_syntax_highlighting(node) end
      )

      # Split long paragraphs into multiple paragraphs
      Transform.transform_where(ast,
        fn node -> node.type == :paragraph and length(node.children) > 10 end,
        fn node -> {:replace_with, split_paragraph(node)} end
      )
  """
  @spec transform_where(Node.t(), (Node.t() -> boolean()), targeted_transform_fun()) :: Node.t()
  def transform_where(%Node{} = ast, predicate, transform_fun)
      when is_function(predicate, 1) and is_function(transform_fun, 1) do
    if predicate.(ast) do
      case transform_fun.(ast) do
        :delete ->
          # Return nil to indicate deletion - parent will handle
          nil

        {:replace_with, replacement_nodes} when is_list(replacement_nodes) ->
          # Return special tuple - parent will handle
          {:replace_with, replacement_nodes}

        transformed_node ->
          # Transform children and update relationships
          process_children_for_transform(transformed_node, predicate, transform_fun)
      end
    else
      # Node doesn't match predicate, but process children
      process_children_for_transform(ast, predicate, transform_fun)
    end
  end

  @doc """
  Insert nodes at specific positions relative to target nodes.

  Examples:
      # Add table of contents before first heading
      Transform.insert_nodes(ast,
        [type: :heading, level: 1],
        :before,
        [create_toc_node()]
      )

      # Add closing paragraph after all code blocks
      Transform.insert_nodes(ast,
        [type: :code_block],
        :after,
        [create_closing_paragraph()]
      )
  """
  @spec insert_nodes(Node.t(), keyword(), insertion_point(), [Node.t()]) :: Node.t()
  def insert_nodes(%Node{} = ast, target_criteria, position, nodes_to_insert) do
    transform_where(
      ast,
      # Transform all container nodes
      fn _node -> true end,
      fn node ->
        if has_children?(node) do
          new_children =
            insert_at_positions(node.children, target_criteria, position, nodes_to_insert)

          %{node | children: new_children}
        else
          node
        end
      end
    )
  end

  @doc """
  Remove all nodes matching the given criteria.

  Examples:
      # Remove all comments
      Transform.remove_nodes(ast, type: :comment)

      # Remove empty list items
      Transform.remove_nodes(ast, fn node ->
        node.type == :list_item and node.children == []
      end)
  """
  @spec remove_nodes(Node.t(), keyword() | (Node.t() -> boolean())) :: Node.t()
  def remove_nodes(%Node{} = ast, criteria) do
    predicate = build_predicate(criteria)

    transform_where(ast, predicate, fn _node -> :delete end)
  end

  @doc """
  Replace nodes matching criteria with new nodes.

  Examples:
      # Replace all images with figure elements
      Transform.replace_nodes(ast,
        [type: :image],
        fn image_node -> create_figure_node(image_node) end
      )
  """
  @spec replace_nodes(Node.t(), keyword() | (Node.t() -> boolean()), (Node.t() ->
                                                                        Node.t() | [Node.t()])) ::
          Node.t()
  def replace_nodes(%Node{} = ast, criteria, replacement_fun)
      when is_function(replacement_fun, 1) do
    predicate = build_predicate(criteria)

    transform_where(ast, predicate, fn node ->
      case replacement_fun.(node) do
        replacement when is_struct(replacement, Node) -> replacement
        replacements when is_list(replacements) -> {:replace_with, replacements}
      end
    end)
  end

  ## Structural Transformations

  @doc """
  Reorder children of container nodes based on a sorting function.

  Examples:
      # Sort list items alphabetically
      Transform.sort_children(ast,
        fn node -> node.type == :list end,
        fn child -> extract_text_content(child) end
      )

      # Sort headings by level
      Transform.sort_children(ast,
        fn node -> node.type == :document end,
        fn child ->
          case child.type do
            :heading -> {0, child.attributes.level}
            _ -> {1, 0}
          end
        end
      )
  """
  @spec sort_children(Node.t(), (Node.t() -> boolean()), (Node.t() -> term())) :: Node.t()
  def sort_children(%Node{} = ast, container_predicate, sort_fun) do
    transform_where(ast, container_predicate, fn node ->
      if has_children?(node) do
        sorted_children = Enum.sort_by(node.children, sort_fun)
        %{node | children: sorted_children}
      else
        node
      end
    end)
  end

  @doc """
  Group consecutive nodes that match criteria into container nodes.

  Examples:
      # Group consecutive list items into lists
      Transform.group_consecutive(ast,
        fn node -> node.type == :list_item end,
        fn items -> Node.list(:unordered, children: items) end
      )
  """
  @spec group_consecutive(Node.t(), (Node.t() -> boolean()), ([Node.t()] -> Node.t())) :: Node.t()
  def group_consecutive(%Node{} = ast, item_predicate, group_fun) do
    transform_where(
      ast,
      fn node -> has_children?(node) end,
      fn node ->
        grouped_children = group_consecutive_children(node.children, item_predicate, group_fun)
        %{node | children: grouped_children}
      end
    )
  end

  @doc """
  Flatten nested structures by promoting children to the parent level.

  Examples:
      # Flatten nested emphasis (bold inside italic becomes just bold)
      Transform.flatten_nested(ast,
        [:emphasis, :strong],
        fn nodes -> Enum.find(nodes, &(&1.type == :strong)) || List.first(nodes) end
      )
  """
  @spec flatten_nested(Node.t(), [atom()], ([Node.t()] -> Node.t())) :: Node.t()
  def flatten_nested(%Node{} = ast, flattenable_types, resolution_fun) do
    map_tree(ast, fn node ->
      if node.type in flattenable_types and has_nested_same_type?(node, flattenable_types) do
        flattened_children = collect_nested_content(node, flattenable_types)
        resolution_fun.(flattened_children)
      else
        node
      end
    end)
  end

  ## Content Transformations

  @doc """
  Update text content using a transformation function.

  Examples:
      # Convert all text to lowercase
      Transform.transform_text(ast, &String.downcase/1)

      # Replace smart quotes with regular quotes
      Transform.transform_text(ast, fn text ->
        text
        |> String.replace(\""", "\"")
        |> String.replace(\""", "\"")
        |> String.replace("'", "'")
        |> String.replace("'", "'")
      end)
  """
  @spec transform_text(Node.t(), (binary() -> binary())) :: Node.t()
  def transform_text(%Node{} = ast, text_transform_fun) when is_function(text_transform_fun, 1) do
    map_tree(ast, fn
      %{type: :text, content: content} = node when is_binary(content) ->
        %{node | content: text_transform_fun.(content)}

      node ->
        node
    end)
  end

  @doc """
  Update attributes using a transformation function.

  Examples:
      # Normalize heading levels (ensure no level skipping)
      Transform.transform_attributes(ast,
        fn node ->
          if node.type == :heading do
            normalized_level = normalize_heading_level(node.attributes.level)
            put_in(node.attributes.level, normalized_level)
          else
            node
          end
        end
      )
  """
  @spec transform_attributes(Node.t(), (Node.t() -> Node.t())) :: Node.t()
  def transform_attributes(%Node{} = ast, attr_transform_fun)
      when is_function(attr_transform_fun, 1) do
    map_tree(ast, attr_transform_fun)
  end

  @doc """
  Update node IDs using a generation function.

  Examples:
      # Regenerate all IDs
      Transform.regenerate_ids(ast)

      # Use content-based IDs for headings
      Transform.transform_ids(ast, fn
        %{type: :heading, content: content} = node ->
          %{node | id: slugify(content)}
        node ->
          node
      end)
  """
  @spec transform_ids(Node.t(), (Node.t() -> Node.t())) :: Node.t()
  def transform_ids(%Node{} = ast, id_transform_fun) when is_function(id_transform_fun, 1) do
    map_tree(ast, id_transform_fun)
  end

  @spec regenerate_ids(Node.t()) :: Node.t()
  def regenerate_ids(%Node{} = ast) do
    transform_ids(ast, fn node ->
      %{node | id: generate_id()}
    end)
  end

  ## Validation and Integrity

  @doc """
  Validate tree integrity after transformations.

  Checks:
  - All parent_id references are valid
  - No circular references
  - All required attributes are present
  - Node relationships are consistent

  Returns `{:ok, ast}` if valid, `{:error, issues}` if problems found.
  """
  @spec validate_integrity(Node.t()) :: transform_result()
  def validate_integrity(%Node{} = ast) do
    issues = []

    # Check parent-child relationships
    issues = check_parent_child_integrity(ast, issues)

    # Check for circular references
    issues = check_circular_references(ast, issues)

    # Check required attributes
    issues = check_required_attributes(ast, issues)

    if issues == [] do
      {:ok, ast}
    else
      {:error, issues}
    end
  end

  @doc """
  Repair common integrity issues automatically.

  Examples:
      {:ok, repaired_ast} = Transform.repair_integrity(corrupted_ast)
  """
  @spec repair_integrity(Node.t()) :: transform_result()
  def repair_integrity(%Node{} = ast) do
    try do
      repaired =
        ast
        |> repair_parent_ids()
        |> repair_missing_ids()
        |> repair_invalid_attributes()

      {:ok, repaired}
    rescue
      error -> {:error, {:repair_failed, error}}
    end
  end

  ## Performance Optimizations

  @doc """
  Apply multiple transformations in a single tree traversal for better performance.

  Examples:
      transforms = [
        {:map, fn node -> add_timestamp(node) end},
        {:where, [type: :heading], fn node -> normalize_heading(node) end},
        {:remove, [type: :comment]}
      ]

      Transform.batch_transform(ast, transforms)
  """
  @spec batch_transform(Node.t(), [tuple()]) :: Node.t()
  def batch_transform(%Node{} = ast, transformations) when is_list(transformations) do
    batch_transform_node(ast, transformations)
  end

  ## Private Implementation

  defp process_children_for_transform(%Node{children: []} = node, _predicate, _transform_fun) do
    node
  end

  defp process_children_for_transform(%Node{children: children} = node, predicate, transform_fun) do
    {transformed_children, _} =
      children
      |> Enum.reduce({[], node.id}, fn child, {acc, parent_id} ->
        case transform_where(child, predicate, transform_fun) do
          nil ->
            # Child was deleted
            {acc, parent_id}

          {:replace_with, replacement_nodes} ->
            # Child was replaced with multiple nodes
            updated_replacements =
              Enum.map(replacement_nodes, &%{&1 | parent_id: parent_id})

            {acc ++ updated_replacements, parent_id}

          transformed_child ->
            # Normal transformation
            updated_child = %{transformed_child | parent_id: parent_id}
            {acc ++ [updated_child], parent_id}
        end
      end)

    %{node | children: transformed_children}
  end

  defp insert_at_positions(children, target_criteria, position, nodes_to_insert) do
    predicate = build_predicate(target_criteria)

    children
    |> Enum.with_index()
    |> Enum.reduce([], fn {child, index}, acc ->
      if predicate.(child) do
        case position do
          :before ->
            acc ++ nodes_to_insert ++ [child]

          :after ->
            acc ++ [child] ++ nodes_to_insert

          :inside_start ->
            updated_child = %{child | children: nodes_to_insert ++ child.children}
            acc ++ [updated_child]

          :inside_end ->
            updated_child = %{child | children: child.children ++ nodes_to_insert}
            acc ++ [updated_child]
        end
      else
        acc ++ [child]
      end
    end)
  end

  defp group_consecutive_children(children, item_predicate, group_fun) do
    children
    |> Enum.chunk_by(item_predicate)
    |> Enum.flat_map(fn chunk ->
      if item_predicate.(List.first(chunk)) do
        [group_fun.(chunk)]
      else
        chunk
      end
    end)
  end

  defp has_nested_same_type?(%Node{children: children}, flattenable_types) do
    Enum.any?(children, fn child ->
      child.type in flattenable_types
    end)
  end

  defp collect_nested_content(%Node{children: children}, flattenable_types) do
    Enum.flat_map(children, fn child ->
      if child.type in flattenable_types do
        [child | collect_nested_content(child, flattenable_types)]
      else
        [child]
      end
    end)
  end

  defp check_parent_child_integrity(%Node{} = ast, issues) do
    {_, new_issues} =
      Walker.depth_first_reduce(ast, issues, fn node, acc ->
        node_issues =
          Enum.reduce(node.children, [], fn child, child_issues ->
            if child.parent_id != node.id do
              issue = {:invalid_parent_id, child.id, child.parent_id, node.id}
              [issue | child_issues]
            else
              child_issues
            end
          end)

        {acc ++ node_issues, :cont}
      end)

    new_issues
  end

  defp check_circular_references(%Node{} = ast, issues) do
    visited = MapSet.new()
    check_circular_refs_recursive(ast, visited, issues)
  end

  defp check_circular_refs_recursive(%Node{id: id} = node, visited, issues) do
    if MapSet.member?(visited, id) do
      [{:circular_reference, id} | issues]
    else
      new_visited = MapSet.put(visited, id)

      Enum.reduce(node.children, issues, fn child, acc ->
        check_circular_refs_recursive(child, new_visited, acc)
      end)
    end
  end

  defp check_required_attributes(%Node{} = ast, issues) do
    {_, new_issues} =
      Walker.depth_first_reduce(ast, issues, fn node, acc ->
        node_issues = validate_node_attributes(node)
        {acc ++ node_issues, :cont}
      end)

    new_issues
  end

  defp validate_node_attributes(%Node{type: :heading, attributes: attrs}) do
    if Map.has_key?(attrs, :level) and attrs.level in 1..6 do
      []
    else
      [{:missing_required_attribute, :heading, :level}]
    end
  end

  defp validate_node_attributes(%Node{type: :link, attributes: attrs}) do
    if Map.has_key?(attrs, :url) do
      []
    else
      [{:missing_required_attribute, :link, :url}]
    end
  end

  defp validate_node_attributes(_node), do: []

  defp repair_parent_ids(%Node{} = ast) do
    map_tree(ast, fn node ->
      children_with_correct_parent =
        Enum.map(node.children, &%{&1 | parent_id: node.id})

      %{node | children: children_with_correct_parent}
    end)
  end

  defp repair_missing_ids(%Node{} = ast) do
    map_tree(ast, fn
      %{id: nil} = node -> %{node | id: generate_id()}
      %{id: ""} = node -> %{node | id: generate_id()}
      node -> node
    end)
  end

  defp repair_invalid_attributes(%Node{} = ast) do
    map_tree(ast, fn node ->
      case node.type do
        :heading ->
          level = Map.get(node.attributes, :level, 1)
          normalized_level = max(1, min(6, level))
          put_in(node.attributes.level, normalized_level)

        _ ->
          node
      end
    end)
  end

  defp batch_transform_node(%Node{} = node, transformations) do
    # Apply all transformations to this node
    transformed_node = apply_transformations_to_node(node, transformations)

    # Recursively apply to children
    transformed_children =
      transformed_node.children
      |> Enum.map(&batch_transform_node(&1, transformations))
      |> Enum.map(&%{&1 | parent_id: transformed_node.id})

    %{transformed_node | children: transformed_children}
  end

  defp apply_transformations_to_node(node, transformations) do
    Enum.reduce(transformations, node, fn transform, current_node ->
      case transform do
        {:map, transform_fun} ->
          transform_fun.(current_node)

        {:where, criteria, transform_fun} ->
          predicate = build_predicate(criteria)

          if predicate.(current_node) do
            transform_fun.(current_node)
          else
            current_node
          end

        {:remove, criteria} ->
          predicate = build_predicate(criteria)

          if predicate.(current_node) do
            # Mark for deletion
            nil
          else
            current_node
          end

        _ ->
          current_node
      end
    end)
  end

  ## Utility Functions

  defp build_predicate(criteria) when is_function(criteria, 1), do: criteria

  defp build_predicate(criteria) when is_list(criteria) do
    fn node ->
      Enum.all?(criteria, fn {key, expected_value} ->
        case key do
          :type -> node.type == expected_value
          :id -> node.id == expected_value
          attr_key -> Map.get(node.attributes, attr_key) == expected_value
        end
      end)
    end
  end

  defp has_children?(%Node{children: []}), do: false
  defp has_children?(%Node{children: _children}), do: true

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  defp extract_text_content(%Node{type: :text, content: content}) when is_binary(content) do
    content
  end

  defp extract_text_content(%Node{children: children}) do
    children
    |> Enum.map(&extract_text_content/1)
    |> Enum.join("")
  end

  defp extract_text_content(_), do: ""

  defp slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
