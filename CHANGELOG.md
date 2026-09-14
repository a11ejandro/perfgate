## [Unreleased]

- Replace p-value-driven comparisons with Bonferroni-adjusted bootstrap
  intervals and directional minimum-effect rules; retain Mann-Whitney only as
  a named diagnostic and correct its tie variance.
- Add evidence-contract v2 with assurance claims, expanded provenance,
  experiment/analysis/policy snapshots, observation metadata, exclusions,
  exact decision rules, sample counts, reproduction commands, and JSON Schemas.
- Propagate underpowered, missing, unstable, empty, and execution-error evidence
  as INCONCLUSIVE or INCOMPARABLE instead of allowing an overall PASS.
- Add stale-baseline enforcement, comparison digests, effective CLI overrides,
  deterministic workload filtering/order, and fail-fast execution.
- Default policy to advisory; direct CI blocking now requires explicit
  `policy.mode: blocking` after environment-specific calibration.

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
