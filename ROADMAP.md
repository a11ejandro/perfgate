# Roadmap

This roadmap tracks work toward a public gem release and beyond. Items within
each phase are roughly prioritized; the order within a phase is not fixed.

Status key: ✅ done · 🚧 in progress · ⬜ not started

---

## Phase 1 — Implemented (MVP core)

✅ `baselined run` — discovers `:baseline`-tagged RSpec examples, runs warmups
   + measured samples in subprocess isolation, writes a versioned JSON result bundle

✅ `baselined compare` — loads two result bundles, validates fingerprint
   compatibility, produces per-workload PASS/WARN/FAIL/INCOMPARABLE decisions,
   saves a comparison result, exits with CI-meaningful codes

✅ Instrumentation — wall-clock duration (monotonic), SQL query count and
   cumulative duration (ActiveSupport::Notifications), Ruby object allocations
   (GC.stat delta), GC activity

✅ Statistics — Mann-Whitney U with tie correction, extended summary
   (min/p50/p95/p99/max/count)

✅ Fingerprinting — environment fingerprint (Ruby version, Rails version,
   platform, dataset version) + per-workload definition hash; compatibility
   engine that blocks incomparable runs

✅ Regression policy — statistical + practical-floor dual guard; noise-ratio
   downgrade; deterministic SQL comparison; configurable thresholds

✅ Console and Markdown reporters — table-format console output; GitHub-flavored
   Markdown for job summaries and PR comments

✅ `baseline run --compare PATH --format markdown` — one-step CI command

✅ Portable archives — `export_archive`/`import_archive` for `.tar.gz` artifact
   hand-off between CI jobs; path-traversal rejection on import

✅ GitHub Actions example workflow — upload/download artifact pattern for
   default-branch → PR comparison

✅ Docs — CONTRIBUTING, SECURITY, compatibility matrix, telemetry contract,
   onboarding guide

---

## Phase 2 — Pre-release polish

⬜ `baselined init` — scaffold `baseline.yml` with commented defaults and an
   example workload block; the spec describes it but it is not yet built

⬜ `baselined doctor` — pre-flight check: Ruby/Rails version, RSpec integration
   presence, storage directory writability, config validity

⬜ `baselined schema` — print the canonical JSON Schema for run-result or
   comparison-result to stdout; useful for tooling integration

⬜ `baselined report` — re-render a saved comparison result in any supported
   format without re-running workloads

⬜ Expanded CI matrix — test against Ruby 3.2/3.3/3.4 and
   Rails 7.1/7.2/8.0 in CI (currently only Ruby 3.2.2 + SQLite)

⬜ PostgreSQL and MySQL smoke tests — verify SQL instrumentation behaves
   identically across adapters

⬜ RubyGems.org release — cut `v0.1.0`, add gem badge to README, publish
   to rubygems.org

---

## Phase 3 — Developer experience

⬜ `baseline accept` — mark a known-regression comparison as accepted so the
   next default-branch run becomes the new reference without manual file moves

⬜ Per-workload threshold overrides in `baseline.yml` — allow tighter or
   looser thresholds for specific workload IDs

⬜ Memory delta metric (opt-in) — process RSS delta per sample; gated behind
   `metrics.memory: true` because RSS is noisy on most platforms

⬜ Sidekiq adapter — first-class `Baselined.measure { MyWorker.drain }` helper
   that suppresses Sidekiq's own threading and logging noise

⬜ VS Code / RubyMine run-configuration snippets in the example app

⬜ Interactive `baseline run --watch` for local iteration

---

## Phase 4 — Ecosystem and integrations

⬜ GitHub PR comment integration — post or update a comparison summary comment
   on the PR (requires a GitHub token; strictly opt-in)

⬜ Telemetry (opt-in) — anonymous, privacy-preserving usage data; schema and
   contract already documented in `docs/telemetry.md`; no data is sent until
   this is built and the user opts in

⬜ Minitest adapter — extend discovery and execution to work with Minitest
   test suites

⬜ GitLab CI / Bitbucket Pipelines example workflows

⬜ SARIF output format — machine-readable regression report for GitHub
   Advanced Security or similar tooling

---

## Out of scope (MVP and foreseeable future)

These are explicitly not on the roadmap for the open-source gem:

- Baseline Cloud / hosted dashboards / long-term history
- User accounts or billing
- Multi-repository analytics
- Production APM or continuous profiling
- Automatic workload discovery (without explicit `:baseline` tag)
- Browser / E2E measurement
- Distributed or concurrency load testing
- AI-generated diagnoses or automatic code attribution
- Non-Ruby languages
