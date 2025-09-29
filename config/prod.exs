import Config

# Production environment configuration
config :logger, level: :info

# Production-specific settings
config :markdown_ld,
  debug_mode: false,
  verbose_logging: false,
  performance_monitoring: true

# Enable telemetry for monitoring
config :telemetry,
  disable_default_metrics: false,
  enable_vm_metrics: true
