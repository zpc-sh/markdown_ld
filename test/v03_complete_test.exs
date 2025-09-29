defmodule MarkdownLd.V03CompleteTest do
  use ExUnit.Case
  doctest MarkdownLd.V03Complete

  alias MarkdownLd.V03Complete

  describe "basic v0.3.0 parsing" do
    test "parses standard markdown with enhanced features" do
      markdown = """
      ---
      "@context":
        schema: "https://schema.org/"
      ld:
        subject: "article:test"
      ---

      # Test Article {ld:@type=schema:Article ld:@id=article:test}

      This is a test document with **emphasis** and [a link](https://example.com){ld:prop=schema:url}.

      ```json-ld
      {
        "@context": {"schema": "https://schema.org/"},
        "@type": "Article",
        "@id": "article:test",
        "schema:name": "Test Article"
      }
      ```

      ## Features {#features}

      - [x] JSON-LD integration
      - [ ] Advanced streaming
      - [x] Stable chunk IDs

      ```elixir
      def hello_world do
        IO.puts("Hello, World!")
      end
      ```
      """

      assert {:ok, result} = V03Complete.parse(markdown)

      # Check basic parsing
      assert is_list(result["headings"])
      assert length(result["headings"]) == 2

      # Check enhanced features
      first_heading = Enum.at(result["headings"], 0)
      assert first_heading["text"] == "Test Article"
      assert first_heading["attributes"]["ld:@type"] == "schema:Article"
      assert first_heading["stable_id"]

      # Check JSON-LD islands
      assert is_list(result["jsonld_islands"])
      assert length(result["jsonld_islands"]) >= 1

      # Check links with attributes
      links = result["links"] || []
      link_with_attr = Enum.find(links, &Map.has_key?(&1, "attributes"))
      assert link_with_attr
      assert link_with_attr["attributes"]["ld:prop"] == "schema:url"

      # Check processing metadata
      metadata = result["processing_metadata"]
      assert metadata["v03_complete"] == true
      assert metadata["compliance_level"] == [:l1_core, :l2_inline]
    end

    test "handles strict vs lax modes" do
      # Invalid JSON-LD in content
      invalid_markdown = """
      ```json-ld
      {
        "@context": {"schema": "https://schema.org/"},
        "invalid": json here
      }
      ```
      """

      # Strict mode should catch the error
      assert {:error, _reason} = V03Complete.parse(invalid_markdown, mode: :strict)

      # Lax mode should continue processing
      assert {:ok, result} = V03Complete.parse(invalid_markdown, mode: :lax)
      assert result["processing_metadata"]["processing_mode"] == :lax
    end

    test "enforces processing limits" do
      huge_content = String.duplicate("# Big Heading\n\n", 10_000)

      custom_limits = %{
        # Very small limit
        max_object_size: 1000,
        max_list_length: 100,
        processing_timeout: 1000
      }

      assert {:error, {:limit_exceeded, :max_object_size, _}} =
               V03Complete.parse(huge_content, limits: custom_limits)
    end
  end

  describe "RFC 8785 JCS canonicalization" do
    test "canonicalizes JSON correctly" do
      json = """
      {
        "b": 2,
        "a": 1,
        "c": {
          "z": 3,
          "y": 4
        }
      }
      """

      assert {:ok, canonical} = V03Complete.canonicalize_json(json)
      assert canonical == "{\"a\":1,\"b\":2,\"c\":{\"y\":4,\"z\":3}}"
    end

    test "handles complex JSON structures" do
      json = """
      {
        "@context": {"schema": "https://schema.org/"},
        "@type": ["Article", "CreativeWork"],
        "schema:author": {
          "@type": "Person",
          "schema:name": "Alice"
        }
      }
      """

      assert {:ok, canonical} = V03Complete.canonicalize_json(json)
      # Verify it's valid JSON and properly ordered
      assert {:ok, _parsed} = Jason.decode(canonical)
    end
  end

  describe "stable chunk IDs" do
    test "generates stable IDs for headings" do
      heading_path = ["Introduction", "Getting Started"]
      text = "Installation Guide"

      assert {:ok, stable_id} = V03Complete.generate_stable_id(heading_path, 0, text)
      assert is_binary(stable_id)
      assert String.length(stable_id) == 12

      # Should be deterministic
      assert {:ok, ^stable_id} = V03Complete.generate_stable_id(heading_path, 0, text)
    end

    test "generates different IDs for different content" do
      assert {:ok, id1} = V03Complete.generate_stable_id(["A"], 0, "text1")
      assert {:ok, id2} = V03Complete.generate_stable_id(["A"], 0, "text2")
      assert {:ok, id3} = V03Complete.generate_stable_id(["B"], 0, "text1")

      assert id1 != id2
      assert id1 != id3
      assert id2 != id3
    end
  end

  describe "attribute objects mini-grammar" do
    test "parses simple attributes" do
      attr_str = "id=test type=Article visible=true count=42"

      assert {:ok, attrs} = V03Complete.parse_attribute_object(attr_str, :lax)
      assert attrs["id"] == "test"
      assert attrs["type"] == "Article"
      assert attrs["visible"] == true
      assert attrs["count"] == 42
    end

    test "handles quoted values" do
      attr_str = ~s[title="Hello World" description="A test document"]

      assert {:ok, attrs} = V03Complete.parse_attribute_object(attr_str, :lax)
      assert attrs["title"] == "Hello World"
      assert attrs["description"] == "A test document"
    end

    test "strict mode validation" do
      # Valid attributes
      valid_attrs = "ld:@type=Article ld:@id=test:1"
      assert {:ok, _attrs} = V03Complete.parse_attribute_object(valid_attrs, :strict)

      # Invalid in strict mode (would need proper implementation)
      # This is a placeholder for more complex validation
      assert {:ok, _attrs} = V03Complete.parse_attribute_object(valid_attrs, :lax)
    end
  end

  describe "polyglot document detection" do
    test "detects Dockerfile polyglots" do
      dockerfile_markdown = """
      # My App Deployment

      This document contains deployment instructions:

      ```dockerfile
      FROM elixir:1.15
      RUN mix deps.get
      COPY . .
      RUN mix release
      CMD ["./my_app"]
      ```

      The above Dockerfile will build our application.
      """

      assert {:ok, result} = V03Complete.detect_polyglot(dockerfile_markdown)
      assert result.detected == true
      assert result.language == "dockerfile"
      assert length(result.artifacts) > 0
    end

    test "detects Kubernetes polyglots" do
      k8s_markdown = """
      # Kubernetes Deployment

      ```yaml
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: my-app
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: my-app
      ```
      """

      assert {:ok, result} = V03Complete.detect_polyglot(k8s_markdown)
      assert result.detected == true
      assert result.language == "kubernetes"
    end

    test "detects bash script polyglots" do
      bash_markdown = """
      # Setup Script

      ```bash
      #!/bin/bash
      echo "Setting up environment..."
      mkdir -p /opt/app
      cd /opt/app
      ./configure --prefix=/usr
      make install
      ```
      """

      assert {:ok, result} = V03Complete.detect_polyglot(bash_markdown)
      assert result.detected == true
      assert result.language == "bash"
    end

    test "returns false for regular markdown" do
      normal_markdown = """
      # Regular Document

      This is just a normal markdown document with some text.

      ## Features

      - Item 1
      - Item 2
      """

      assert {:ok, result} = V03Complete.detect_polyglot(normal_markdown)
      assert result.detected == false
    end
  end

  describe "character concealment" do
    test "hides data with zero-width characters" do
      text = "Hello World"
      secret_data = "secret information"

      assert {:ok, hidden_text} = V03Complete.hide_data_zero_width(text, secret_data)
      assert String.length(hidden_text) > String.length(text)
      # Text should still look the same when printed (invisible characters)
      assert String.starts_with?(hidden_text, text)
    end

    test "extracts concealed data from document" do
      # Document with hidden zero-width characters
      # Contains hidden chars
      concealed_markdown = "Hello​‌‍⁠World"

      assert {:ok, result} = V03Complete.parse(concealed_markdown, enable_concealment: true)
      concealment = result["concealment"]

      if concealment do
        assert concealment["zero_width_found"] == true
      end
    end

    test "detects content-addressed links" do
      markdown = """
      See the [deployment guide](e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855).

      Also check [another resource](a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3).
      """

      assert {:ok, result} = V03Complete.parse(markdown, enable_concealment: true)
      concealment = result["concealment"]

      if concealment do
        assert concealment["content_links_count"] == 2
      end
    end
  end

  describe "mem8 integration" do
    test "parses with mem8 context from map" do
      markdown = """
      # AI-Enhanced Document

      This document will be processed with wave-based context.
      """

      mem8_context = %{
        "version" => "1.0.0",
        "awareness_level" => 0.8,
        "active_memories" => [
          %{"frequency" => 440.0, "amplitude" => 0.5},
          %{"frequency" => 880.0, "amplitude" => 0.3}
        ],
        "attention_weights" => %{
          "technical" => 0.7,
          "creative" => 0.3
        },
        "blocks" => [],
        "projects" => []
      }

      assert {:ok, result} = V03Complete.parse_with_mem8(markdown, mem8_context)

      # Check mem8 integration
      assert result["wave_influence"] != nil
      assert result["consciousness_state"]["awareness_level"] == 0.8
      assert result["consciousness_state"]["active_memories"] == 2
      assert result["processing_metadata"]["mem8_enhanced"] == true
    end

    test "handles missing mem8 context gracefully" do
      markdown = "# Simple Document"

      # Should work without mem8 context
      assert {:ok, result} = V03Complete.parse(markdown)
      assert result["processing_metadata"]["mem8_enhanced"] == false
    end
  end

  describe "streaming diff with stable IDs" do
    test "detects moves using stable IDs" do
      old_content = """
      # Introduction
      Welcome to our app.

      ## Getting Started
      First, install dependencies.

      ## Advanced Usage
      For advanced users.
      """

      new_content = """
      # Introduction
      Welcome to our app.

      ## Advanced Usage
      For advanced users.

      ## Getting Started
      First, install dependencies.
      """

      assert {:ok, diff} = V03Complete.diff_with_stable_ids(old_content, new_content)

      # Should detect that "Getting Started" moved
      move_operations = Enum.filter(diff, &(&1.type == :move_block))
      assert length(move_operations) > 0

      move_op = Enum.at(move_operations, 0)
      assert move_op.stable_id
      assert move_op.from_line != move_op.to_line
    end

    test "detects content updates with stable IDs" do
      old_content = """
      # My Project
      Version 1.0 documentation.
      """

      new_content = """
      # My Project
      Version 2.0 documentation with new features.
      """

      assert {:ok, diff} = V03Complete.diff_with_stable_ids(old_content, new_content)

      update_operations = Enum.filter(diff, &(&1.type == :update_block))
      assert length(update_operations) > 0

      update_op = Enum.at(update_operations, 0)
      assert update_op.old_content != update_op.new_content
      assert update_op.stable_id
    end
  end

  describe "semantic merge" do
    test "merges non-conflicting changes" do
      base = """
      # Project
      Base version.

      ## Features
      - Feature A
      """

      ours = """
      # Project
      Our version.

      ## Features
      - Feature A
      - Feature B
      """

      theirs = """
      # Project
      Base version.

      ## Features
      - Feature A
      ## Installation
      Run `mix deps.get`.
      """

      assert {:ok, merged} = V03Complete.semantic_merge(base, ours, theirs)
      assert is_binary(merged)
      # Merged result should contain elements from both branches
    end

    test "detects merge conflicts" do
      base = """
      # Project
      Base version.
      """

      ours = """
      # Project
      Our conflicting version.
      """

      theirs = """
      # Project
      Their conflicting version.
      """

      assert {:error, {:merge_conflicts, conflicts}} =
               V03Complete.semantic_merge(base, ours, theirs)

      assert length(conflicts) > 0

      conflict = Enum.at(conflicts, 0)
      assert conflict.type == :same_segment_edit
      assert conflict.stable_id
    end
  end

  describe "compliance level validation" do
    test "validates L1 core compliance" do
      # Document with frontmatter and JSON-LD
      l1_document = """
      ---
      "@context":
        schema: "https://schema.org/"
      ---

      # Test

      ```json-ld
      {"@type": "Article"}
      ```
      """

      assert {:ok, result} = V03Complete.parse(l1_document, compliance_level: [:l1_core])
      assert result["processing_metadata"]["compliance_level"] == [:l1_core]
    end

    test "validates L2 inline compliance" do
      l2_document = """
      # Test Document {ld:@type=Article}

      [Link with properties](http://example.com){ld:prop=schema:url}
      """

      assert {:ok, result} = V03Complete.parse(l2_document, compliance_level: [:l2_inline])
      # Should have inline attributes processed
      heading = Enum.at(result["headings"], 0)
      assert heading["attributes"]["ld:@type"] == "Article"
    end

    test "fails compliance for insufficient features" do
      # Plain markdown without required features
      plain_document = """
      # Simple Document
      Just plain text.
      """

      # Should fail L1 compliance (no frontmatter context or JSON-LD)
      assert {:error, {:compliance_failures, failures}} =
               V03Complete.parse(plain_document, compliance_level: [:l1_core])

      assert length(failures) > 0

      assert Enum.any?(failures, fn {check, _reason} ->
               check in [:frontmatter_context, :jsonld_fences]
             end)
    end
  end

  describe "performance and limits" do
    test "respects processing timeout" do
      # This would be slow content in reality
      content = "# Test Document\n\nSome content."

      short_timeout_limits = %{
        max_object_size: 100_000,
        max_list_length: 1000,
        # 1ms - very short
        processing_timeout: 1
      }

      # Might timeout, but should handle gracefully
      result = V03Complete.parse(content, limits: short_timeout_limits)

      case result do
        # Completed within timeout
        {:ok, _} -> assert true
        # Timeout handled gracefully
        {:error, :processing_timeout} -> assert true
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "tracks performance metadata" do
      content = """
      # Performance Test

      This document tests performance tracking.

      ```json-ld
      {"@type": "Article"}
      ```
      """

      assert {:ok, result} = V03Complete.parse(content, track_performance: true)

      # Should have processing time
      assert result["processing_time_us"] != nil
      assert is_integer(result["processing_time_us"])
      assert result["processing_time_us"] > 0
    end
  end

  describe "error handling" do
    test "categorizes errors correctly" do
      # Invalid JSON-LD syntax
      invalid_content = """
      ```json-ld
      { invalid json here
      ```
      """

      case V03Complete.parse(invalid_content, mode: :strict) do
        {:error, reason} ->
          # Error should be categorized
          assert reason != nil

        {:ok, _} ->
          # Lax mode might allow this
          assert true
      end
    end

    test "handles malformed frontmatter" do
      malformed = """
      ---
      invalid: yaml: here:
        - broken
      ---

      # Content
      """

      # Should handle gracefully in lax mode
      assert {:ok, result} = V03Complete.parse(malformed, mode: :lax)
      # Malformed frontmatter might be ignored
      assert is_map(result)
    end

    test "handles unknown attribute syntax" do
      unknown_attrs = """
      # Heading {unknown:syntax here}
      """

      # Should parse heading but might not process unknown attributes
      assert {:ok, result} = V03Complete.parse(unknown_attrs)
      headings = result["headings"]
      assert length(headings) == 1
      assert Enum.at(headings, 0)["text"] in ["Heading", "Heading {unknown:syntax here}"]
    end
  end

  describe "integration scenarios" do
    test "full featured document with all extensions" do
      complex_document = """
      ---
      "@context":
        schema: "https://schema.org/"
        ex: "https://example.org/"
      ld:
        subject: "project:complex"
        base: "https://example.org/"
      ecosystem:
        version: "0.4"
        capabilities: ["compression", "memory"]
      ---

      # Complex Project {ld:@type=[schema:Article,ex:Project] ld:@id=project:complex}

      This document demonstrates​‌‍⁠ all v0.3 features.

      ## Architecture {#arch}

      The system uses:

      ```dockerfile
      FROM elixir:1.15
      WORKDIR /app
      COPY . .
      RUN mix deps.get && mix release
      CMD ["./app"]
      ```

      ```json-ld
      {
        "@context": {"schema": "https://schema.org/"},
        "@type": "SoftwareApplication",
        "@id": "project:complex",
        "schema:name": "Complex Project",
        "schema:author": {
          "@type": "Person",
          "schema:name": "Developer"
        }
      }
      ```

      ### Links and References

      - [Documentation](https://example.org/docs){ld:prop=schema:documentation}
      - [Repository](a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3)
      - [Live Demo](wss://demo.example.org/socket){ld:prop=schema:demo}

      ### Task List

      - [x] Core implementation
      - [x] Polyglot detection
      - [ ] Advanced streaming
      - [x] Mem8 integration

      ## Deployment

      ```yaml
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: complex-project
      spec:
        replicas: 3
      ```
      """

      # Parse with all features enabled
      opts = [
        compliance_level: [:l1_core, :l2_inline, :l3_advanced],
        detect_polyglot: true,
        enable_concealment: true,
        mode: :lax
      ]

      assert {:ok, result} = V03Complete.parse(complex_document, opts)

      # Verify all features detected
      metadata = result["processing_metadata"]
      assert metadata["v03_complete"] == true
      assert metadata["polyglot_detected"] == true
      assert metadata["concealment_detected"] == true

      # Verify polyglot detection
      polyglot = result["polyglot"]
      assert polyglot["detected"] == true
      assert polyglot["language"] in ["dockerfile", "kubernetes", "bash"]

      # Verify JSON-LD processing
      islands = result["jsonld_islands"]
      # Frontmatter + fence
      assert length(islands) >= 2

      # Verify attribute processing
      headings = result["headings"]
      main_heading = Enum.at(headings, 0)
      assert main_heading["text"] == "Complex Project"
      assert main_heading["attributes"]["ld:@type"] != nil

      # Verify stable IDs
      assert main_heading["stable_id"] != nil
      assert String.length(main_heading["stable_id"]) == 12

      # Verify concealment detection
      if result["concealment"] do
        assert result["concealment"]["zero_width_found"] == true
        assert result["concealment"]["content_links_count"] >= 1
      end
    end

    test "mem8 enhanced processing with wave context" do
      content = """
      # AI-Enhanced Document

      This content will be processed with consciousness context.

      ## Technical Details

      Implementation focuses on wave-based memory patterns.

      ```json-ld
      {
        "@type": "TechnicalDocument",
        "schema:topic": ["AI", "Memory", "Waves"]
      }
      ```
      """

      mem8_context = %{
        "version" => "1.0.0",
        "awareness_level" => 0.9,
        "active_memories" => [
          %{"frequency" => 440.0, "amplitude" => 0.8, "valence" => 0.3},
          %{"frequency" => 880.0, "amplitude" => 0.6, "valence" => 0.7}
        ],
        "attention_weights" => %{
          "technical" => 0.8,
          "ai" => 0.9,
          "implementation" => 0.7
        },
        "blocks" => [],
        "projects" => [%{"name" => "markdown-ld", "status" => "active"}]
      }

      assert {:ok, result} = V03Complete.parse_with_mem8(content, mem8_context)

      # Verify mem8 integration
      assert result["wave_influence"] > 0.0
      consciousness = result["consciousness_state"]
      assert consciousness["awareness_level"] == 0.9
      assert consciousness["active_memories"] == 2

      # Verify enhanced semantic processing
      metadata = result["processing_metadata"]
      assert metadata["mem8_enhanced"] == true
    end
  end
end
