defmodule MarkdownLd.Native do
  @moduledoc """
  Native Rust functions for high-performance markdown processing.
  
  This module provides the interface to the underlying Rust implementation
  with SIMD optimizations, memory pooling, and advanced parsing capabilities.
  """

  # Prefer precompiled NIFs when available; fall back to local build via Rustler
  if Code.ensure_loaded?(RustlerPrecompiled) do
    use RustlerPrecompiled,
      otp_app: :markdown_ld,
      crate: "markdown_ld_nif",
      # Binaries should be published under this release tag
      base_url: "https://github.com/nocsi/markdown_ld/releases/download/v0.4.1",
      version: "0.4.1",
      force_build: System.get_env("RUSTLER_PRECOMPILED_FORCE_BUILD") in ["1", "true"],
      targets: [
        "x86_64-unknown-linux-gnu",
        "aarch64-unknown-linux-gnu",
        "x86_64-unknown-linux-musl",
        "aarch64-unknown-linux-musl",
        "x86_64-apple-darwin",
        "aarch64-apple-darwin",
        "x86_64-pc-windows-msvc"
      ]
  else
    use Rustler, otp_app: :markdown_ld, crate: "markdown_ld_nif"
  end

  # Markdown parsing functions
  def parse_markdown(_content, _options), do: :erlang.nif_error(:nif_not_loaded)
  def parse_markdown_binary(_binary, _options), do: :erlang.nif_error(:nif_not_loaded)
  def parse_batch_parallel(_documents, _options), do: :erlang.nif_error(:nif_not_loaded)

  # SIMD-optimized extraction functions
  def word_count_simd(_content), do: :erlang.nif_error(:nif_not_loaded)
  def extract_links_simd(_content), do: :erlang.nif_error(:nif_not_loaded)
  def extract_headings_simd(_content), do: :erlang.nif_error(:nif_not_loaded)
  def extract_code_blocks_simd(_content), do: :erlang.nif_error(:nif_not_loaded)
  def extract_tasks_simd(_content), do: :erlang.nif_error(:nif_not_loaded)

  # Performance and caching functions
  def get_performance_stats(), do: :erlang.nif_error(:nif_not_loaded)
  def reset_performance_stats(), do: :erlang.nif_error(:nif_not_loaded)
  def clear_pattern_cache(), do: :erlang.nif_error(:nif_not_loaded)

  # Experimental: parse attribute object via Rust core, returns {:ok, json_string} or {:error, reason}
  def parse_attr_object_json(_content), do: :erlang.nif_error(:nif_not_loaded)
end
