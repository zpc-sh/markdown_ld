#!/usr/bin/env elixir

# Filesystem Mount/Dismount Example for AI Operations
# Demonstrates how AI can work with markdown as a virtual filesystem

Mix.install([
  {:markdown_ld, path: "."},
  {:jason, "~> 1.4"}
])

defmodule FilesystemMountExample do
  @moduledoc """
  Comprehensive example showing how to mount markdown as a virtual filesystem,
  perform operations, and dismount back to markdown.

  This demonstrates the workflow for AI agents that need to:
  1. Mount a codebase from markdown
  2. Navigate and modify files as if it's a real filesystem
  3. Dismount back to markdown with all changes preserved
  """

  alias MarkdownLd.AST.Filesystem
  alias MarkdownLd.AST

  def run_full_workflow do
    IO.puts("🚀 Markdown Filesystem Mount/Dismount Example")
    IO.puts("=" |> String.duplicate(60))

    # Step 1: Create example codebase markdown
    codebase_markdown = create_example_codebase_markdown()
    IO.puts("\n📝 Created example codebase markdown (#{byte_size(codebase_markdown)} bytes)")

    # Step 2: Parse tree markdown to AST
    {:ok, fs_ast} = Filesystem.parse_tree_markdown(codebase_markdown)
    IO.puts("🌳 Parsed to filesystem AST with #{AST.stats(fs_ast).total_nodes} nodes")

    # Step 3: Mount as virtual filesystem
    {:ok, vfs} = Filesystem.mount(fs_ast, writable: true)
    IO.puts("🗂️ Mounted at: #{vfs.mount_point}")
    print_mount_info(vfs)

    # Step 4: AI-style filesystem operations
    demonstrate_ai_operations(vfs)

    # Step 5: Dismount and show results
    {:ok, updated_markdown} = Filesystem.dismount(vfs)
    IO.puts("\n📤 Dismounted filesystem")
    IO.puts("Updated markdown:")
    IO.puts("-" |> String.duplicate(40))
    IO.puts(updated_markdown)
    IO.puts("-" |> String.duplicate(40))

    IO.puts("\n✅ Workflow complete!")
  end

  defp create_example_codebase_markdown do
    """
    # Project Structure

    Generated from tree2md-style markdown representing a complete codebase.

    ```
    src/
    ├── main.rs (250 lines)
    ├── lib.rs (180 lines)
    ├── config/
    │   ├── settings.toml (45 lines)
    │   └── database.yml (30 lines)
    └── utils/
        ├── helper.rs (95 lines)
        └── logging.rs (120 lines)
    tests/
    ├── integration/
    │   ├── api_test.rs (200 lines)
    │   └── db_test.rs (150 lines)
    └── unit/
        ├── main_test.rs (80 lines)
        └── helper_test.rs (60 lines)
    docs/
    ├── README.md (100 lines)
    ├── API.md (300 lines)
    └── deployment/
        ├── docker.md (75 lines)
        └── kubernetes.md (120 lines)
    Cargo.toml (50 lines)
    .gitignore (25 lines)
    LICENSE (20 lines)
    ```

    **Totals**: 📂 8 dirs • 📄 15 files • 🧾 ~1.9K LOC

    **By type**:
    - Rust: 7 (47%) #######--------
    - Markdown: 4 (27%) ####-----------
    - Config: 2 (13%) ##-------------
    - TOML: 1 (7%) #--------------
    - License: 1 (7%) #--------------
    """
  end

  defp print_mount_info(vfs) do
    IO.puts("\n📊 Mount Information:")
    IO.puts("  Mount point: #{vfs.mount_point}")
    IO.puts("  Mounted at: #{vfs.metadata.mounted_at}")
    IO.puts("  Original stats: #{inspect(vfs.metadata.stats)}")

    IO.puts("\n📁 Directory structure:")

    case File.ls(vfs.mount_point) do
      {:ok, entries} ->
        Enum.each(entries, fn entry ->
          path = Path.join(vfs.mount_point, entry)

          case File.stat(path) do
            {:ok, %{type: :directory}} -> IO.puts("  📁 #{entry}/")
            {:ok, %{type: :regular}} -> IO.puts("  📄 #{entry}")
            _ -> IO.puts("  ❓ #{entry}")
          end
        end)

      {:error, reason} ->
        IO.puts("  Error listing directory: #{inspect(reason)}")
    end
  end

  defp demonstrate_ai_operations(vfs) do
    IO.puts("\n🤖 Demonstrating AI Filesystem Operations")
    IO.puts("-" |> String.duplicate(40))

    # Navigate filesystem like an AI would
    demonstrate_navigation(vfs)

    # Read and analyze files
    demonstrate_file_reading(vfs)

    # Modify files
    demonstrate_file_modification(vfs)

    # Create new files
    demonstrate_file_creation(vfs)
  end

  defp demonstrate_navigation(vfs) do
    IO.puts("\n🧭 Navigation Operations:")

    # List root directory
    case Filesystem.navigate(vfs, :ls, ".") do
      {:ok, entries} ->
        IO.puts("📋 Root directory contents:")

        Enum.each(entries, fn entry ->
          type_icon = if entry.type == :directory, do: "📁", else: "📄"
          IO.puts("  #{type_icon} #{entry.name}")
        end)

      {:error, reason} ->
        IO.puts("❌ Error listing directory: #{inspect(reason)}")
    end

    # Show tree structure
    case Filesystem.navigate(vfs, :tree, ".") do
      {:ok, tree_output} ->
        IO.puts("🌳 Tree structure: #{tree_output}")

      {:error, reason} ->
        IO.puts("❌ Error showing tree: #{inspect(reason)}")
    end

    # Find files
    case Filesystem.navigate(vfs, :find, "**/*.rs") do
      {:ok, rust_files} ->
        IO.puts("🔍 Found #{length(rust_files)} Rust files:")

        Enum.take(rust_files, 3)
        |> Enum.each(fn file ->
          IO.puts("  🦀 #{Path.relative_to(file, vfs.mount_point)}")
        end)

      {:error, reason} ->
        IO.puts("❌ Error finding files: #{inspect(reason)}")
    end
  end

  defp demonstrate_file_reading(vfs) do
    IO.puts("\n📖 File Reading Operations:")

    # Check if Cargo.toml exists and read it
    cargo_path = Path.join(vfs.mount_point, "Cargo.toml")

    case File.exists?(cargo_path) do
      true ->
        case Filesystem.navigate(vfs, :cat, "Cargo.toml") do
          {:ok, content} ->
            IO.puts("📄 Cargo.toml content (first 200 chars):")
            IO.puts("  #{String.slice(content, 0, 200)}...")

          {:error, reason} ->
            IO.puts("❌ Error reading Cargo.toml: #{inspect(reason)}")
        end

      false ->
        IO.puts("📄 Cargo.toml: File placeholder (empty in mount)")
    end

    # Get file statistics
    case Filesystem.navigate(vfs, :stat, "src/main.rs") do
      {:ok, stat} ->
        IO.puts("📊 src/main.rs stats:")
        IO.puts("  Size: #{stat.size} bytes")
        IO.puts("  Type: #{stat.type}")

      {:error, reason} ->
        IO.puts("❌ Error getting file stats: #{inspect(reason)}")
    end
  end

  defp demonstrate_file_modification(vfs) do
    IO.puts("\n✏️ File Modification Operations:")

    # Create content for main.rs
    main_rs_content = """
    // Auto-generated main.rs by AI filesystem operations
    use std::env;
    use std::process;

    mod config;
    mod utils;

    fn main() {
        println!("Hello from modified main.rs!");

        let args: Vec<String> = env::args().collect();
        if args.len() > 1 {
            println!("Arguments: {:?}", &args[1..]);
        }

        // Initialize configuration
        match config::load_settings() {
            Ok(settings) => println!("Settings loaded: {:?}", settings),
            Err(e) => {
                eprintln!("Failed to load settings: {}", e);
                process::exit(1);
            }
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_main_functionality() {
            // Test main function components
            assert!(true, "Basic test placeholder");
        }
    }
    """

    # Write to main.rs
    main_rs_path = Path.join(vfs.mount_point, "src/main.rs")

    case File.write(main_rs_path, main_rs_content) do
      :ok ->
        IO.puts("✅ Modified src/main.rs (#{byte_size(main_rs_content)} bytes)")
        IO.puts("   Added #{length(String.split(main_rs_content, "\n"))} lines")

      {:error, reason} ->
        IO.puts("❌ Error writing to main.rs: #{inspect(reason)}")
    end

    # Update README.md
    readme_content = """
    # Project README

    This project has been automatically updated by AI filesystem operations.

    ## Features

    - Rust-based implementation
    - Configuration management
    - Comprehensive testing
    - AI-enhanced development workflow

    ## Building

    ```bash
    cargo build --release
    ```

    ## Testing

    ```bash
    cargo test
    ```

    ## AI Integration

    This project demonstrates how AI can work with codebases through
    markdown filesystem mounting:

    1. Parse codebase structure from markdown
    2. Mount as virtual filesystem
    3. Perform standard file operations
    4. Dismount back to updated markdown

    Generated at: #{DateTime.utc_now()}
    """

    readme_path = Path.join([vfs.mount_point, "docs", "README.md"])

    case File.write(readme_path, readme_content) do
      :ok ->
        IO.puts("✅ Updated docs/README.md")

      {:error, reason} ->
        IO.puts("❌ Error updating README: #{inspect(reason)}")
    end
  end

  defp demonstrate_file_creation(vfs) do
    IO.puts("\n📝 File Creation Operations:")

    # Create a new configuration file
    config_content = """
    # AI Configuration
    # Generated by AI filesystem operations

    [ai]
    enabled = true
    model = "gpt-4"
    temperature = 0.7
    max_tokens = 2000

    [filesystem]
    mount_temp_dir = true
    preserve_permissions = true
    sync_mode = "on_dismount"

    [development]
    auto_format = true
    run_tests_on_save = true
    generate_docs = true
    """

    ai_config_path = Path.join([vfs.mount_point, "src", "config", "ai.toml"])

    case File.write(ai_config_path, config_content) do
      :ok ->
        IO.puts("✅ Created src/config/ai.toml")

      {:error, reason} ->
        IO.puts("❌ Error creating AI config: #{inspect(reason)}")
    end

    # Create a new test file
    test_content = """
    // AI-generated integration test
    use crate::config;

    #[tokio::test]
    async fn test_ai_integration() {
        // Test AI configuration loading
        let ai_config = config::load_ai_settings().expect("AI config should load");
        assert!(ai_config.enabled, "AI should be enabled");

        // Test filesystem operations
        let temp_dir = std::env::temp_dir();
        let test_file = temp_dir.join("ai_test.txt");

        std::fs::write(&test_file, "Hello from AI!").expect("Should write test file");
        let content = std::fs::read_to_string(&test_file).expect("Should read test file");

        assert_eq!(content, "Hello from AI!");

        // Cleanup
        std::fs::remove_file(&test_file).ok();
    }

    #[test]
    fn test_markdown_filesystem_round_trip() {
        // Test that we can mount, modify, and dismount
        // This would be the test for our current operation
        assert!(true, "Placeholder for round-trip test");
    }
    """

    ai_test_path = Path.join([vfs.mount_point, "tests", "integration", "ai_integration_test.rs"])

    case File.write(ai_test_path, test_content) do
      :ok ->
        IO.puts("✅ Created tests/integration/ai_integration_test.rs")

      {:error, reason} ->
        IO.puts("❌ Error creating AI test: #{inspect(reason)}")
    end

    # Create a documentation file
    doc_content = """
    # AI Filesystem Operations

    This document describes how AI agents can work with codebases through
    markdown filesystem mounting.

    ## Overview

    The markdown filesystem allows AI to:

    1. **Parse** codebase structure from tree-style markdown
    2. **Mount** the structure as a virtual filesystem
    3. **Navigate** using standard filesystem operations
    4. **Modify** files and directories as needed
    5. **Dismount** back to updated markdown

    ## Benefits

    - **Familiar Interface**: AI uses standard file operations
    - **Preservation**: All changes are captured in markdown
    - **Portability**: Entire codebases as single markdown files
    - **Versioning**: Standard markdown diff/merge operations
    - **Compression**: Efficient storage of large codebases

    ## Example Workflow

    ```elixir
    # Parse codebase markdown
    {:ok, fs_ast} = Filesystem.parse_tree_markdown(markdown)

    # Mount as virtual filesystem
    {:ok, vfs} = Filesystem.mount(fs_ast)

    # AI performs file operations
    File.write(Path.join(vfs.mount_point, "new_file.rs"), content)
    File.read(Path.join(vfs.mount_point, "existing_file.rs"))

    # Dismount with all changes
    {:ok, updated_markdown} = Filesystem.dismount(vfs)
    ```

    ## Implementation Notes

    - Uses temporary directories for mounting
    - Preserves file metadata and statistics
    - Supports both tree and markdown output formats
    - Handles binary files appropriately
    - Includes comprehensive error handling

    Generated by AI filesystem operations at #{DateTime.utc_now()}
    """

    ai_doc_path = Path.join([vfs.mount_point, "docs", "ai_filesystem.md"])

    case File.write(ai_doc_path, doc_content) do
      :ok ->
        IO.puts("✅ Created docs/ai_filesystem.md")

      {:error, reason} ->
        IO.puts("❌ Error creating AI documentation: #{inspect(reason)}")
    end

    IO.puts("\n📊 Final filesystem state:")
    print_filesystem_summary(vfs)
  end

  defp print_filesystem_summary(vfs) do
    case File.ls(vfs.mount_point) do
      {:ok, entries} ->
        total_files = count_files_recursive(vfs.mount_point)
        total_size = calculate_total_size(vfs.mount_point)

        IO.puts("  📁 Root entries: #{length(entries)}")
        IO.puts("  📄 Total files: #{total_files}")
        IO.puts("  💾 Total size: #{format_bytes(total_size)}")

      {:error, reason} ->
        IO.puts("  ❌ Error reading filesystem: #{inspect(reason)}")
    end
  end

  defp count_files_recursive(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.reduce(entries, 0, fn entry, acc ->
          path = Path.join(dir, entry)

          case File.stat(path) do
            {:ok, %{type: :directory}} -> acc + count_files_recursive(path)
            {:ok, %{type: :regular}} -> acc + 1
            _ -> acc
          end
        end)

      {:error, _} ->
        0
    end
  end

  defp calculate_total_size(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.reduce(entries, 0, fn entry, acc ->
          path = Path.join(dir, entry)

          case File.stat(path) do
            {:ok, %{type: :directory}} -> acc + calculate_total_size(path)
            {:ok, %{type: :regular, size: size}} -> acc + size
            _ -> acc
          end
        end)

      {:error, _} ->
        0
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"

  defp format_bytes(bytes) when bytes < 1024 * 1024 do
    "#{Float.round(bytes / 1024, 1)}KB"
  end

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024 do
    "#{Float.round(bytes / (1024 * 1024), 1)}MB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / (1024 * 1024 * 1024), 1)}GB"
  end
end

# Run the example
FilesystemMountExample.run_full_workflow()
