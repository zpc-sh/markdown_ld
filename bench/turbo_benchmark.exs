# PERF: Comprehensive benchmark suite for MarkdownLd
# This benchmark demonstrates the performance improvements from SIMD optimizations,
# memory pooling, and advanced parsing algorithms.

defmodule MarkdownLd.TurboBenchmark do
  @moduledoc """
  Comprehensive performance benchmarks for MarkdownLd with SIMD optimizations.
  
  Tests various markdown processing scenarios and compares performance
  across different input sizes and content types.
  """

  def run do
    IO.puts("🚀 MarkdownLd Turbo Benchmark Suite")
    IO.puts("=" |> String.duplicate(50))
    
    # Test data generation
    test_cases = generate_test_cases()
    
    # Run individual function benchmarks
    run_parsing_benchmarks(test_cases)
    run_extraction_benchmarks(test_cases)
    run_batch_benchmarks(test_cases)
    run_zero_copy_benchmarks(test_cases)
    
    # Performance tracking
    display_performance_stats()
    
    IO.puts("\n✨ Benchmark completed!")
  end

  defp generate_test_cases do
    %{
      small: generate_markdown(100),
      medium: generate_markdown(1000),
      large: generate_markdown(10000),
      huge: generate_markdown(50000),
      link_heavy: generate_link_heavy_markdown(500),
      heading_heavy: generate_heading_heavy_markdown(300),
      code_heavy: generate_code_heavy_markdown(200),
      mixed_content: generate_mixed_markdown(2000)
    }
  end

  defp run_parsing_benchmarks(test_cases) do
    IO.puts("\n📖 Parsing Benchmarks")
    IO.puts("-" |> String.duplicate(30))
    
    Enum.each(test_cases, fn {name, content} ->
      size_mb = byte_size(content) / (1024 * 1024)
      
      {time, {:ok, result}} = :timer.tc(fn ->
        MarkdownLd.parse(content, cache_patterns: true, track_performance: true)
      end)
      
      processing_speed = byte_size(content) / time * 1_000_000 / (1024 * 1024)  # MB/s
      
      IO.puts("#{format_name(name)} | #{format_size(size_mb)} MB | #{format_time(time)} μs | #{format_speed(processing_speed)} MB/s")
      IO.puts("  └─ #{result.word_count} words, #{length(result.headings)} headings, #{length(result.links)} links")
    end)
  end

  defp run_extraction_benchmarks(test_cases) do
    IO.puts("\n🔍 SIMD Extraction Benchmarks")
    IO.puts("-" |> String.duplicate(30))
    
    content = test_cases.mixed_content
    functions = [
      {"Word Count", &MarkdownLd.word_count/1},
      {"Links", &MarkdownLd.extract_links/1},
      {"Headings", &MarkdownLd.extract_headings/1},
      {"Code Blocks", &MarkdownLd.extract_code_blocks/1},
      {"Tasks", &MarkdownLd.extract_tasks/1}
    ]
    
    Enum.each(functions, fn {name, func} ->
      {time, {:ok, result}} = :timer.tc(fn -> func.(content) end)
      processing_speed = byte_size(content) / time * 1_000_000 / (1024 * 1024)
      
      count = if is_integer(result), do: result, else: length(result)
      IO.puts("#{format_name(name)} | #{format_time(time)} μs | #{format_speed(processing_speed)} MB/s | #{count} items")
    end)
  end

  defp run_batch_benchmarks(test_cases) do
    IO.puts("\n📦 Batch Processing Benchmarks")
    IO.puts("-" |> String.duplicate(30))
    
    # Create batch test data
    small_docs = List.duplicate(test_cases.small, 50)
    medium_docs = List.duplicate(test_cases.medium, 20)
    large_docs = List.duplicate(test_cases.large, 5)
    
    test_batches = [
      {"50 Small Docs", small_docs},
      {"20 Medium Docs", medium_docs},
      {"5 Large Docs", large_docs}
    ]
    
    Enum.each(test_batches, fn {name, docs} ->
      total_size = Enum.sum(Enum.map(docs, &byte_size/1)) / (1024 * 1024)
      
      # Elixir-side parallel
      {time_elixir, {:ok, _}} = :timer.tc(fn ->
        MarkdownLd.parse_batch(docs, max_workers: 4)
      end)
      
      # Rust-side parallel
      {time_rust, {:ok, _}} = :timer.tc(fn ->
        MarkdownLd.parse_batch_rust(docs)
      end)
      
      speed_elixir = total_size / time_elixir * 1_000_000
      speed_rust = total_size / time_rust * 1_000_000
      
      IO.puts("#{format_name(name)} | #{format_size(total_size)} MB total")
      IO.puts("  ├─ Elixir Parallel: #{format_time(time_elixir)} μs | #{format_speed(speed_elixir)} MB/s")
      IO.puts("  └─ Rust Parallel:   #{format_time(time_rust)} μs | #{format_speed(speed_rust)} MB/s")
    end)
  end

  defp run_zero_copy_benchmarks(test_cases) do
    IO.puts("\n⚡ Zero-Copy vs Regular Parsing")
    IO.puts("-" |> String.duplicate(30))
    
    content = test_cases.large
    
    # Regular parsing
    {time_regular, {:ok, _}} = :timer.tc(fn ->
      MarkdownLd.parse(content)
    end)
    
    # Zero-copy binary parsing
    {time_zero_copy, {:ok, _}} = :timer.tc(fn ->
      MarkdownLd.parse_binary(content)
    end)
    
    speedup = time_regular / time_zero_copy
    size_mb = byte_size(content) / (1024 * 1024)
    
    IO.puts("Content Size: #{format_size(size_mb)} MB")
    IO.puts("Regular Parse: #{format_time(time_regular)} μs")
    IO.puts("Zero-Copy Parse: #{format_time(time_zero_copy)} μs")
    IO.puts("Speedup: #{Float.round(speedup, 2)}x faster")
  end

  defp display_performance_stats do
    IO.puts("\n📊 Performance Statistics")
    IO.puts("-" |> String.duplicate(30))
    
    case MarkdownLd.get_performance_stats() do
      {:ok, stats} ->
        IO.puts("Total SIMD Operations: #{stats["simd_operations"] || 0}")
        IO.puts("Cache Hit Rate: #{stats["cache_hit_rate"] || 0.0}%")
        IO.puts("Memory Pool Usage: #{stats["memory_pool_usage"] || 0} bytes")
        IO.puts("Pattern Cache Size: #{stats["pattern_cache_size"] || 0} entries")
      {:error, reason} ->
        IO.puts("Could not retrieve stats: #{reason}")
    end
    
    # Reset for next run
    MarkdownLd.reset_performance_stats()
  end

  # Test data generators

  defp generate_markdown(word_count) do
    paragraphs = div(word_count, 50)
    
    1..paragraphs
    |> Enum.map(fn _ ->
      paragraph = 1..50
      |> Enum.map(fn _ -> random_word() end)
      |> Enum.join(" ")
      
      # Add some markdown formatting
      paragraph
      |> add_random_formatting()
    end)
    |> Enum.join("\n\n")
  end

  defp generate_link_heavy_markdown(link_count) do
    1..link_count
    |> Enum.map(fn i ->
      "[Link #{i}](https://example#{i}.com)"
    end)
    |> Enum.join(" ")
  end

  defp generate_heading_heavy_markdown(heading_count) do
    1..heading_count
    |> Enum.map(fn i ->
      level = rem(i, 6) + 1
      hashes = String.duplicate("#", level)
      "#{hashes} Heading #{i}"
    end)
    |> Enum.join("\n\n")
  end

  defp generate_code_heavy_markdown(block_count) do
    languages = ["elixir", "rust", "javascript", "python", "go"]
    
    1..block_count
    |> Enum.map(fn i ->
      lang = Enum.at(languages, rem(i, length(languages)))
      code_lines = 5..15 |> Enum.random()
      
      code = 1..code_lines
      |> Enum.map(fn _ -> "  #{random_word()} #{random_word()}(#{random_word()})" end)
      |> Enum.join("\n")
      
      "```#{lang}\n#{code}\n```"
    end)
    |> Enum.join("\n\n")
  end

  defp generate_mixed_markdown(word_count) do
    base = generate_markdown(word_count)
    links = generate_link_heavy_markdown(20)
    headings = generate_heading_heavy_markdown(10)
    code = generate_code_heavy_markdown(5)
    
    [base, links, headings, code] |> Enum.join("\n\n")
  end

  defp add_random_formatting(text) do
    text
    |> maybe_bold()
    |> maybe_italic()
    |> maybe_code()
  end

  defp maybe_bold(text), do: if(:rand.uniform() < 0.1, do: "**#{text}**", else: text)
  defp maybe_italic(text), do: if(:rand.uniform() < 0.1, do: "*#{text}*", else: text)
  defp maybe_code(text), do: if(:rand.uniform() < 0.05, do: "`#{text}`", else: text)

  defp random_word do
    words = ~w[
      lorem ipsum dolor sit amet consectetur adipiscing elit sed
      do eiusmod tempor incididunt ut labore et dolore magna aliqua
      enim ad minim veniam quis nostrud exercitation ullamco laboris
      nisi aliquip ex ea commodo consequat duis aute irure reprehenderit
      voluptate velit esse cillum fugiat nulla pariatur excepteur sint
      occaecat cupidatat non proident sunt in culpa qui officia deserunt
      mollit anim id est laborum
    ]
    
    Enum.random(words)
  end

  # Formatting helpers

  defp format_name(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
    |> String.pad_trailing(15)
  end

  defp format_size(size_mb) when size_mb < 0.001, do: "#{Float.round(size_mb * 1000, 1)}K"
  defp format_size(size_mb), do: "#{Float.round(size_mb, 3)}"

  defp format_time(time_us) when time_us > 1_000_000 do
    "#{Float.round(time_us / 1_000_000, 2)}s"
  end
  defp format_time(time_us) when time_us > 1_000 do
    "#{Float.round(time_us / 1_000, 1)}ms"
  end
  defp format_time(time_us), do: "#{time_us}μs"

  defp format_speed(speed_mb_s), do: "#{Float.round(speed_mb_s, 1)}"
end

# Run the benchmark
MarkdownLd.TurboBenchmark.run()