## Overview

* Project semantic context (original MEM8)
* Directory structures (Smart Tree Quantum)
* Reactive memory snapshots
* Wave memory vectors
* Emotional history curves

## File Naming Convention

```
project.m8          # Main project summary
README.m8           # Compressed README
CHANGELOG.m8        # Compressed changelog
src/module.m8       # Module-specific context
.cache/deps.m8      # Dependency graph
```

## Unified Binary Structure

```
[0-15]  Standard MEM8 Header
[16-N]  Section Table
[N+1-]  Section Data
```

### Section Types

| Code   | Name               | Description                                    |                |
| ------ | ------------------ | ---------------------------------------------- | -------------- |
| `0x01` | Identity           | Project identity and metadata                  |                |
| `0x02` | Context            | Semantic and architectural context             |                |
| `0x03` | Structure          | File tree or component layout                  |                |
| `0x04` | Compilation        | Build metadata or recipes                      |                |
| `0x05` | Cache              | Temporary or derivable content                 |                |
| `0x06` | AI Context         | Persona overlays, goals, traits                |                |
| `0x07` | Relationships      | Symbolic/cognitive links                       |                |
| `0x08` | Sensor Arbitration | Sensor weightings, override thresholds         |                |
| `0x09` | Markdown-LD        | Compressed markdown-ld (quantized)             |                |
| `0x0A` | Quantum Tree       | Directory structure snapshot                   |                |
| `0x0B` | Code Relations     | Symbol graph, call trees, etc.                 |                |
| `0x0C` | Build Artifacts    | Binaries, WASM, bytecode                       |                |
| `0x0D` | Temporal Index     | Wave timestamps and decay windows              |                |
| `0x0E` | Collective Emotion | Group affect curves over time                  |                |
| `0x0F` | WaveMemoryBlob     | Compressed 32-byte wave memory patterns        |                |
| `0x10` | ReactiveStateDump  | Layers 0–3 of MEM                              | 8 active stack |
| `0x11` | CustodianNotes     | Ethical flags, trauma markers, decay overrides |                |

## Magic Detection

```rust
match first_4_bytes {
    b"MEM8" => {
        if has_section(0x09) { /* Markqant */ }
        if has_section(0x0A) { /* Tree */ }
        if has_section(0x0F) { /* Wave memory */ }
    }
    b"MARK" => migrate_to_m8()
    _ => attempt_fallback_parse()
}
```

## Advantages

1. **One format, many minds**: Structure + emotion + cognition in one file
2. **Composable memory**: Wave memory, timeline, emotion = context
3. **Custodian-integrated**: Native safety & trauma-flagging support
4. **Retroactive updates**: Add new sections over time
5. **Optimized for AI**: Quantized, readable, searchable

## Roadmap

* `0x12`: Procedural Storylines
* `0x13`: Sensory Snapshots (raw image/audio segments)
* `0x14`: Memory Reinforcement Logs
* `0x15`: Mesh-Linked Memory Index
