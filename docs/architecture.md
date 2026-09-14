# Architecture

Perfgate is a layered pipeline: each layer has a single responsibility and hands
off a well-typed value to the next. No layer reaches backwards.

```
RSpec examples
     │
     ▼
┌─────────────┐
│  Discovery  │  rspec/discovery.rb, rspec/workload_builder.rb
│             │  Finds :perfgate-tagged examples; builds Workload objects
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
│                  │  Wraps Perfgate.measure { } with collectors for each metric
└────────┬─────────┘
         │  SampleContext per metric
         ▼
┌────────────────┐
│  Statistics    │  statistics/{summary,bootstrap_interval,mann_whitney_u}.rb
│                │  robust summaries; bootstrap effect interval; rank-test diagnostic
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
│  Per-metric:         │  Duration/allocations → interval + directional MEI
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
                `perfgate run --compare PATH --format markdown` is the canonical
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

**Two comparison strategies.** Continuous metrics (duration, SQL duration, and
allocations) use a deterministic independent-sample bootstrap interval for the
difference in medians. The reported Mann-Whitney p-value is diagnostic and does
not drive the decision. SQL query count uses an exact rule only when every
observation within each run is identical; otherwise its result is INCONCLUSIVE.

**Intervals and practical materiality are one rule.** PASS requires the upper
interval bound to exclude the warning MEI. FAIL requires the lower bound to
exceed the failure MEI. Overlap becomes WARN when the point estimate is
material and INCONCLUSIVE otherwise. Thresholds are directional, so an
improvement never becomes a regression because its absolute magnitude is
large. Bonferroni adjustment controls the configured family-wise confidence
across stochastic metrics in a comparison.

**Advisory before blocking.** Evidence and organizational policy are separate.
The default policy preserves a FAIL evidence state but returns a non-blocking
WARN until `policy.mode: blocking` is explicitly selected after workload- and
environment-specific validation.

**Reference-design limitation.** Version 2 evidence declares the implemented
`historical_stored_baseline` design, preserves observation order/timestamps,
and rejects stale or incompatible references. Same-worker randomized blocks
and interleaved control/candidate execution remain future work.

**One source of truth for thresholds.** `perfgate.yml` controls every
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
