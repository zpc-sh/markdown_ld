defmodule MarkdownLd.AST.Node do
  @moduledoc """
  Core AST node structure for Markdown documents.

  Optimized for:
  - Memory efficiency when storing large codebases
  - Fast tree traversal operations
  - Indexing compatibility (B+ tree, trigram, graph, semantic)
  - Serialization for persistent storage
  """

  @type node_id :: binary()
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
          | :section
          | :thematic_break
          | :footnote_definition
          | :footnote_reference

  @type position :: {line :: non_neg_integer(), column :: non_neg_integer()}
  @type range :: {start :: position(), stop :: position()}

  @enforce_keys [:id, :type]
  defstruct [
    # Core identification
    # Unique node identifier
    :id,
    # Node type atom
    :type,

    # Content and structure
    # Primary content (text, url, etc.)
    content: nil,
    # Type-specific attributes
    attributes: %{},
    # Child nodes
    children: [],
    # Parent node ID for upward traversal
    parent_id: nil,

    # Position tracking (for IDE features, error reporting)
    # Source position range
    position: nil,

    # Metadata (extensible for indexing)
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: node_id(),
          type: node_type(),
          content: any(),
          attributes: map(),
          children: [t()],
          parent_id: node_id() | nil,
          position: range() | nil,
          metadata: map()
        }

  # Factory functions for different node types

  @doc """
  Create a document root node.
  """
  @spec document(binary(), keyword()) :: t()
  def document(content, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :document,
      content: content,
      attributes: %{
        title: extract_title(content),
        frontmatter: parse_frontmatter(content),
        word_count: count_words(content),
        file_path: Keyword.get(opts, :file_path),
        language: detect_language(opts)
      },
      metadata: %{
        parse_time_us: Keyword.get(opts, :parse_time_us, 0),
        size_bytes: byte_size(content),
        checksum: checksum(content),
        created_at: DateTime.utc_now(),
        indexes: %{}
      }
    }
  end

  @doc """
  Create a heading node.
  """
  @spec heading(binary(), pos_integer(), keyword()) :: t()
  def heading(text, level, opts \\ []) when level in 1..6 do
    %__MODULE__{
      id: generate_id(),
      type: :heading,
      content: text,
      attributes: %{
        level: level,
        anchor: slugify(text),
        setext: Keyword.get(opts, :setext, false)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a paragraph node.
  """
  @spec paragraph(keyword()) :: t()
  def paragraph(opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :paragraph,
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a code block node.
  """
  @spec code_block(binary(), binary() | nil, keyword()) :: t()
  def code_block(code, language \\ nil, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :code_block,
      content: code,
      attributes: %{
        language: language,
        info_string: Keyword.get(opts, :info_string),
        is_fenced: Keyword.get(opts, :fenced, true),
        fence_char: Keyword.get(opts, :fence_char, "`"),
        fence_length: Keyword.get(opts, :fence_length, 3)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a list node.
  """
  @spec list(atom(), keyword()) :: t()
  def list(list_type, opts \\ []) when list_type in [:ordered, :unordered] do
    %__MODULE__{
      id: generate_id(),
      type: :list,
      attributes: %{
        list_type: list_type,
        start: Keyword.get(opts, :start, 1),
        delimiter: Keyword.get(opts, :delimiter),
        marker: Keyword.get(opts, :marker),
        tight: Keyword.get(opts, :tight, true)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a list item node.
  """
  @spec list_item(keyword()) :: t()
  def list_item(opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :list_item,
      attributes: %{
        marker: Keyword.get(opts, :marker),
        padding: Keyword.get(opts, :padding, 0),
        tight: Keyword.get(opts, :tight, true)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a task item node (GitHub-style task lists).
  """
  @spec task_item(boolean(), keyword()) :: t()
  def task_item(checked?, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :task_item,
      attributes: %{
        checked: checked?,
        marker: Keyword.get(opts, :marker, "- ")
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a link node.
  """
  @spec link(binary(), binary(), binary() | nil, keyword()) :: t()
  def link(url, text, title \\ nil, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :link,
      content: text,
      attributes: %{
        url: url,
        title: title,
        reference: Keyword.get(opts, :reference),
        autolink: Keyword.get(opts, :autolink, false)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create an image node.
  """
  @spec image(binary(), binary(), binary() | nil, keyword()) :: t()
  def image(url, alt_text, title \\ nil, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :image,
      content: alt_text,
      attributes: %{
        url: url,
        title: title,
        reference: Keyword.get(opts, :reference)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a text node.
  """
  @spec text(binary(), keyword()) :: t()
  def text(content, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :text,
      content: content,
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create an emphasis node (italic).
  """
  @spec emphasis(keyword()) :: t()
  def emphasis(opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :emphasis,
      attributes: %{
        marker: Keyword.get(opts, :marker, "*")
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a strong node (bold).
  """
  @spec strong(keyword()) :: t()
  def strong(opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :strong,
      attributes: %{
        marker: Keyword.get(opts, :marker, "**")
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a code span node (inline code).
  """
  @spec code_span(binary(), keyword()) :: t()
  def code_span(code, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :code_span,
      content: code,
      attributes: %{
        backtick_count: count_backticks(code)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a table node.
  """
  @spec table([atom()], keyword()) :: t()
  def table(alignments, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :table,
      attributes: %{
        alignments: alignments,
        column_count: length(alignments)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a table row node.
  """
  @spec table_row(boolean(), keyword()) :: t()
  def table_row(is_header?, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :table_row,
      attributes: %{
        header: is_header?
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a table cell node.
  """
  @spec table_cell(atom(), keyword()) :: t()
  def table_cell(alignment, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :table_cell,
      attributes: %{
        alignment: alignment,
        header: Keyword.get(opts, :header, false)
      },
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  @doc """
  Create a blockquote node.
  """
  @spec blockquote(keyword()) :: t()
  def blockquote(opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: :blockquote,
      position: Keyword.get(opts, :position),
      parent_id: Keyword.get(opts, :parent_id)
    }
  end

  # Tree manipulation helpers

  @doc """
  Add a child node to this node.
  """
  @spec add_child(t(), t()) :: t()
  def add_child(%__MODULE__{} = parent, %__MODULE__{} = child) do
    child_with_parent = %{child | parent_id: parent.id}
    %{parent | children: parent.children ++ [child_with_parent]}
  end

  @doc """
  Add multiple children to this node.
  """
  @spec add_children(t(), [t()]) :: t()
  def add_children(%__MODULE__{} = parent, children) when is_list(children) do
    children_with_parent = Enum.map(children, &%{&1 | parent_id: parent.id})
    %{parent | children: parent.children ++ children_with_parent}
  end

  @doc """
  Replace all children of this node.
  """
  @spec set_children(t(), [t()]) :: t()
  def set_children(%__MODULE__{} = parent, children) when is_list(children) do
    children_with_parent = Enum.map(children, &%{&1 | parent_id: parent.id})
    %{parent | children: children_with_parent}
  end

  @doc """
  Check if this node is a leaf (has no children).
  """
  @spec leaf?(t()) :: boolean()
  def leaf?(%__MODULE__{children: []}), do: true
  def leaf?(%__MODULE__{}), do: false

  @doc """
  Check if this node is a container (can have children).
  """
  @spec container?(t()) :: boolean()
  def container?(%__MODULE__{type: type}) do
    type in [
      :document,
      :heading,
      :paragraph,
      :list,
      :list_item,
      :task_item,
      :blockquote,
      :table,
      :table_row,
      :table_cell,
      :emphasis,
      :strong
    ]
  end

  @doc """
  Check if this node is a block-level element.
  """
  @spec block?(t()) :: boolean()
  def block?(%__MODULE__{type: type}) do
    type in [
      :document,
      :heading,
      :paragraph,
      :list,
      :list_item,
      :code_block,
      :blockquote,
      :table,
      :table_row,
      :thematic_break,
      :task_item
    ]
  end

  @doc """
  Check if this node is an inline element.
  """
  @spec inline?(t()) :: boolean()
  def inline?(%__MODULE__{type: type}) do
    type in [
      :text,
      :link,
      :image,
      :emphasis,
      :strong,
      :code_span,
      :break,
      :strikethrough,
      :footnote_reference
    ]
  end

  # Indexing support

  @doc """
  Extract indexable content from this node.

  Returns a map with different content types for different indexes:
  - :text - Plain text content for full-text search
  - :path - Path information for B+ tree indexing
  - :links - Link relationships for graph indexing
  - :metadata - Structured metadata
  """
  @spec indexable_content(t()) :: map()
  def indexable_content(%__MODULE__{} = node) do
    %{
      text: extract_text(node),
      path: extract_path_info(node),
      links: extract_link_info(node),
      metadata: extract_metadata(node),
      structure: extract_structure_info(node)
    }
  end

  # Private helpers

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content) do
      [_, title] -> String.trim(title)
      nil -> nil
    end
  end

  defp parse_frontmatter(content) do
    case Regex.run(~r/^---\n(.*?)\n---/s, content) do
      [_, yaml] ->
        try do
          YamlElixir.read_from_string!(yaml)
        rescue
          _ -> %{}
        end

      nil ->
        %{}
    end
  end

  defp count_words(content) do
    content
    # Remove code blocks
    |> String.replace(~r/```.*?```/s, "")
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> length()
  end

  defp detect_language(opts) do
    case Keyword.get(opts, :file_path) do
      nil -> nil
      path -> Path.extname(path) |> String.trim_leading(".")
    end
  end

  defp checksum(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  defp count_backticks(code) do
    code
    |> String.graphemes()
    |> Enum.take_while(&(&1 == "`"))
    |> length()
    |> max(1)
  end

  defp extract_text(%__MODULE__{type: :text, content: content}) when is_binary(content) do
    content
  end

  defp extract_text(%__MODULE__{children: children}) do
    children
    |> Enum.map(&extract_text/1)
    |> Enum.join("")
  end

  defp extract_text(_), do: ""

  defp extract_path_info(%__MODULE__{attributes: %{file_path: path}}) when is_binary(path) do
    %{
      file_path: path,
      directory: Path.dirname(path),
      filename: Path.basename(path),
      extension: Path.extname(path)
    }
  end

  defp extract_path_info(_), do: %{}

  defp extract_link_info(%__MODULE__{type: :link, attributes: %{url: url}}) do
    %{outbound_links: [url]}
  end

  defp extract_link_info(%__MODULE__{children: children}) do
    links =
      children
      |> Enum.flat_map(&extract_link_info/1)
      |> Enum.flat_map(fn
        %{outbound_links: links} -> links
        _ -> []
      end)

    if links == [] do
      %{}
    else
      %{outbound_links: links}
    end
  end

  defp extract_link_info(_), do: %{}

  defp extract_metadata(%__MODULE__{attributes: attrs, metadata: meta}) do
    Map.merge(attrs, meta)
  end

  defp extract_structure_info(%__MODULE__{type: type, children: children}) do
    %{
      node_type: type,
      child_count: length(children),
      child_types: Enum.map(children, & &1.type) |> Enum.frequencies()
    }
  end
end
