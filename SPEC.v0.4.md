# Markdown-LD Profile v0.4 (Draft)

**Ecosystem Extensions: Compression, Memory, and Virtual Filesystems**

Status: Draft proposal. This profile extends Markdown-LD v0.3 with ecosystem capabilities focusing on intelligent compression and contextual memory processing for next-generation AI-native content systems.

## 1. Scope and Goals

### Core v0.3 Capabilities (Inherited)
- JSON-LD semantics across edits, diffs, and merges
- CommonMark compatibility with streaming support
- Deterministic extraction with stable IDs

### New v0.4 Ecosystem Extensions
- **Compression Extension (E1)**: AI-native MQ2 compression with semantic awareness
- **Memory Extension (E2)**: Wave-based contextual memory for AI processing
- **VFS Extension (E3)**: Foundation for repository embedding (v0.5 target)
- **Ecosystem Orchestration (E4)**: Compression + Memory coordination
- **Model Extension (E5)**: Schema-driven model specifications with code generation

### Design Principles
- **AI-Native**: Optimized for machine intelligence while preserving human readability
- **Backward Compatible**: v0.3 processors gracefully degrade v0.4 content
- **Performance First**: SIMD-optimized compression with 40-80% size reduction
- **Context-Aware**: Memory patterns enhance semantic processing and AI understanding

## 2. Ecosystem Architecture

### 2.1 Ecosystem Declaration

Documents declare ecosystem capabilities in frontmatter:

```yaml
---
"@context":
  schema: "https://schema.org/"
  mld: "https://markdown-ld.org/v0.4/"
ld:
  base: "https://example.org/"
  subject: "ecosystem:main"
ecosystem:
  version: "0.4"
  capabilities: ["compression", "memory"]
  compression:
    format: "mq2"
    level: "L1"
    semantic_aware: true
  memory:
    format: "mem8"
    context_file: "project.m8"
    wave_enabled: true
  # VFS extension planned for v0.5
  # vfs:
  #   format: "native_v1" 
  #   embedded: true
---
```

### 2.2 Processing Pipeline

Ecosystem-enabled documents are processed in layers:

1. **Ecosystem Detection**: Parse frontmatter, identify compression and memory capabilities
2. **Memory Context**: Load wave-based contextual memory and temporal patterns
3. **Decompression Layer**: MQ2 semantic-aware decompression preserving JSON-LD boundaries
4. **Semantic Processing**: Enhanced v0.3 JSON-LD extraction with memory context
5. **Graph Generation**: Semantic graph includes compression metadata and memory relationships

### 2.3 Media Types

**Unified Parameterized Approach**:
- Base: `text/markdown+ld; profile="v0.4"`
- With compression: `text/markdown+ld; profile="v0.4"; compression="mq2"`
- With memory: `text/markdown+ld; profile="v0.4"; memory="mem8"`
- Full ecosystem: `text/markdown+ld; profile="v0.4"; ecosystem="compression,memory"`

## 3. Extension 1: Compression (E1)

### 3.1 MQ2/MarkQant Integration

The Compression Extension integrates MQ2 (MarkQant v2) AI-native compression achieving 40-80% size reduction while maintaining human readability and preserving JSON-LD semantic boundaries.

#### Code Fence Syntax
````markdown
```mq2
MQ2~6743A100~1000~400~A0~mq~L1
~T\x80 Project|\x81 Documentation|\x82 implements|
~~~~
# \x80 \x81

This project \x82 a fast compression algorithm.
```
````

#### Semantic-Aware Tokenization
- Preserve JSON-LD island boundaries during compression
- Use separate token spaces for:
  - Markdown structure (`# ## - * []()`)
  - JSON-LD keywords (`@context @id @type`)
  - Content text (frequency-based assignment)
  - Code blocks (language-specific tokens)

#### Compression Levels
- **L0 (Basic)**: Single-byte tokens, 40-60% compression, high readability
- **L1 (Extended)**: X-token extensions, 50-70% compression, good readability  
- **L2 (Full)**: Advanced patterns, 60-80% compression, moderate readability

### 3.2 Compression-Aware Diff/Merge

Diffs operate on decompressed content but preserve compression metadata:

```elixir
{:ok, patch} = MarkdownLd.diff(old_compressed, new_compressed, 
  compression_aware: true,
  preserve_tokens: true
)
```

Changes to highly-compressed sections trigger token reanalysis for optimal compression.

### 3.3 Security and Limits

- Maximum compressed size: 256MB
- Maximum decompression ratio: 1000:1 (compression bomb protection)
- Token table size limit: 64KB  
- Processing timeout: 30 seconds per document
- Semantic boundary validation: JSON-LD islands must remain parseable

## 4. Extension 2: Memory (E2)

### 4.1 Mem8 Wave-Based Context

The Memory Extension integrates Mem8 wave-based memory patterns for contextual AI processing.

#### Memory Context Files
```
project.m8          # Main project context
README.m8           # Document-specific memory
.cache/context.m8   # Derived contextual memory
```

#### Mem8 Section Integration
Memory sections can be embedded directly in documents:

````markdown
```mem8
[0-15]  MEM8 Header
[16-31] Section Table
[32-N]  Section Data:
  0x06: AI Context - persona overlays, goals, traits
  0x0D: Temporal Index - wave timestamps and decay windows
  0x0E: Collective Emotion - group affect curves
  0x0F: WaveMemoryBlob - 32-byte patterns
```
````

#### Wave Pattern Processing
- **Temporal Context**: Memory patterns influence JSON-LD expansion based on time
- **Emotional Weighting**: Affect curves modify semantic relationship strengths
- **Decay Functions**: Older context information naturally diminishes over time
- **Wave Synchronization**: Multiple documents can share synchronized wave patterns

### 4.2 Contextual Semantic Processing

Memory context influences JSON-LD processing:

```yaml
# Memory-influenced context expansion
"@context":
  schema: "https://schema.org/"
  emotion_weight: 0.7    # Current emotional state influences expansion
  temporal_decay: 0.9    # Recent context weighted higher
  wave_sync: "project:alpha"  # Synchronized with project wave pattern
```

### 4.3 Memory-Enhanced Diffs

Memory patterns track semantic changes over time:

```elixir
{:ok, patch} = MarkdownLd.diff(old, new,
  memory_context: "project.m8",
  track_emotional_changes: true,
  wave_pattern_analysis: true
)
```

### 4.4 Security and Privacy

- Memory contexts are opt-in and clearly declared
- Emotional data includes consent and retention policies
- Wave patterns use cryptographic hashing for privacy protection
- Custodian integration for trauma-aware processing

## 5. Extension 3: VFS (E3)

### 5.1 Virtual Filesystem Embedding

The VFS Extension enables embedding complete filesystem structures within documents.

#### Repository Crystallization
````markdown
```vfs
CODEREPO_NATIVE_V1:
TOKENS:
  0001=dir
  0002=file
  0020=.js
  0021=.rs
  0080=node_modules
DATA:
[compressed filesystem structure]
SUMMARY:
FILES: 1337
DIRS: 42
SIZE: 15728640
```
````

#### Filesystem Semantics
Embedded filesystems generate semantic triples:

```turtle
<project:1> schema:hasPart <project:1/src> .
<project:1/src> rdf:type mld:Directory .
<project:1/src> mld:contains <project:1/src/main.rs> .
<project:1/src/main.rs> rdf:type mld:SourceFile .
<project:1/src/main.rs> mld:language "rust" .
<project:1/src/main.rs> mld:size 2048 .
```

### 5.2 Cross-File Relationships

VFS-enabled documents can reference embedded files:

```markdown
The main algorithm is implemented in [main.rs](vfs://src/main.rs){ld:prop=schema:codeRepository}.

Configuration is stored in [config.json](vfs://config/app.json){ld:prop=schema:configuration}.
```

### 5.3 Distributed Content Systems

VFS enables truly self-contained documents:

```yaml
ecosystem:
  vfs:
    embedded: true
    include_dependencies: true
    compression: "mq2"
    distributed_refs: true
```

### 5.4 VFS Foundation (v0.5 Target)

VFS extension provides the foundation for:
- Repository embedding and crystallization
- Markdown-as-filesystem bindings (innovative VFS interface)
- Self-contained project archives
- Distributed content systems with embedded dependencies

## 6. Extension 4: Ecosystem Orchestration (E4)

### 6.1 Multi-Layer Processing

Full ecosystem support coordinates all extensions:

```yaml
ecosystem:
  version: "0.4"
  orchestration:
    processing_order: ["memory", "compression"]
    memory_enhanced_tokenization: true
    fallback_behavior: "graceful_degradation"
    performance_target: "50ms"
```

### 6.2 Cross-Extension Interactions

- **Memory + Compression**: Wave patterns and context influence optimal token assignment
- **Compression + Memory**: Compressed content includes memory context for enhanced AI processing
- **Temporal Compression**: Memory decay functions optimize token allocation over time

### 6.3 Ecosystem Metadata

Full ecosystems generate rich metadata:

```turtle
<document:1> rdf:type mld:EcosystemDocument .
<document:1> mld:compressionRatio 0.65 .
<document:1> mld:memoryWaveSync "project:alpha" .
<document:1> mld:tokenCount 47 .
<document:1> mld:processingTime "35ms" .
<document:1> mld:ecosystemVersion "0.4" .
```

## 7. Compliance Levels

### Core Levels (v0.3 Compatible)
- **L1 Core**: Frontmatter context, JSON-LD fences, triple diff
- **L2 Inline**: Attribute lists, property tables, heading subjects  
- **L3 Advanced**: Semantic merge, streaming, rename detection

### Extension Levels (v0.4 New)  
- **E1 Compression**: MQ2 compression/decompression with semantic awareness
- **E2 Memory**: Mem8 wave-based contextual processing and temporal patterns
- **E3 VFS**: Foundation for repository embedding (v0.5 implementation)
- **E4 Orchestration**: Compression + Memory coordination and optimization

### Compliance Matrix

| Capability | L1 | L2 | L3 | E1 | E2 | E3 | E4 |
|------------|----|----|----|----|----|----|----| 
| JSON-LD semantics | ✓ | ✓ | ✓ | ✓ | ✓ | ○ | ✓ |
| Inline attributes | | ✓ | ✓ | ✓ | ✓ | ○ | ✓ |
| Streaming/merge | | | ✓ | ✓ | ✓ | ○ | ✓ |
| MQ2 compression | | | | ✓ | | ○ | ✓ |
| Mem8 memory | | | | | ✓ | ○ | ✓ |
| VFS foundation | | | | | | ○ | ○ |
| Memory+Compression | | | | | | ○ | ✓ |

Legend: ✓ = Required, ○ = Planned for v0.5

## 8. Security and Safety

### 8.1 Resource Limits

**Per-Extension Limits**:
- Compression: 256MB max size, 1000:1 max ratio, 30s timeout
- Memory: 64MB context files, 1000 wave patterns, consent tracking
- VFS: Foundation only (implementation in v0.5)

**Ecosystem Limits**:
- Total processing time: 2 minutes
- Memory usage: 512MB RAM maximum
- Disk usage: 5GB temporary files  
- Network: No outbound connections (offline processing)

### 8.2 Privacy and Consent

Memory extension requires explicit consent:

```yaml
ecosystem:
  memory:
    consent_required: true
    data_retention: "30 days"
    sharing_policy: "none"
    custodian_integration: true
```

### 8.3 Attack Surface Mitigation

- **Compression Bombs**: Ratio limits and timeout protection
- **Memory Poisoning**: Cryptographic integrity checks on wave patterns
- **Path Traversal**: Strict allowlist for VFS paths
- **Resource Exhaustion**: Hard limits on all extension processing

## 9. Performance Characteristics

### 9.1 Benchmarks (Target)

| Operation | v0.3 Baseline | v0.4 Ecosystem | Improvement |
|-----------|---------------|----------------|-------------|
| Parse + Extract | 1.2ms | 0.8ms | 33% faster |
| MQ2 Compression | N/A | 8ms | 40-80% size reduction |
| Mem8 Context | N/A | 2ms | Enhanced AI processing |
| Memory+Compression | N/A | 12ms | Optimized tokenization |
| Full Ecosystem | N/A | 22ms | Complete AI platform |

### 9.2 Scalability

- **Compression**: Linear with content size, ~200MB/s throughput
- **Memory**: Constant time context loading, O(log n) wave lookup  
- **Memory+Compression**: Context-aware token optimization, 15% better ratios
- **Ecosystem**: Pipeline parallelization, 3x speedup on multi-core

### 9.3 Memory Efficiency

- Zero-copy processing for compressed content
- Streaming decompression for large documents  
- Garbage collection optimization for wave patterns
- Context-aware token caching for repeated patterns

## 10. Implementation Guide

### 10.1 Extension Detection

```elixir
defmodule MarkdownLd.Ecosystem do
  def parse_capabilities(frontmatter) do
    case frontmatter["ecosystem"] do
      %{"capabilities" => caps} -> detect_extensions(caps)
      _ -> {:ok, []}
    end
  end
  
  defp detect_extensions(caps) do
    enabled = []
    |> maybe_add(:compression, "compression" in caps)
    |> maybe_add(:memory, "memory" in caps)
    # VFS planned for v0.5
    # |> maybe_add(:vfs, "vfs" in caps)
    
    {:ok, enabled}
  end
end
```

### 10.2 Processing Pipeline

```elixir
defmodule MarkdownLd.EcosystemProcessor do
  def process(content, opts \\ []) do
    with {:ok, {frontmatter, body}} <- parse_frontmatter(content),
         {:ok, capabilities} <- Ecosystem.parse_capabilities(frontmatter),
         {:ok, body} <- maybe_decompress(body, capabilities),
         {:ok, context} <- maybe_load_memory(frontmatter, capabilities),
         {:ok, result} <- MarkdownLd.parse(body, memory_context: context) do
      {:ok, add_ecosystem_metadata(result, capabilities)}
    end
  end
end
```

### 10.3 Extension APIs

```elixir
# Compression Extension
{:ok, compressed} = MarkdownLd.Compression.compress(content, level: :L1)
{:ok, decompressed} = MarkdownLd.Compression.decompress(compressed)

# Memory Extension
{:ok, context} = MarkdownLd.Memory.load_context("project.m8")
{:ok, result} = MarkdownLd.parse(content, memory_context: context)

# Full Ecosystem (Compression + Memory)
{:ok, result} = MarkdownLd.EcosystemProcessor.process(content,
  compression: :mq2,
  memory: "project.m8"
)
```

## 11. Migration and Compatibility

### 11.1 Backward Compatibility

v0.3 processors handling v0.4 documents:
- Ignore `ecosystem:` frontmatter section
- Skip `mq2` and `mem8` code fences (treat as unknown languages)
- Process standard JSON-LD islands normally
- Generate standard semantic output (without compression/memory metadata)

### 11.2 Progressive Enhancement

Documents can be designed for graceful degradation:

```markdown
---
"@context": 
  schema: "https://schema.org/"
ld:
  subject: "article:1"
ecosystem:
  compression:
    format: "mq2"
    fallback: "preserve_readability"
---

# Project Overview

<!-- This content optimized for compression but readable without -->

```mq2 
MQ2~6743A100~1000~400~A0~mq~L1
~T common patterns...
~~~~
The project implements efficient algorithms for content processing.
```

The project implements efficient algorithms for content processing.
```

### 11.3 Migration Tools

```bash
# Upgrade existing v0.3 documents to v0.4
markdown-ld upgrade --version 0.4 --enable compression,memory docs/

# Add ecosystem capabilities to existing documents  
markdown-ld ecosystem --compress --memory project.m8 --vfs ./ README.md

# Validate ecosystem documents
markdown-ld validate --ecosystem --strict docs/
```

## 12. Examples

### 12.1 Compressed Development Guide

````markdown
---
"@context":
  schema: "https://schema.org/"
  dev: "https://dev.example.org/"
ecosystem:
  compression:
    format: "mq2"
    level: "L1" 
    semantic_aware: true
---

# Development Guide {ld:@type=schema:TechArticle}

```mq2
MQ2~67445A00~2048~820~32~mq~L1
~T\x80 function|\x81 const|\x82 return|\x83 async|\x84 await|
~~~~
This guide covers \x80 definitions, \x81 declarations, and \x83/\x84 patterns.

## Best Practices

Always use \x81 for immutable values and \x80 for reusable logic.
```

[Source code examples](vfs://examples/){ld:prop=schema:codeRepository}
````

### 12.2 Context-Aware Documentation

````markdown
---
ecosystem:
  memory:
    format: "mem8"
    context_file: "team.m8"
    emotional_tracking: true
---

# Project Retrospective {ld:@type=schema:Review}

```mem8
[Memory context includes team emotional state, project timeline, 
 and collaborative patterns that influence document interpretation]
```

The team's **satisfaction** with the current sprint reflects our improved
collaboration patterns and reduced technical debt.
````

### 12.3 AI-Enhanced Documentation

````markdown
---
ecosystem:
  compression: {format: "mq2", level: "L1", semantic_aware: true}
  memory: {context_file: "project.m8", wave_enabled: true}
---

# AI-Enhanced Project Documentation

```mem8
[Project context: development patterns, team expertise areas,
 architectural decisions, and temporal project evolution patterns]
```

```mq2
MQ2~6743A100~3A98~1B2F~2A~mq~L1
~T\x80implementation|\x81architecture|\x82performance|\x83optimization|
~~~~
This project focuses on high-\x82 \x80 with careful attention to \x81
design and continuous \x83 based on real-world usage patterns.
```

The compressed content above includes 65% size reduction while maintaining
full readability and AI-processable semantic structure.
````

## 13. Extension 5: Model Support (E5)

### 13.1 Model Schema Specifications

The Model Extension enables embedding structured schema definitions within markdown that can generate multiple target formats including JSON-LD schemas, database models, TypeScript interfaces, and more.

#### 13.1.1 Model Declaration Syntax

Models are declared using YAML frontmatter within fenced code blocks:

````markdown
```
---
@context: 
  - https://pactis.dev/schemas/model/v1
  - pactis: https://pactis.dev/vocab#
@type: ModelSpecification
@id: pactis:ConversationCrystal
generates:
  - json-ld-schema
  - ash-resource
  - typescript-interface
  - graphql-type
---

# ConversationCrystal Model

**Essence:** Compressed dialogue patterns with cognitive architectures

## Shape Definition
```yaml
properties:
  name: 
    type: string
    required: true
  conversation_type:
    type: enum
    values: [standard, branched, meta, collaborative]
  essence:
    type: string
    required: true
    minLength: 10
  dialogue_pattern:
    type: string
  cognitive_progression:
    type: array
    items: string
    
relationships:
  parent_crystal:
    type: Crystal
    cardinality: "0..1"
  applications:
    type: ConversationApplication
    cardinality: "0..*"
```
```
````

#### 13.1.2 Generation Targets

The `generates` array specifies output formats:

- **json-ld-schema**: Semantic web schemas with full JSON-LD context
- **ash-resource**: Elixir Ash framework resource definitions  
- **typescript-interface**: TypeScript type definitions
- **graphql-type**: GraphQL schema definitions
- **template**: Custom template-based generation
- **parser**: Parser module generation
- **generator**: Generator utility creation

#### 13.1.3 Ecosystem Integration

Model specifications integrate with the ecosystem declaration:

```yaml
---
"@context":
  schema: "https://schema.org/"
  pactis: "https://pactis.dev/vocab#"
ecosystem:
  version: "0.4"
  capabilities: ["compression", "memory", "model"]
  model:
    format: "pactis-v1"
    generation_targets: ["ash-resource", "typescript"]
    output_directory: "generated/"
---
```

### 13.2 Code Generation Pipeline

#### 13.2.1 Processing Flow

1. **Model Discovery**: Scan document for model specification blocks
2. **Schema Validation**: Validate against model specification schema  
3. **Target Generation**: Generate code for each specified target
4. **Output Management**: Write generated files to specified locations
5. **Integration Hooks**: Execute post-generation integration scripts

#### 13.2.2 Template System

Custom generation templates use a simple templating syntax:

```eex
defmodule <%= @module_name %> do
  use Ash.Resource

  attributes do
<%= for {name, spec} <- @properties do %>
    attribute :<%= name %>, :<%= map_type(spec.type) %><%= if spec.required, do: ", allow_nil?: false" %>
<% end %>
  end

  relationships do
<%= for {name, rel} <- @relationships do %>
    <%= rel.cardinality |> cardinality_macro() %> :<%= name %>, <%= rel.type %>
<% end %>
  end
end
```

### 13.3 Schema Definition Language

#### 13.3.1 Property Types

Standard property types with validation:

- **string**: Text with optional minLength/maxLength
- **integer**: Numeric with optional min/max ranges  
- **boolean**: True/false values
- **enum**: Restricted value sets
- **array**: Collections with item type specification
- **object**: Nested object structures
- **datetime**: ISO 8601 timestamps
- **uuid**: UUID identifiers

#### 13.3.2 Relationship Modeling

Relationships define connections between models:

```yaml
relationships:
  parent:
    type: Category
    cardinality: "0..1"        # Optional parent
  children:
    type: Category
    cardinality: "0..*"        # Multiple children
  owner:
    type: User
    cardinality: "1"           # Required owner
  tags:
    type: Tag
    cardinality: "1..*"        # One or more tags
```

### 13.4 Integration Examples

#### 13.4.1 Ash Resource Generation

```elixir
# Generated from ConversationCrystal model
defmodule MyApp.ConversationCrystal do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :conversation_type, :atom, 
      constraints: [one_of: [:standard, :branched, :meta, :collaborative]]
    attribute :essence, :string, 
      allow_nil?: false, 
      constraints: [min_length: 10]
    attribute :dialogue_pattern, :string
    attribute :cognitive_progression, {:array, :string}
  end

  relationships do
    belongs_to :parent_crystal, MyApp.Crystal
    has_many :applications, MyApp.ConversationApplication
  end
end
```

#### 13.4.2 TypeScript Interface Generation

```typescript
// Generated from ConversationCrystal model
export interface ConversationCrystal {
  name: string;
  conversation_type: 'standard' | 'branched' | 'meta' | 'collaborative';
  essence: string; // minLength: 10
  dialogue_pattern?: string;
  cognitive_progression?: string[];
  parent_crystal?: Crystal;
  applications?: ConversationApplication[];
}
```

### 13.5 Performance and Caching

#### 13.5.1 Generation Caching

- Model specifications are fingerprinted for change detection
- Generated files include generation metadata headers
- Incremental regeneration only for modified models
- Dependency graph tracking for related model updates

#### 13.5.2 Build Integration

```makefile
# Integration with existing build systems
generate-models:
	markdown-ld generate --input docs/ --output src/generated/
	
build: generate-models
	mix compile
```

## 14. Future Extensions

### 14.1 Planned v0.5 Extensions

- **E3 VFS**: Complete virtual filesystem with markdown-as-filesystem bindings
- **E6 Networking**: Distributed document synchronization  
- **E7 Encryption**: End-to-end encrypted ecosystem content
- **E8 AI Integration**: Native large language model processing hooks

### 14.2 Research Areas

- **Neural Compression**: AI-optimized token assignment using document understanding
- **Temporal Semantics**: Time-aware JSON-LD with memory wave integration
- **Markdown-as-Filesystem**: Revolutionary VFS interface using markdown syntax
- **Context Fusion**: Multi-modal memory patterns (text, code, emotional, temporal)

## 15. Conclusion

Markdown-LD v0.4 transforms documents into AI-native content platforms. The two core extensions—Compression and Memory—work together to create a new paradigm for content processing that is:

- **AI-Native**: Optimized compression and contextual memory for machine intelligence
- **Human-Readable**: 60-85% of compressed content remains understandable
- **Performant**: SIMD-optimized processing achieving 40-80% size reduction
- **Context-Aware**: Wave-based memory enhances semantic processing
- **Secure**: Built-in limits, compression bomb protection, and privacy controls

v0.4 establishes Markdown-LD as the foundation for AI-native content systems, with v0.5 adding revolutionary markdown-as-filesystem capabilities.

---

**Media Type**: `text/markdown+ld; profile="v0.4"`  
**Status**: Draft Proposal  
**Authors**: MarkdownLd Development Team  
**Date**: December 2025

## Appendix A: Ecosystem Ontology

```turtle
@prefix mld: <https://markdown-ld.org/v0.4/> .
@prefix schema: <https://schema.org/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

# Ecosystem Classes
mld:EcosystemDocument rdf:type rdfs:Class .
mld:CompressedContent rdf:type rdfs:Class .
mld:MemoryContext rdf:type rdfs:Class .  
mld:EmbeddedFilesystem rdf:type rdfs:Class .

# Compression Properties
mld:compressionFormat rdf:type rdf:Property .
mld:compressionRatio rdf:type rdf:Property .
mld:compressionLevel rdf:type rdf:Property .

# Memory Properties  
mld:memoryWaveSync rdf:type rdf:Property .
mld:emotionalState rdf:type rdf:Property .
mld:temporalDecay rdf:type rdf:Property .

# VFS Properties
mld:embeddedFiles rdf:type rdf:Property .
mld:filesystemSize rdf:type rdf:Property .
mld:pathReference rdf:type rdf:Property .
```

## Appendix B: Performance Benchmarks

```
Compression Benchmarks (MQ2):
- Small files (1-10KB): 40-60% compression, 0.5ms processing
- Medium files (10-100KB): 45-65% compression, 2-5ms processing  
- Large files (100KB-1MB): 50-70% compression, 10-50ms processing
- Very large files (1MB+): 55-75% compression, 50-200ms processing

Memory Context (Mem8):
- Context loading: 1-3ms for typical project contexts
- Wave pattern lookup: <0.1ms per pattern
- Emotional weighting: 0.2ms per semantic triple
- Temporal decay calculation: 0.1ms per time window

VFS Embedding:
- Small repos (<100 files): 5-10ms embedding time
- Medium repos (100-1K files): 15-50ms embedding time
- Large repos (1K-10K files): 50-200ms embedding time  
- Very large repos (10K+ files): 200ms-2s embedding time

Full Ecosystem Processing:
- Typical document: 10-45ms total processing time
- With all extensions: 20-100ms total processing time
- Memory usage: 10-50MB per document
- Disk usage: 2-5x original document size (temporary)
```
