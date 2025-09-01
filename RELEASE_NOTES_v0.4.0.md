# MarkdownLd v0.4.0

Highlights
- Optional JSON‑LD backend: `jsonld_ex` with safe fallback to internal expander
- Single‑pass JSON‑LD extractor with fast‑path skip for non‑JSON‑LD docs
- Literal metadata (language/datatype) preserved; tables support lists and typed values
- Telemetry hooks + aggregator and microbench task for performance tracking
- rustler_precompiled integration + CI to publish multi‑target NIF artifacts
- Spec workflow hardening (path safety, schema lint, deterministic thread)

Upgrade Notes
- No breaking API changes to `MarkdownLd.parse*` or extractor functions
- To enable `jsonld_ex`, add the optional dependency and set:
  - `config :markdown_ld, jsonld_backend: :jsonld_ex`
- To enable telemetry, set:
  - `config :markdown_ld, track_performance: true`

Perf Validation
- CI: “JSON‑LD Perf Smoke” compares internal vs jsonld_ex backends
- Local: `mix spec.perf.jsonld --dir doc --glob '**/*.md' --telemetry true`
