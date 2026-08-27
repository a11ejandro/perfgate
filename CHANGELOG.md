## [Unreleased]

## [0.1.0] - 2026-08-26

- Core execution engine: CLI, configuration loader, RSpec discovery
  via `perfgate: true` metadata, `Perfgate.measure`, process-isolated
  warmup/samples, and a filesystem result bundle.
- Rails metrics: SQL query count/duration, allocations, and GC
  diagnostics, correctly isolated to the measurement block.
- Comparison and policy: execution fingerprints, a compatibility
  engine, Mann-Whitney statistics, practical thresholds, PASS/WARN/FAIL
  decisions with CI exit codes, and regression-injection test coverage.
- CI experience: deterministic diagnostics, console and Markdown
  reports, `perfgate run --compare/--format` for a single-step CI
  comparison, portable `perfgate-run-<run-id>.tar.gz` archives, and a
  documented GitHub Actions workflow.
- Release readiness: security policy, contribution guide,
  compatibility matrix, and telemetry specification.
