# Architecture

Baseline is a layered pipeline: each layer has a single responsibility and hands
off a well-typed value to the next. No layer reaches backwards.

```
RSpec examples
     │
     ▼
┌─────────────┐
│  Discovery  │  rspec/discovery.rb, rspec/workload_builder.rb
│             │  Finds :baseline-tagged examples; builds Workload objects
└──────┬──────┘
       │  []Workload
       ▼
┌─────────────┐
│  Execution  │  execution/runner.rb, execution/process_runner.rb
│             │  Warmup → measured samples; isolates each run in a subprocess
└──────┬──────┘
       │  raw sample arrays (ns integers)
       ▼
┌──────────────────┐
│ Instrumentation  │  instrumentation/{duration,sql_activity,allocations,gc}.rb
│                  │  Wraps Baselined.measure { } with collectors for each metric
└────────┬─────────┘
         │  SampleContext per metric
         ▼
┌────────────────┐
│  Statistics    │  statistics/{summary,mann_whitney_u}.rb
│                │  min/p50/p95/max; Mann-Whitney U for regression significance
└───────┬────────┘
        │  Summary structs
        ▼
┌──────────────────┐
│  Fingerprints    │  fingerprints/{components,workload_definition,compatibility}.rb
│                  │  Environment + workload hashes; compatibility gate that blocks
│                  │  incomparable runs before any metric decision is made
└────────┬─────────┘
         │  FingerprintResult
         ▼
┌──────────────────────┐
│  Comparison::Engine  │  comparison/{engine,workload_comparison,metric_decision,
│                      │  statistical_metric_decision,deterministic_metric_decision,
│                      │  diagnostics}.rb
│                      │
│  Per-metric:         │  Duration/allocations → statistical (Mann-Whitney + floor)
│                      │  SQL count            → deterministic (exact delta)
│                      │  GC                   → informational only
└──────────┬───────────┘
           │  ComparisonResult
           ▼
┌──────────────────┐
│  Policy::Engine  │  policy/engine.rb
│                  │  Maps workload-level PASS/WARN/FAIL/INCOMPARABLE →
│                  │  overall status + exit code (0–5 per spec §21)
└──────────┬───────┘
           │  PolicyResult (status, exit_code)
           ▼
┌──────────────────┐
│  Report          │  report/{console,markdown}.rb
│                  │  Human-readable console table or GitHub-flavored Markdown
└──────────┬───────┘
           │  String
           ▼
        stdout / summary.md

────────────────────────────────────────────────────────
Cross-cutting concerns (not in the pipeline)
────────────────────────────────────────────────────────

Config          config/{schema,validator,defaults,env_overrides}.rb
                Single Config object loaded once; env vars layer on top of YAML.

Storage         storage/{adapter,filesystem,archive}.rb
                Filesystem adapter writes versioned JSON bundles.
                import/export_archive produce .tar.gz for CI artifact hand-off.

Serialization   serialization/run_result.rb
                RunResult ↔ JSON; forwards-compatible with schema versioning.

CLI             cli/{run_command,compare_command,run_comparison_reporter}.rb
                Thin dispatcher; each subcommand is a callable object.
                `baseline run --compare PATH --format markdown` is the canonical
                one-step CI command.

Errors          errors.rb
                Typed error hierarchy; CLI maps each class to an exit code.
```

## Key design decisions

**Subprocess isolation.** Each workload runs in a forked child process (or a
fresh subprocess when fork is unavailable). This prevents metric leakage between
workloads and matches the Rails parallel-test-runner constraint that SQLite
requires a file-backed database.

**Fingerprint-first.** Compatibility is checked before any metric comparison. If
the environment fingerprint is incompatible the whole comparison is INCOMPARABLE;
if an individual workload's definition changed it is flagged as modified. This
prevents silent comparisons across incompatible runs.

**Two comparison strategies.** Continuous metrics (duration, allocations) use
Mann-Whitney U so random OS noise does not produce false alarms. SQL query count
is deterministic — it should not vary between runs on the same code, so any
change is significant.

**Practical floor beats statistics alone.** A statistically-significant
difference that is smaller than `minimum_absolute_ms` (default 10 ms) is
downgraded from FAIL to WARN. A sub-noise-ratio change is downgraded further
to PASS. This prevents microscopic regressions from blocking PRs.

**One source of truth for thresholds.** `baseline.yml` controls every
comparison and policy knob. Environment variables may override values for CI
parameterisation but cannot introduce new keys.

## Adding a new metric

1. Add a collector in `instrumentation/` that captures `before`/`after` values
   and returns a delta in `SampleContext`.
2. Register it in `Instrumentation` and add it to `RunResult`'s schema.
3. Choose a comparison strategy (statistical or deterministic) and add a rule
   to `Comparison::Engine`.
4. Add a policy threshold key to `Config::Schema` with a safe default that
   makes the metric informational-only until the user opts in.
5. Update `Report::Console` and `Report::Markdown` to surface it.
