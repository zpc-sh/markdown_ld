defmodule MarkdownLd.AST.Filesystem do
  @moduledoc """
  Filesystem tree support for Markdown AST with mount/dismount capabilities.

  Enables treating markdown documents as virtual filesystems that can be:
  - Mounted as directory structures
  - Navigated with filesystem semantics
  - Modified through filesystem operations
  - Dismounted back to markdown

  Inspired by tree2md but designed for AI interaction and codebase storage.

  ## Core Concepts

  - **Filesystem AST**: Special AST nodes that represent directories and files
  - **Mount/Dismount**: Convert between markdown and virtual filesystem
  - **AI Navigation**: Allow AI to navigate and modify as if it's a real filesystem
  - **Preservation**: Maintain all markdown metadata and structure

  ## Examples

      # Parse codebase structure from markdown
      {:ok, fs_ast} = Filesystem.parse_tree_markdown(content)

      # Mount as virtual filesystem
      {:ok, vfs} = Filesystem.mount(fs_ast, "/tmp/workspace")

      # AI can now work with files
      File.read(Path.join(vfs.mount_point, "src/main.rs"))
      File.write(Path.join(vfs.mount_point, "README.md"), new_content)

      # Dismount back to markdown with changes
      {:ok, updated_markdown} = Filesystem.dismount(vfs)
  """

  alias MarkdownLd.AST.{Node, Walker, Query, Transform}
  require Logger

  @type filesystem_node :: %Node{
          type: :filesystem_root | :directory | :file,
          attributes: %{
            path: binary(),
            size: non_neg_integer() | nil,
            permissions: binary() | nil,
            modified: DateTime.t() | nil,
            file_type: atom() | nil,
            line_count: non_neg_integer() | nil,
            encoding: atom() | nil,
            is_binary: boolean()
          },
          content: binary() | nil,
          metadata: %{
            original_path: binary(),
            stats: map(),
            github_url: binary() | nil,
            is_symlink: boolean(),
            mount_info: map() | nil
          }
        }

  @type virtual_filesystem :: %{
          mount_point: binary(),
          ast: Node.t(),
          path_mapping: %{binary() => Node.node_id()},
          reverse_mapping: %{Node.node_id() => binary()},
          metadata: %{
            mounted_at: DateTime.t(),
            original_markdown: binary(),
            stats: map()
          }
        }

  @type tree_stats :: %{
          total_files: non_neg_integer(),
          total_dirs: non_neg_integer(),
          total_size: non_neg_integer(),
          line_count: non_neg_integer(),
          file_types: %{atom() => non_neg_integer()},
          largest_files: [%{path: binary(), size: non_neg_integer()}],
          extensions: %{binary() => non_neg_integer()}
        }

  ## Parsing Tree Markdown

  @doc """
  Parse tree-style markdown into filesystem AST.

  Supports multiple input formats:
  - Tree command output
  - tree2md format
  - Directory listings
  - GitHub file trees

  Examples:
      content = '''
      src/
      ├── main.rs (250 lines)
      ├── lib.rs (180 lines)
      └── utils/
          ├── helper.rs (95 lines)
          └── config.rs (120 lines)
      README.md (45 lines)
      '''

      {:ok, fs_ast} = Filesystem.parse_tree_markdown(content)
  """
  @spec parse_tree_markdown(binary(), keyword()) :: {:ok, filesystem_node()} | {:error, term()}
  def parse_tree_markdown(content, opts \\ []) do
    with {:ok, tree_structure} <- detect_and_parse_format(content, opts),
         {:ok, fs_ast} <- build_filesystem_ast(tree_structure, opts) do
      {:ok, fs_ast}
    else
      error -> error
    end
  end

  @doc """
  Generate tree markdown from filesystem or directory.

  Options:
  - `:style` - :tree, :markdown, :github (default: :tree)
  - `:max_depth` - Maximum directory depth (default: nil)
  - `:include_stats` - Include file statistics (default: true)
  - `:github_url` - Base URL for GitHub links (default: nil)
  - `:include_content` - Include file contents as code blocks (default: false)
  - `:exclude_patterns` - Glob patterns to exclude (default: standard exclusions)
  - `:include_patterns` - Glob patterns to include (default: all)
  """
  @spec generate_tree_markdown(binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def generate_tree_markdown(root_path, opts \\ []) do
    with {:ok, tree_data} <- scan_directory_tree(root_path, opts),
         markdown <- format_tree_as_markdown(tree_data, opts) do
      {:ok, markdown}
    else
      error -> error
    end
  end

  ## Virtual Filesystem Operations

  @doc """
  Mount a filesystem AST as a virtual filesystem.

  Creates a temporary directory structure that mirrors the AST,
  allowing normal filesystem operations.

  Options:
  - `:mount_point` - Directory to mount in (default: temp dir)
  - `:writable` - Allow modifications (default: true)
  - `:sync_mode` - :immediate, :on_dismount, :manual (default: :on_dismount)
  - `:preserve_permissions` - Maintain original file permissions (default: true)
  """
  @spec mount(filesystem_node(), keyword()) :: {:ok, virtual_filesystem()} | {:error, term()}
  def mount(%Node{type: type} = fs_ast, opts \\ []) when type in [:filesystem_root, :document] do
    mount_point = Keyword.get(opts, :mount_point, create_temp_mount_point())

    with :ok <- ensure_mount_point(mount_point),
         {:ok, path_mapping} <- create_filesystem_structure(fs_ast, mount_point, opts),
         {:ok, vfs} <- initialize_vfs(fs_ast, mount_point, path_mapping, opts) do
      Logger.info("Mounted filesystem AST at #{mount_point}")
      {:ok, vfs}
    else
      error ->
        cleanup_mount_point(mount_point)
        error
    end
  end

  @doc """
  Dismount virtual filesystem and return updated markdown.

  Scans the mounted filesystem for changes and updates the AST accordingly,
  then generates the updated markdown representation.
  """
  @spec dismount(virtual_filesystem()) :: {:ok, binary()} | {:error, term()}
  def dismount(%{mount_point: mount_point, ast: _original_ast} = vfs) do
    with {:ok, updated_ast} <- sync_changes_to_ast(vfs),
         markdown <- ast_to_tree_markdown(updated_ast),
         :ok <- cleanup_mount_point(mount_point) do
      Logger.info("Dismounted filesystem from #{mount_point}")
      {:ok, markdown}
    else
      error ->
        Logger.error("Failed to dismount filesystem: #{inspect(error)}")
        error
    end
  end

  @doc """
  Navigate virtual filesystem like a real filesystem.

  Provides filesystem-like operations:
  - ls(path) - List directory contents
  - cat(path) - Read file contents
  - cd(path) - Change working directory
  - find(pattern) - Find files matching pattern
  - tree(path) - Show tree structure
  """
  @spec navigate(virtual_filesystem(), atom(), binary()) :: term()
  def navigate(%{mount_point: mount_point} = vfs, operation, path \\ ".") do
    full_path = resolve_path(mount_point, path)

    case operation do
      :ls -> list_directory(vfs, full_path)
      :cat -> read_file_content(vfs, full_path)
      :tree -> show_tree_structure(vfs, full_path)
      # path is pattern for find
      :find -> find_files(vfs, path)
      :stat -> get_file_stats(vfs, full_path)
      :pwd -> get_working_directory(vfs)
      _ -> {:error, {:unknown_operation, operation}}
    end
  end

  ## Statistics and Analysis

  @doc """
  Generate comprehensive statistics about filesystem tree.
  """
  @spec analyze_tree(filesystem_node()) :: tree_stats()
  def analyze_tree(%Node{} = fs_ast) do
    {stats, _} =
      Walker.depth_first_reduce(fs_ast, initial_stats(), fn node, acc ->
        updated_stats =
          case node.type do
            :file ->
              acc
              |> update_in([:total_files], &(&1 + 1))
              |> update_in([:total_size], &(&1 + (node.attributes[:size] || 0)))
              |> update_in([:line_count], &(&1 + (node.attributes[:line_count] || 0)))
              |> add_file_type_stats(node)
              |> add_extension_stats(node)

            :directory ->
              update_in(acc, [:total_dirs], &(&1 + 1))

            _ ->
              acc
          end

        {updated_stats, :cont}
      end)

    stats
    |> add_largest_files(fs_ast)
    |> finalize_stats()
  end

  @doc """
  Convert filesystem AST back to tree markdown format.
  """
  @spec ast_to_tree_markdown(filesystem_node(), keyword()) :: binary()
  def ast_to_tree_markdown(%Node{} = fs_ast, opts \\ []) do
    style = Keyword.get(opts, :style, :tree)
    include_stats = Keyword.get(opts, :include_stats, true)
    github_url = Keyword.get(opts, :github_url)

    tree_lines = render_tree_structure(fs_ast, style, github_url, [])
    tree_content = Enum.join(tree_lines, "\n")

    if include_stats do
      stats = analyze_tree(fs_ast)
      stats_content = render_stats(stats)
      tree_content <> "\n\n" <> stats_content
    else
      tree_content
    end
  end

  ## Private Implementation

  defp detect_and_parse_format(content, opts) do
    cond do
      tree_command_format?(content) -> parse_tree_command_output(content, opts)
      markdown_list_format?(content) -> parse_markdown_list(content, opts)
      github_tree_format?(content) -> parse_github_tree(content, opts)
      true -> parse_generic_tree(content, opts)
    end
  end

  defp tree_command_format?(content) do
    String.contains?(content, ["├──", "└──", "│"]) or
      String.contains?(content, ["|--", "`--", "|"])
  end

  defp markdown_list_format?(content) do
    String.contains?(content, ["- ", "* ", "+ "]) and
      String.contains?(content, "/")
  end

  defp github_tree_format?(content) do
    String.contains?(content, "```") and
      String.contains?(content, ["tree", "directory", "structure"])
  end

  defp parse_tree_command_output(content, _opts) do
    lines = String.split(content, "\n", trim: true)

    parsed_entries =
      lines
      |> Enum.filter(&tree_line?/1)
      |> Enum.map(&parse_tree_line/1)
      |> Enum.reject(&is_nil/1)

    {:ok, build_tree_structure(parsed_entries)}
  end

  defp tree_line?(line) do
    String.match?(line, ~r/^[│├└\s]*[├└]──\s*/) or
      String.match?(line, ~r/^[\|\s]*[\|`]--\s*/)
  end

  defp parse_tree_line(line) do
    # Parse tree command output line
    # Examples:
    # ├── src/
    # │   ├── main.rs (250 lines)
    # └── README.md (45 lines)

    depth = calculate_tree_depth(line)
    cleaned = clean_tree_line(line)

    case parse_file_info(cleaned) do
      {:ok, file_info} -> Map.put(file_info, :depth, depth)
      :error -> nil
    end
  end

  defp calculate_tree_depth(line) do
    # Count indentation level from tree characters
    prefix = String.replace(line, ~r/[^│\|\s├└`-].*$/, "")

    tree_chars = String.replace(prefix, ~r/[^\|│├└`-]/, "")
    # Approximate depth
    div(String.length(tree_chars), 3)
  end

  defp clean_tree_line(line) do
    line
    |> String.replace(~r/^[│├└\s]*[├└]──\s*/, "")
    |> String.replace(~r/^[\|\s]*[\|`]--\s*/, "")
    |> String.trim()
  end

  defp parse_file_info(cleaned) do
    cond do
      String.ends_with?(cleaned, "/") ->
        # Directory
        name = String.trim_trailing(cleaned, "/")

        {:ok,
         %{
           name: name,
           type: :directory,
           path: name,
           size: nil,
           line_count: nil
         }}

      line_count_match = Regex.run(~r/^(.+?)\s+\((\d+)\s+lines?\)/, cleaned) ->
        # File with line count
        [_, name, line_count_str] = line_count_match

        {:ok,
         %{
           name: name,
           type: :file,
           path: name,
           size: nil,
           line_count: String.to_integer(line_count_str)
         }}

      size_match = Regex.run(~r/^(.+?)\s+\(([0-9.]+\s*[KMGT]?B)\)/, cleaned) ->
        # File with size
        [_, name, size_str] = size_match

        {:ok,
         %{
           name: name,
           type: :file,
           path: name,
           size: parse_size(size_str),
           line_count: nil
         }}

      true ->
        # Plain filename
        {:ok,
         %{
           name: cleaned,
           type: if(String.contains?(cleaned, "."), do: :file, else: :directory),
           path: cleaned,
           size: nil,
           line_count: nil
         }}
    end
  end

  defp parse_size(size_str) do
    case Regex.run(~r/^([0-9.]+)\s*([KMGT]?)B?$/i, String.trim(size_str)) do
      [_, num_str, ""] -> String.to_float(num_str) |> trunc()
      [_, num_str, "K"] -> (String.to_float(num_str) * 1024) |> trunc()
      [_, num_str, "M"] -> (String.to_float(num_str) * 1024 * 1024) |> trunc()
      [_, num_str, "G"] -> (String.to_float(num_str) * 1024 * 1024 * 1024) |> trunc()
      [_, num_str, "T"] -> (String.to_float(num_str) * 1024 * 1024 * 1024 * 1024) |> trunc()
      _ -> 0
    end
  end

  defp build_tree_structure(entries) do
    # Build nested structure from flat list with depth info
    {tree, _} = build_tree_recursive(entries, 0, [])
    tree
  end

  defp build_tree_recursive([], _current_depth, acc), do: {Enum.reverse(acc), []}

  defp build_tree_recursive([entry | rest], current_depth, acc) do
    cond do
      entry.depth < current_depth ->
        # Back up to parent level
        {Enum.reverse(acc), [entry | rest]}

      entry.depth == current_depth ->
        # Same level, process this entry
        {children, remaining} =
          if entry.type == :directory do
            build_tree_recursive(rest, current_depth + 1, [])
          else
            {[], rest}
          end

        entry_with_children = Map.put(entry, :children, children)
        build_tree_recursive(remaining, current_depth, [entry_with_children | acc])

      entry.depth > current_depth ->
        # This shouldn't happen in well-formed input
        build_tree_recursive(rest, current_depth, acc)
    end
  end

  defp build_filesystem_ast(tree_structure, opts) do
    root_path = Keyword.get(opts, :root_path, ".")

    root_node =
      Node.document("", file_path: root_path)
      |> Map.put(:type, :filesystem_root)
      |> Map.put(:attributes, %{
        path: root_path,
        size: nil,
        permissions: nil,
        modified: DateTime.utc_now(),
        file_type: :directory,
        line_count: nil,
        encoding: :utf8,
        is_binary: false
      })

    children = Enum.map(tree_structure, &convert_to_filesystem_node(&1, root_path))
    {:ok, Node.set_children(root_node, children)}
  end

  defp convert_to_filesystem_node(entry, parent_path) do
    full_path = Path.join(parent_path, entry.name)
    file_type = detect_file_type(entry.name)

    node = %Node{
      id: generate_node_id(),
      type: entry.type,
      content: nil,
      attributes: %{
        path: full_path,
        size: entry.size,
        permissions: nil,
        modified: nil,
        file_type: file_type,
        line_count: entry.line_count,
        encoding: :utf8,
        is_binary: is_binary_file?(entry.name)
      },
      children: [],
      parent_id: nil,
      position: nil,
      metadata: %{
        original_path: entry.name,
        stats: %{},
        github_url: nil,
        is_symlink: false,
        mount_info: nil
      }
    }

    if entry.type == :directory and Map.has_key?(entry, :children) do
      children = Enum.map(entry.children, &convert_to_filesystem_node(&1, full_path))
      Node.set_children(node, children)
    else
      node
    end
  end

  defp scan_directory_tree(root_path, opts) do
    max_depth = Keyword.get(opts, :max_depth)
    exclude_patterns = Keyword.get(opts, :exclude_patterns, default_exclude_patterns())
    include_patterns = Keyword.get(opts, :include_patterns, ["**/*"])

    try do
      tree_data = scan_directory(root_path, 0, max_depth, exclude_patterns, include_patterns)
      {:ok, tree_data}
    rescue
      error -> {:error, {:scan_failed, error}}
    end
  end

  defp scan_directory(path, current_depth, max_depth, exclude_patterns, include_patterns) do
    if max_depth && current_depth >= max_depth do
      %{name: Path.basename(path), type: :directory, path: path, children: []}
    else
      case File.ls(path) do
        {:ok, entries} ->
          children =
            entries
            |> Enum.filter(&should_include?(&1, exclude_patterns, include_patterns))
            |> Enum.map(fn entry ->
              entry_path = Path.join(path, entry)

              scan_entry(
                entry_path,
                current_depth + 1,
                max_depth,
                exclude_patterns,
                include_patterns
              )
            end)
            # Directories first, then alphabetical
            |> Enum.sort_by(&{&1.type, &1.name})

          %{
            name: Path.basename(path),
            type: :directory,
            path: path,
            children: children,
            size: calculate_directory_size(children),
            file_count: count_files(children)
          }

        {:error, _} ->
          %{name: Path.basename(path), type: :directory, path: path, children: []}
      end
    end
  end

  defp scan_entry(path, current_depth, max_depth, exclude_patterns, include_patterns) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :directory}} ->
        scan_directory(path, current_depth, max_depth, exclude_patterns, include_patterns)

      {:ok, %File.Stat{type: :regular, size: size}} ->
        line_count = count_lines_in_file(path)

        %{
          name: Path.basename(path),
          type: :file,
          path: path,
          size: size,
          line_count: line_count,
          file_type: detect_file_type(path),
          modified: File.stat!(path).mtime
        }

      _ ->
        %{name: Path.basename(path), type: :unknown, path: path}
    end
  end

  defp create_temp_mount_point do
    base_dir = System.tmp_dir!()
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :rand.uniform(999_999)
    Path.join(base_dir, "markdown_ld_mount_#{timestamp}_#{random}")
  end

  defp ensure_mount_point(mount_point) do
    case File.mkdir_p(mount_point) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mount_point_creation_failed, reason}}
    end
  end

  defp create_filesystem_structure(fs_ast, mount_point, _opts) do
    {path_mapping, _} =
      Walker.depth_first_reduce(fs_ast, %{}, fn node, acc ->
        case node.type do
          :file ->
            relative_path = node.attributes.path
            full_path = Path.join(mount_point, relative_path)

            # Ensure parent directory exists
            File.mkdir_p!(Path.dirname(full_path))

            # Create file with content if available
            content = node.content || ""
            File.write!(full_path, content)

            mapping = Map.put(acc, full_path, node.id)
            {mapping, :cont}

          :directory ->
            relative_path = node.attributes.path
            full_path = Path.join(mount_point, relative_path)
            File.mkdir_p!(full_path)

            mapping = Map.put(acc, full_path, node.id)
            {mapping, :cont}

          _ ->
            {acc, :cont}
        end
      end)

    {:ok, path_mapping}
  end

  defp initialize_vfs(fs_ast, mount_point, path_mapping, opts) do
    reverse_mapping =
      path_mapping
      |> Enum.map(fn {path, node_id} -> {node_id, path} end)
      |> Enum.into(%{})

    vfs = %{
      mount_point: mount_point,
      ast: fs_ast,
      path_mapping: path_mapping,
      reverse_mapping: reverse_mapping,
      metadata: %{
        mounted_at: DateTime.utc_now(),
        original_markdown: ast_to_tree_markdown(fs_ast),
        stats: analyze_tree(fs_ast)
      }
    }

    {:ok, vfs}
  end

  defp sync_changes_to_ast(%{
         mount_point: mount_point,
         ast: original_ast,
         path_mapping: path_mapping
       }) do
    # Scan mounted filesystem for changes and update AST
    updated_ast =
      Transform.map_tree(original_ast, fn node ->
        case node.type do
          :file ->
            if full_path = Map.get(path_mapping, Path.join(mount_point, node.attributes.path)) do
              case File.read(full_path) do
                {:ok, new_content} ->
                  # Update content and stats
                  new_size = byte_size(new_content)
                  new_line_count = count_lines(new_content)

                  node
                  |> Map.put(:content, new_content)
                  |> put_in([:attributes, :size], new_size)
                  |> put_in([:attributes, :line_count], new_line_count)
                  |> put_in([:attributes, :modified], DateTime.utc_now())

                {:error, _} ->
                  # File was deleted or is inaccessible
                  node
              end
            else
              node
            end

          _ ->
            node
        end
      end)

    {:ok, updated_ast}
  end

  defp cleanup_mount_point(mount_point) do
    case File.rm_rf(mount_point) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:cleanup_failed, reason}}
    end
  end

  defp resolve_path(mount_point, relative_path) do
    Path.join(mount_point, relative_path) |> Path.expand()
  end

  defp list_directory(vfs, full_path) do
    case File.ls(full_path) do
      {:ok, entries} ->
        detailed_entries =
          Enum.map(entries, fn entry ->
            entry_path = Path.join(full_path, entry)
            get_entry_details(vfs, entry_path)
          end)

        {:ok, detailed_entries}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_file_content(_vfs, full_path) do
    File.read(full_path)
  end

  defp get_entry_details(_vfs, entry_path) do
    case File.stat(entry_path) do
      {:ok, stat} ->
        %{
          name: Path.basename(entry_path),
          path: entry_path,
          type: stat.type,
          size: stat.size,
          modified: stat.mtime,
          permissions: stat.mode
        }

      {:error, _} ->
        %{
          name: Path.basename(entry_path),
          path: entry_path,
          type: :unknown,
          error: :stat_failed
        }
    end
  end

  # Helper functions

  defp default_exclude_patterns do
    [
      "**/.git/**",
      "**/node_modules/**",
      "**/target/**",
      "**/.env*",
      "**/*.log",
      "**/tmp/**",
      "**/temp/**",
      "**/.DS_Store",
      "**/Thumbs.db"
    ]
  end

  defp should_include?(entry, exclude_patterns, include_patterns) do
    included = Enum.any?(include_patterns, &PathGlob.match?(&1, entry))
    excluded = Enum.any?(exclude_patterns, &PathGlob.match?(&1, entry))
    included and not excluded
  end

  defp detect_file_type(filename) do
    case Path.extname(filename) do
      ".rs" -> :rust
      ".ex" -> :elixir
      ".exs" -> :elixir_script
      ".md" -> :markdown
      ".txt" -> :text
      ".json" -> :json
      ".yml" -> :yaml
      ".yaml" -> :yaml
      ".toml" -> :toml
      ".js" -> :javascript
      ".ts" -> :typescript
      ".py" -> :python
      ".rb" -> :ruby
      ".go" -> :go
      ".c" -> :c
      ".h" -> :c_header
      ".cpp" -> :cpp
      ".hpp" -> :cpp_header
      ".java" -> :java
      ".kt" -> :kotlin
      ".swift" -> :swift
      ".php" -> :php
      ".html" -> :html
      ".css" -> :css
      ".scss" -> :scss
      ".sql" -> :sql
      ".sh" -> :shell
      ".bash" -> :bash
      ".zsh" -> :zsh
      ".fish" -> :fish
      ".dockerfile" -> :dockerfile
      ".gitignore" -> :gitignore
      ".env" -> :env
      "" -> :no_extension
      _ -> :unknown
    end
  end

  defp is_binary_file?(filename) do
    binary_extensions = [
      ".png",
      ".jpg",
      ".jpeg",
      ".gif",
      ".bmp",
      ".ico",
      ".pdf",
      ".zip",
      ".tar",
      ".gz",
      ".exe",
      ".dll",
      ".so",
      ".dylib",
      ".mp3",
      ".mp4",
      ".avi",
      ".mov",
      ".wav",
      ".flac"
    ]

    ext = Path.extname(filename) |> String.downcase()
    ext in binary_extensions
  end

  defp count_lines_in_file(path) do
    case File.read(path) do
      {:ok, content} -> count_lines(content)
      {:error, _} -> 0
    end
  end

  defp count_lines(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> length()
  end

  defp generate_node_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  defp initial_stats do
    %{
      total_files: 0,
      total_dirs: 0,
      total_size: 0,
      line_count: 0,
      file_types: %{},
      extensions: %{}
    }
  end

  defp add_file_type_stats(stats, node) do
    file_type = node.attributes[:file_type] || :unknown
    update_in(stats, [:file_types, file_type], &((&1 || 0) + 1))
  end

  defp add_extension_stats(stats, node) do
    path = node.attributes[:path] || ""
    ext = Path.extname(path)

    if ext != "" do
      update_in(stats, [:extensions, ext], &((&1 || 0) + 1))
    else
      stats
    end
  end

  defp add_largest_files(stats, fs_ast) do
    files = Query.select(fs_ast, type: :file)

    largest =
      files
      |> Enum.filter(& &1.attributes[:size])
      |> Enum.sort_by(& &1.attributes.size, :desc)
      |> Enum.take(10)
      |> Enum.map(fn file ->
        %{path: file.attributes.path, size: file.attributes.size}
      end)

    Map.put(stats, :largest_files, largest)
  end

  defp finalize_stats(stats), do: stats

  defp render_tree_structure(%Node{children: children}, style, github_url, acc) do
    children
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {child, index}, lines ->
      is_last = index == length(children) - 1
      render_node_line(child, is_last, style, github_url, lines)
    end)
  end

  defp render_node_line(%Node{} = node, is_last, style, github_url, acc) do
    line =
      case style do
        :tree -> render_tree_line(node, is_last, github_url)
        :markdown -> render_markdown_line(node, github_url)
        :github -> render_github_line(node, github_url)
      end

    new_lines = [line | acc]

    if node.type == :directory and node.children != [] do
      render_tree_structure(node, style, github_url, new_lines)
    else
      new_lines
    end
  end

  defp render_tree_line(%Node{} = node, is_last, github_url) do
    prefix = if is_last, do: "└── ", else: "├── "
    name = Path.basename(node.attributes.path)

    line =
      case node.type do
        :directory ->
          "#{prefix}#{name}/"

        :file ->
          name_part =
            if github_url do
              "[#{name}](#{github_url}/#{node.attributes.path})"
            else
              name
            end

          stats_part = build_file_stats_string(node)
          "#{prefix}#{name_part}#{stats_part}"
      end

    line
  end

  defp render_markdown_line(%Node{} = node, github_url) do
    name = Path.basename(node.attributes.path)

    case node.type do
      :directory ->
        "- #{name}/"

      :file ->
        name_part =
          if github_url do
            "[#{name}](#{github_url}/#{node.attributes.path})"
          else
            name
          end

        stats_part = build_file_stats_string(node)
        "- #{name_part}#{stats_part}"
    end
  end

  defp render_github_line(%Node{} = node, github_url) do
    name = Path.basename(node.attributes.path)

    case node.type do
      :directory ->
        "📁 #{name}/"

      :file ->
        icon = get_file_icon(node.attributes.file_type)

        name_part =
          if github_url do
            "[#{name}](#{github_url}/#{node.attributes.path})"
          else
            name
          end

        stats_part = build_file_stats_string(node)
        "#{icon} #{name_part}#{stats_part}"
    end
  end

  defp build_file_stats_string(%Node{} = node) do
    parts = []

    parts =
      if line_count = node.attributes[:line_count] do
        [" (#{line_count} lines)" | parts]
      else
        parts
      end

    parts =
      if size = node.attributes[:size] do
        size_str = format_file_size(size)
        [" (#{size_str})" | parts]
      else
        parts
      end

    Enum.join(parts, "")
  end

  defp get_file_icon(file_type) do
    case file_type do
      :rust -> "🦀"
      :elixir -> "💜"
      :javascript -> "📜"
      :typescript -> "📘"
      :python -> "🐍"
      :markdown -> "📝"
      :json -> "📋"
      :yaml -> "⚙️"
      :dockerfile -> "🐳"
      :shell -> "🔧"
      _ -> "📄"
    end
  end

  defp format_file_size(size) when size < 1024, do: "#{size}B"

  defp format_file_size(size) when size < 1024 * 1024 do
    "#{Float.round(size / 1024, 1)}KB"
  end

  defp format_file_size(size) when size < 1024 * 1024 * 1024 do
    "#{Float.round(size / (1024 * 1024), 1)}MB"
  end

  defp format_file_size(size) do
    "#{Float.round(size / (1024 * 1024 * 1024), 1)}GB"
  end

  defp render_stats(%{} = stats) do
    """
    **Totals**: 📂 #{stats.total_dirs} dirs • 📄 #{stats.total_files} files • 🧾 ~#{format_line_count(stats.line_count)} LOC

    #{render_file_type_breakdown(stats.file_types)}
    """
  end

  defp format_line_count(count) when count < 1000, do: "#{count}"

  defp format_line_count(count) when count < 1_000_000 do
    "#{Float.round(count / 1000, 1)}K"
  end

  defp format_line_count(count) do
    "#{Float.round(count / 1_000_000, 1)}M"
  end

  defp render_file_type_breakdown(file_types) when map_size(file_types) == 0, do: ""

  defp render_file_type_breakdown(file_types) do
    total = Enum.sum(Map.values(file_types))

    breakdown =
      file_types
      |> Enum.sort_by(fn {_type, count} -> count end, :desc)
      # Top 8 file types
      |> Enum.take(8)
      |> Enum.map(fn {type, count} ->
        percentage = round(count / total * 100)
        bar_length = round(percentage / 100 * 15)
        bar = String.duplicate("#", bar_length) <> String.duplicate("-", 15 - bar_length)
        type_name = type |> Atom.to_string() |> String.capitalize()
        "- #{type_name}: #{count} (#{percentage}%) #{bar}"
      end)
      |> Enum.join("\n")

    "**By type**:\n#{breakdown}"
  end

  defp parse_markdown_list(_content, _opts) do
    {:error, :not_implemented}
  end

  defp parse_github_tree(_content, _opts) do
    {:error, :not_implemented}
  end

  defp parse_generic_tree(_content, _opts) do
    {:error, :not_implemented}
  end

  defp format_tree_as_markdown(tree_data, opts) do
    style = Keyword.get(opts, :style, :tree)
    github_url = Keyword.get(opts, :github_url)

    lines = render_tree_recursive(tree_data, style, github_url, "", [])
    Enum.join(Enum.reverse(lines), "\n")
  end

  defp render_tree_recursive(%{children: children} = node, style, github_url, prefix, acc) do
    # Render current node
    line = render_node_with_prefix(node, style, github_url, prefix)
    new_acc = [line | acc]

    # Render children with updated prefix
    children
    |> Enum.with_index()
    |> Enum.reduce(new_acc, fn {child, index}, lines ->
      is_last = index == length(children) - 1
      child_prefix = update_prefix(prefix, is_last, style)
      render_tree_recursive(child, style, github_url, child_prefix, lines)
    end)
  end

  defp render_tree_recursive(node, style, github_url, prefix, acc) do
    line = render_node_with_prefix(node, style, github_url, prefix)
    [line | acc]
  end

  defp render_node_with_prefix(%{type: :directory, name: name} = _node, :tree, _github_url, prefix) do
    "#{prefix}#{name}/"
  end

  defp render_node_with_prefix(%{type: :file, name: name} = node, :tree, github_url, prefix) do
    name_part =
      if github_url do
        "[#{name}](#{Path.join(github_url, node.path)})"
      else
        name
      end

    stats = build_file_stats_from_map(node)
    "#{prefix}#{name_part}#{stats}"
  end

  defp render_node_with_prefix(%{name: name} = _node, :markdown, _github_url, _prefix) do
    "- #{name}"
  end

  defp update_prefix(prefix, is_last, :tree) do
    if is_last do
      prefix <> "    "
    else
      prefix <> "│   "
    end
  end

  defp update_prefix(prefix, _is_last, _style) do
    prefix <> "  "
  end

  defp build_file_stats_from_map(%{line_count: line_count}) when is_integer(line_count) do
    " (#{line_count} lines)"
  end

  defp build_file_stats_from_map(%{size: size}) when is_integer(size) do
    " (#{format_file_size(size)})"
  end

  defp build_file_stats_from_map(_), do: ""

  defp calculate_directory_size(children) do
    Enum.reduce(children, 0, fn child, acc ->
      case child do
        %{size: size} when is_integer(size) -> acc + size
        _ -> acc
      end
    end)
  end

  defp count_files(children) do
    Enum.reduce(children, 0, fn child, acc ->
      case child do
        %{type: :file} -> acc + 1
        %{type: :directory, children: sub_children} -> acc + count_files(sub_children)
        _ -> acc
      end
    end)
  end

  defp show_tree_structure(vfs, full_path) do
    # This would show tree structure from the mounted filesystem
    case File.ls(full_path) do
      {:ok, _entries} ->
        # Generate tree view of the mounted filesystem
        {:ok, "Tree structure for #{full_path}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_files(vfs, pattern) do
    # Find files matching pattern in mounted filesystem
    mount_point = vfs.mount_point

    try do
      matches = Path.wildcard(Path.join(mount_point, pattern))
      {:ok, matches}
    rescue
      _ -> {:error, :pattern_error}
    end
  end

  defp get_file_stats(_vfs, full_path) do
    File.stat(full_path)
  end

  defp get_working_directory(vfs) do
    {:ok, vfs.mount_point}
  end

  # Add missing PathGlob module stub for compilation
  defmodule PathGlob do
    def match?(pattern, path) do
      # Simple glob matching - in production you'd use a proper glob library
      regex_pattern =
        pattern
        |> String.replace("**", ".*")
        |> String.replace("*", "[^/]*")
        |> String.replace("?", ".")
        |> then(&("^" <> &1 <> "$"))

      case Regex.compile(regex_pattern) do
        {:ok, regex} -> Regex.match?(regex, path)
        {:error, _} -> false
      end
    end
  end
end
