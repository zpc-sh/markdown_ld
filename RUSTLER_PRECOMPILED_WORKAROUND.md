# Rustler Precompiled Is Broken - Just Don't Use It 🚫

## The Problem

Getting this error? You're not alone:

```
Error while downloading precompiled NIF: the precompiled NIF file does not exist in the checksum file
```

The `rustler_precompiled` system is fundamentally broken - one missing platform build, one checksum mismatch, and your entire dependency tree explodes. This affects `jsonld_ex` and many other Rust-based Elixir libraries.

## The Solution ✨

**Don't use rustler_precompiled at all.** Just remove it and build from source - it's more reliable, simpler, and faster to debug.

### Remove rustler_precompiled from your `mix.exs`:

```elixir
defp deps do
  [
    {:rustler, "~> 0.34.0", runtime: false},
    # {:rustler_precompiled, "~> 0.8"}, # <- DELETE THIS LINE
    # ... your other deps
  ]
end
```

That's it. No configs, no workarounds, no force_build flags. Just pure Rustler building from source.

## Why This Works 🎯

- **Reliable**: Source builds always work if you have the toolchain
- **Simple**: No configs, no workarounds, no broken download systems
- **Future-proof**: Never breaks when upstream forgets to build for your platform
- **Fast enough**: Modern machines compile Rust NIFs in seconds
- **Transparent**: You see exactly what's being built
- **Secure**: No trusting random precompiled binaries

## Prerequisites

Make sure you have:
- **Rust toolchain**: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs/ | sh`
- **Build tools**:
  - macOS: `xcode-select --install`
  - Ubuntu/Debian: `apt-get install build-essential`
  - Alpine: `apk add build-base`

## Alternative: Keep rustler_precompiled (Not Recommended)

If you really want to keep the broken system and force build everything:

```elixir
# config/config.exs
config :rustler_precompiled, :force_build, :all
```

But honestly, just remove the dependency entirely. You don't need it.

## Docker/CI Considerations

In Docker or CI environments, make sure to:

1. Install build tools in your base image
2. Cache the `~/.cargo` directory to speed up builds
3. Use multi-stage builds if you want smaller production images

Example Dockerfile snippet:
```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs/ | sh -s -- -y \
    && . ~/.cargo/env
```

## Share the Love 💝

If this fixes your build, spread the word: **rustler_precompiled is optional and often harmful.**

Most experienced Elixir/Rust developers build from source anyway. The precompiled route is a trap for newcomers who don't want to install build tools, but then get stuck when the system inevitably breaks.

## Why Not Fix the Checksums?

You could try to fix individual checksum files, but:
- It's whack-a-mole - new versions break again
- You don't control upstream release processes  
- Platform-specific issues are impossible to debug
- Downloads can fail for corporate proxies, CI environments, etc.
- The whole system adds complexity for marginal benefit

**Just delete the dependency.** Build tools are part of development - embrace them! 🚀

## The Real Talk

rustler_precompiled promises convenience but delivers:
- ❌ Mysterious download failures
- ❌ Checksum mismatch hell
- ❌ Missing platform binaries
- ❌ Network dependencies during compilation
- ❌ Trust issues with random precompiled binaries

Pure Rustler delivers:
- ✅ Builds that always work (if you have Rust installed)
- ✅ Full transparency of what's being compiled
- ✅ No network dependencies
- ✅ Platform independence
- ✅ Better security posture

The choice is obvious. 🎯
