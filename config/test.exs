import Config

# Test environment configuration
config :logger, level: :warn

# Test-specific settings
config :markdown_ld,
  debug_mode: false,
  verbose_logging: false,
  test_mode: true

# Disable telemetry in tests
config :telemetry, :disable_default_metrics, true
