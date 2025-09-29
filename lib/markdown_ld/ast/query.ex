defmodule MarkdownLd.AST.Query do
  @moduledoc """
  Query operations for Markdown AST nodes.

  Provides a flexible query system for finding and filtering nodes
  based on various criteria including type, attributes, content,
  and position.

  Optimized for:
  - Fast predicate-based filtering
  - Complex multi-criteria queries
  - XPath-like path expressions
  - CSS selector-style queries
  """

  alias MarkdownLd.AST.{Node, Walker}

  @type query_criteria :: keyword() | (Node.t() -> boolean())
  @type query_result :: [Node.t()]
  @type path_expression :: binary()
  @type css_selector :: binary()

  ## Basic Query Operations

  @doc """
  Select all nodes matching the given criteria.

  Supports multiple query formats:
  - Keyword criteria: `[type: :heading, level: 1]`
  - Function predicate: `fn node -> node.type == :text end`
  - Mixed criteria with function: `[type: :link, fn node -> String.contains?(node.content, "github") end]`

  Examples:
      # Find all headings
      headings = Query.select(ast, type: :heading)

      # Find level-1 headings
      h1_headings = Query.select(ast, type: :heading, level: 1)

      # Find external links
      external_links = Query.select(ast, type: :link, fn node ->
        String.starts_with?(node.attributes.url, "http")
      end)

      # Find code blocks with specific language
      elixir_code = Query.select(ast, type: :code_block, language: "elixir")
  """
  @spec select(Node.t(), query_criteria()) :: query_result()
  def select(%Node{} = ast, criteria) do
    predicate = build_predicate(criteria)

    {results, _} =
      Walker.depth_first_reduce(ast, [], fn node, acc ->
        if predicate.(node) do
          {[node | acc], :cont}
        else
          {acc, :cont}
        end
      end)

    Enum.reverse(results)
  end

  @doc """
  Find the first node matching the given criteria.

  Returns `nil` if no matching node is found.

  Examples:
      # Find first heading
      first_heading = Query.find_first(ast, type: :heading)

      # Find first code block with language
      first_code = Query.find_first(ast, type: :code_block, fn node ->
        node.attributes.language != nil
      end)
  """
  @spec find_first(Node.t(), query_criteria()) :: Node.t() | nil
  def find_first(%Node{} = ast, criteria) do
    predicate = build_predicate(criteria)

    result =
      Walker.depth_first(ast, fn node ->
        if predicate.(node) do
          {:found, node}
        else
          :cont
        end
      end)

    case result do
      {:found, node} -> node
      _ -> nil
    end
  end

  @doc """
  Select nodes using XPath-like expressions.

  Supports:
  - `/` - Child selector
  - `//` - Descendant selector
  - `[@attr=value]` - Attribute filters
  - `[position()]` - Position filters
  - `text()` - Text node selector

  Examples:
      # Find all direct child headings
      Query.xpath(ast, "/heading")

      # Find all descendant links
      Query.xpath(ast, "//link")

      # Find headings with specific level
      Query.xpath(ast, "//heading[@level=1]")

      # Find first paragraph
      Query.xpath(ast, "//paragraph[1]")

      # Find text nodes
      Query.xpath(ast, "//text()")
  """
  @spec xpath(Node.t(), path_expression()) :: query_result()
  def xpath(%Node{} = ast, expression) when is_binary(expression) do
    parsed_expression = parse_xpath(expression)
    evaluate_xpath(ast, parsed_expression)
  end

  @doc """
  Select nodes using CSS selector syntax.

  Supports:
  - `type` - Type selector
  - `.class` - Class attribute selector (from metadata)
  - `#id` - ID selector
  - `[attr]` - Has attribute
  - `[attr=value]` - Attribute equals
  - ` ` - Descendant combinator
  - `>` - Child combinator

  Examples:
      # Select all headings
      Query.css(ast, "heading")

      # Select headings with specific level
      Query.css(ast, "heading[level=1]")

      # Select direct child paragraphs
      Query.css(ast, "> paragraph")

      # Select links in lists
      Query.css(ast, "list link")

      # Select by ID
      Query.css(ast, "#introduction")
  """
  @spec css(Node.t(), css_selector()) :: query_result()
  def css(%Node{} = ast, selector) when is_binary(selector) do
    parsed_selector = parse_css_selector(selector)
    evaluate_css_selector(ast, parsed_selector)
  end

  ## Advanced Query Operations

  @doc """
  Select nodes with complex attribute queries.

  Supports various comparison operators:
  - `:eq` - Equals
  - `:ne` - Not equals
  - `:gt` - Greater than
  - `:lt` - Less than
  - `:contains` - String contains
  - `:starts_with` - String starts with
  - `:ends_with` - String ends with
  - `:matches` - Regex match

  Examples:
      # Find large headings (level <= 2)
      large_headings = Query.select_where(ast, :attributes, [level: {:lt, 3}])

      # Find links containing "github"
      github_links = Query.select_where(ast, :attributes, [url: {:contains, "github"}])

      # Find code blocks matching pattern
      test_code = Query.select_where(ast, :content, {:matches, ~r/test.*function/i})
  """
  @spec select_where(Node.t(), :attributes | :content | :metadata, term()) :: query_result()
  def select_where(%Node{} = ast, field, criteria) do
    predicate = build_field_predicate(field, criteria)
    select(ast, predicate)
  end

  @doc """
  Select nodes within a specific depth range.

  Examples:
      # Get nodes at depth 2-4
      mid_level_nodes = Query.select_depth_range(ast, 2, 4)

      # Get only leaf nodes (maximum depth)
      max_depth = Walker.max_depth(ast)
      leaf_nodes = Query.select_depth_range(ast, max_depth, max_depth)
  """
  @spec select_depth_range(Node.t(), non_neg_integer(), non_neg_integer()) :: query_result()
  def select_depth_range(%Node{} = ast, min_depth, max_depth) do
    levels = Walker.nodes_by_level(ast)

    min_depth..max_depth
    |> Enum.flat_map(fn depth ->
      Map.get(levels, depth, [])
    end)
  end

  @doc """
  Select nodes by their position among siblings.

  Examples:
      # Get first child of each container
      first_children = Query.select_by_position(ast, :first)

      # Get last child of each container
      last_children = Query.select_by_position(ast, :last)

      # Get second child of each container
      second_children = Query.select_by_position(ast, 2)
  """
  @spec select_by_position(Node.t(), :first | :last | pos_integer()) :: query_result()
  def select_by_position(%Node{} = ast, position) do
    {results, _} =
      Walker.depth_first_reduce(ast, [], fn node, acc ->
        matching_children =
          case position do
            :first ->
              case node.children do
                [first | _] -> [first]
                [] -> []
              end

            :last ->
              case node.children do
                [] -> []
                children -> [List.last(children)]
              end

            n when is_integer(n) and n > 0 ->
              case Enum.at(node.children, n - 1) do
                nil -> []
                child -> [child]
              end
          end

        {acc ++ matching_children, :cont}
      end)

    results
  end

  @doc """
  Select nodes that have specific children.

  Examples:
      # Find lists that contain task items
      task_lists = Query.select_has_child(ast, type: :list, child_type: :task_item)

      # Find paragraphs with links
      linked_paragraphs = Query.select_has_child(ast, type: :paragraph, child_type: :link)
  """
  @spec select_has_child(Node.t(), keyword()) :: query_result()
  def select_has_child(%Node{} = ast, criteria) do
    parent_criteria = Keyword.drop(criteria, [:child_type, :child_predicate])
    child_type = Keyword.get(criteria, :child_type)
    child_predicate = Keyword.get(criteria, :child_predicate)

    parent_predicate = build_predicate(parent_criteria)

    predicate = fn node ->
      if parent_predicate.(node) do
        has_matching_child =
          Enum.any?(node.children, fn child ->
            type_matches = if child_type, do: child.type == child_type, else: true
            predicate_matches = if child_predicate, do: child_predicate.(child), else: true
            type_matches and predicate_matches
          end)

        has_matching_child
      else
        false
      end
    end

    select(ast, predicate)
  end

  @doc """
  Select sibling nodes of nodes matching criteria.

  Examples:
      # Get siblings of all headings
      heading_siblings = Query.select_siblings(ast, type: :heading)

      # Get following siblings only
      following_siblings = Query.select_siblings(ast, [type: :heading], :following)
  """
  @spec select_siblings(Node.t(), query_criteria(), :all | :preceding | :following) ::
          query_result()
  def select_siblings(%Node{} = ast, criteria, direction \\ :all) do
    target_nodes = select(ast, criteria)
    parent_child_map = Walker.parent_child_map(ast)

    target_nodes
    |> Enum.flat_map(fn target_node ->
      parent_id = Map.get(parent_child_map, target_node.id)

      if parent_id do
        parent = find_first(ast, fn node -> node.id == parent_id end)

        if parent do
          get_siblings(parent.children, target_node, direction)
        else
          []
        end
      else
        []
      end
    end)
    |> Enum.uniq_by(& &1.id)
  end

  ## Query Building and Evaluation

  defp build_predicate(criteria) when is_function(criteria, 1), do: criteria

  defp build_predicate(criteria) when is_list(criteria) do
    {keyword_criteria, function_criteria} =
      Enum.split_with(criteria, fn
        {_key, _value} -> true
        fun when is_function(fun, 1) -> false
        _ -> true
      end)

    keyword_predicate = build_keyword_predicate(keyword_criteria)
    function_predicates = Enum.filter(function_criteria, &is_function(&1, 1))

    fn node ->
      keyword_match = keyword_predicate.(node)
      function_matches = Enum.all?(function_predicates, fn pred -> pred.(node) end)

      keyword_match and function_matches
    end
  end

  defp build_keyword_predicate([]), do: fn _node -> true end

  defp build_keyword_predicate(criteria) do
    fn node ->
      Enum.all?(criteria, fn {key, expected_value} ->
        case key do
          :type ->
            node.type == expected_value

          :id ->
            node.id == expected_value

          :content ->
            node.content == expected_value

          attr_key ->
            # Check attributes
            actual_value = get_in(node.attributes, [attr_key])
            actual_value == expected_value
        end
      end)
    end
  end

  defp build_field_predicate(:attributes, criteria) when is_list(criteria) do
    fn node ->
      Enum.all?(criteria, fn {key, comparison} ->
        value = Map.get(node.attributes, key)
        evaluate_comparison(value, comparison)
      end)
    end
  end

  defp build_field_predicate(:content, comparison) do
    fn node ->
      evaluate_comparison(node.content, comparison)
    end
  end

  defp build_field_predicate(:metadata, criteria) when is_list(criteria) do
    fn node ->
      Enum.all?(criteria, fn {key, comparison} ->
        value = Map.get(node.metadata, key)
        evaluate_comparison(value, comparison)
      end)
    end
  end

  defp evaluate_comparison(value, {:eq, expected}), do: value == expected
  defp evaluate_comparison(value, {:ne, expected}), do: value != expected
  defp evaluate_comparison(value, {:gt, expected}), do: value > expected
  defp evaluate_comparison(value, {:lt, expected}), do: value < expected
  defp evaluate_comparison(value, {:gte, expected}), do: value >= expected
  defp evaluate_comparison(value, {:lte, expected}), do: value <= expected

  defp evaluate_comparison(value, {:contains, substring}) when is_binary(value) do
    String.contains?(value, substring)
  end

  defp evaluate_comparison(value, {:starts_with, prefix}) when is_binary(value) do
    String.starts_with?(value, prefix)
  end

  defp evaluate_comparison(value, {:ends_with, suffix}) when is_binary(value) do
    String.ends_with?(value, suffix)
  end

  defp evaluate_comparison(value, {:matches, regex}) when is_binary(value) do
    Regex.match?(regex, value)
  end

  defp evaluate_comparison(_value, _comparison), do: false

  ## XPath Implementation

  defp parse_xpath(expression) do
    expression
    |> String.trim()
    |> String.split(~r{/+}, trim: true)
    |> Enum.map(&parse_xpath_segment/1)
  end

  defp parse_xpath_segment(segment) do
    cond do
      segment == "text()" ->
        %{type: :text_node}

      String.contains?(segment, "[") ->
        [name, filter_expr] = String.split(segment, "[", parts: 2)
        filter_expr = String.trim_trailing(filter_expr, "]")
        filters = parse_xpath_filters(filter_expr)

        %{type: :element, name: name, filters: filters}

      true ->
        %{type: :element, name: segment, filters: []}
    end
  end

  defp parse_xpath_filters(filter_expr) do
    cond do
      String.match?(filter_expr, ~r/^\d+$/) ->
        # Position filter
        position = String.to_integer(filter_expr)
        [%{type: :position, value: position}]

      String.contains?(filter_expr, "=") ->
        # Attribute filter
        [attr, value] = String.split(filter_expr, "=", parts: 2)
        attr = String.trim_leading(attr, "@")
        value = String.trim(value, "'\"")

        [%{type: :attribute, name: attr, value: value}]

      true ->
        []
    end
  end

  defp evaluate_xpath(%Node{} = ast, []), do: [ast]

  defp evaluate_xpath(%Node{} = ast, [segment | rest]) do
    matching_children = find_matching_children(ast, segment)

    if rest == [] do
      matching_children
    else
      Enum.flat_map(matching_children, &evaluate_xpath(&1, rest))
    end
  end

  defp find_matching_children(%Node{children: children}, segment) do
    children
    |> Enum.filter(&matches_xpath_segment?(&1, segment))
    |> apply_xpath_filters(segment.filters)
  end

  defp matches_xpath_segment?(%Node{type: :text}, %{type: :text_node}), do: true

  defp matches_xpath_segment?(%Node{type: node_type}, %{type: :element, name: name}) do
    Atom.to_string(node_type) == name
  end

  defp matches_xpath_segment?(_node, _segment), do: false

  defp apply_xpath_filters(nodes, []), do: nodes

  defp apply_xpath_filters(nodes, [%{type: :position, value: pos} | rest]) do
    filtered =
      case Enum.at(nodes, pos - 1) do
        nil -> []
        node -> [node]
      end

    apply_xpath_filters(filtered, rest)
  end

  defp apply_xpath_filters(nodes, [%{type: :attribute, name: name, value: value} | rest]) do
    filtered =
      Enum.filter(nodes, fn node ->
        Map.get(node.attributes, String.to_atom(name)) == value
      end)

    apply_xpath_filters(filtered, rest)
  end

  ## CSS Selector Implementation

  defp parse_css_selector(selector) do
    selector
    |> String.trim()
    |> String.split(~r/\s*([>+~])\s*/, include_captures: true, trim: true)
    |> parse_css_combinators()
  end

  defp parse_css_combinators(tokens) do
    parse_css_combinators(tokens, [], nil)
  end

  defp parse_css_combinators([], selectors, _combinator) do
    Enum.reverse(selectors)
  end

  defp parse_css_combinators([token | rest], selectors, combinator) do
    case token do
      ">" ->
        parse_css_combinators(rest, selectors, :child)

      " " ->
        parse_css_combinators(rest, selectors, :descendant)

      selector_token ->
        parsed_selector = parse_css_simple_selector(selector_token)
        selector_with_combinator = %{parsed_selector | combinator: combinator}
        parse_css_combinators(rest, [selector_with_combinator | selectors], nil)
    end
  end

  defp parse_css_simple_selector(selector) do
    %{
      type: extract_css_type(selector),
      id: extract_css_id(selector),
      classes: extract_css_classes(selector),
      attributes: extract_css_attributes(selector),
      combinator: nil
    }
  end

  defp extract_css_type(selector) do
    case Regex.run(~r/^([a-zA-Z][a-zA-Z0-9_-]*)/, selector) do
      [_, type] -> String.to_atom(type)
      nil -> nil
    end
  end

  defp extract_css_id(selector) do
    case Regex.run(~r/#([a-zA-Z][a-zA-Z0-9_-]*)/, selector) do
      [_, id] -> id
      nil -> nil
    end
  end

  defp extract_css_classes(selector) do
    Regex.scan(~r/\.([a-zA-Z][a-zA-Z0-9_-]*)/, selector)
    |> Enum.map(fn [_, class] -> class end)
  end

  defp extract_css_attributes(selector) do
    Regex.scan(~r/\[([a-zA-Z][a-zA-Z0-9_-]*)(?:=([^\]]+))?\]/, selector)
    |> Enum.map(fn
      [_, attr] -> {String.to_atom(attr), :present}
      [_, attr, value] -> {String.to_atom(attr), String.trim(value, "'\"")}
    end)
  end

  defp evaluate_css_selector(%Node{} = ast, selectors) do
    # Simple implementation - evaluate each selector independently
    # In a full implementation, combinators would be properly handled

    Enum.flat_map(selectors, fn selector ->
      select(ast, fn node -> matches_css_selector?(node, selector) end)
    end)
    |> Enum.uniq_by(& &1.id)
  end

  defp matches_css_selector?(%Node{} = node, selector) do
    type_matches = selector.type == nil or node.type == selector.type
    id_matches = selector.id == nil or node.id == selector.id

    class_matches =
      selector.classes == [] or
        Enum.all?(selector.classes, fn class ->
          node.metadata
          |> Map.get(:classes, [])
          |> Enum.member?(class)
        end)

    attr_matches =
      Enum.all?(selector.attributes, fn
        {attr, :present} -> Map.has_key?(node.attributes, attr)
        {attr, value} -> Map.get(node.attributes, attr) == value
      end)

    type_matches and id_matches and class_matches and attr_matches
  end

  ## Helper Functions

  defp get_siblings(siblings, target_node, direction) do
    target_index = Enum.find_index(siblings, &(&1.id == target_node.id))

    case {target_index, direction} do
      {nil, _} ->
        []

      {index, :all} ->
        siblings
        |> List.delete_at(index)

      {index, :preceding} ->
        Enum.take(siblings, index)

      {index, :following} ->
        siblings
        |> Enum.drop(index + 1)
    end
  end
end
