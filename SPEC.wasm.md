# Markdown-LD - WASM Modules (L3 Optional)

Status: Optional sidecar for embedding WebAssembly modules and configs in Markdown without raw HTML. Intended for sandboxed, deterministic clients (e.g., terminal/TUI renderers). No execution implied by the spec; execution is renderer policy.

## 1. Goals
- Carry WASM binaries and configs as fenced blocks (no raw < > in markdown).
- Deterministic identity and diff via content hashes (JCS + SHA-256).
- Safe-by-default: execution disabled unless explicitly permitted by policy.

## 2. Fences
- Module: ```application/wasm {ldw:module=<id> ldw:entry=_start ldw:wasi=true|false ldw:policy=disabled|sandboxed|trusted}
  <base64 wasm bytes>
  ```
- Config (optional): ```application/wasm+json {ldw:config-for=<id>}
  {"imports": {"env": {"now_ms": "host_fn"}}, "limits": {"memory_mb": 64, "cpu_ms": 1000}}
  ```

Rules
- `ldw:module` is author-chosen stable ID (unique in doc).
- Hash: `sha256(wasm_bytes)`; `module_id = sha256(jcs({id, entry, wasi, hash}))[:12]` for deterministic detection.
- Config is JSON and canonicalized via JCS for hashing.
- Execution policy: default `disabled`. `sandboxed` allows instantiation in a WebWorker/WASI shim with no network; `trusted` is implementation-defined but MUST still enforce memory/time limits.

## 3. Diff Semantics
- Add/remove modules by `ldw:module`.
- Update when either `hash` (binary) or config hash changes.
- Config-only change emits update with `before/after` hashes.

## 4. Determinism
- Use RFC 8785 JCS for config hashing and identity payloads.
- WASM binary hash is `sha256(bytes)`; do not re-encode base64 for hash.

## 5. Security
- No network or filesystem access in sandboxed mode.
- Memory/time limits enforced by host; abort on overrun.
- No DOM access; run in Worker with message passing; optional OffscreenCanvas only when explicitly allowed.

## 6. Terminal Integration (non-normative)
- ABI: host provides imports `term_write(ptr,len)`, `term_resize(cols,rows)`, `now_ms()`; module exports `on_input(ptr,len)`, optional `_start`.
- For RIO-in-WASM experiments, use `wasm32-unknown-unknown` or WASI with a JS/WASM shim; pin engine versions for reproducibility.

