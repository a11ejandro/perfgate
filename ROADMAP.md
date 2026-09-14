# Roadmap

This roadmap tracks work toward a public gem release and beyond. Items within
each phase are roughly prioritized; the order within a phase is not fixed.

Status key: ✅ done · 🚧 in progress · ⬜ not started

---

## Phase 1 — Implemented (MVP core)

✅ `perfgate run` — discovers `:perfgate`-tagged RSpec examples, runs warmups
   + measured samples in subprocess isolation, writes a versioned JSON result bundle

✅ `perfgate compare` — loads two result bundles, validates fingerprint
   compatibility, produces per-workload PASS/WARN/FAIL/INCOMPARABLE decisions,
   saves a comparison result, exits with CI-meaningful codes

✅ Instrumentation — wall-clock duration (monotonic), SQL query count and
   cumulative duration (ActiveSupport::Notifications), Ruby object allocations
   (GC.stat delta), GC activity

✅ Statistics — independent bootstrap interval for median change, directional
   MEI decisions, Bonferroni family adjustment, Mann-Whitney diagnostic with tie
   correction, extended robust summaries

✅ Fingerprinting — runtime/database/lockfile/schema/instrumentation/dataset
   provenance + source-aware per-workload definition hash; missing strict
   provenance and stale baselines are incomparable

✅ Regression policy — five evidence outcomes, exact recorded rule, advisory
   default, explicit blocking opt-in, and deterministic SQL comparison only
   after within-run stability is established

✅ Evidence contract v2 — raw observations with order/timestamps/status,
   assurance claim/owner/dataset/directions/MEIs, experiment and analysis plans,
   policy snapshot, reproduction command, and comparison digests

✅ Console and Markdown reporters — table-format console output; GitHub-flavored
   Markdown for job summaries and PR comments

✅ `perfgate run --compare PATH --format markdown` — one-step CI command

✅ Portable archives — `export_archive`/`import_archive` for `.tar.gz` artifact
   hand-off between CI jobs; path-traversal rejection on import

✅ GitHub Actions example workflow — upload/download artifact pattern for
   default-branch → PR comparison

✅ Docs — CONTRIBUTING, SECURITY, compatibility matrix, telemetry contract,
   onboarding guide

---

## Phase 2 — Pre-release polish

⬜ `perfgate init` — scaffold `perfgate.yml` with commented defaults and an
   example workload block; the spec describes it but it is not yet built

⬜ `perfgate doctor` — pre-flight check: Ruby/Rails version, RSpec integration
   presence, storage directory writability, config validity

⬜ `perfgate schema` — print the canonical JSON Schema for run-result or
   comparison-result to stdout; useful for tooling integration

⬜ `perfgate report` — re-render a saved comparison result in any supported
   format without re-running workloads

⬜ Expanded CI matrix — test against Ruby 3.2/3.3/3.4 and
   Rails 7.1/7.2/8.0 in CI (currently only Ruby 3.2.2 + SQLite)

⬜ PostgreSQL and MySQL smoke tests — verify SQL instrumentation behaves
   identically across adapters

⬜ RubyGems.org release — cut `v0.1.0`, add gem badge to README, publish
   to rubygems.org

---

## Phase 3 — Developer experience

⬜ Same-worker randomized-block and interleaved control/candidate reference
   designs, with paired estimators and carryover reset hooks

⬜ Calibration command and retained A/A/injected-regression decision curves for
   false-decision rate, rerun stability, and power at each declared MEI

⬜ `perfgate accept` — mark a known-regression comparison as accepted so the
   next default-branch run becomes the new reference without manual file moves

⬜ Per-workload threshold overrides in `perfgate.yml` — allow tighter or
   looser thresholds for specific workload IDs

⬜ Memory delta metric (opt-in) — process RSS delta per sample; gated behind
   `metrics.memory: true` because RSS is noisy on most platforms

⬜ Sidekiq adapter — first-class `Perfgate.measure { MyWorker.drain }` helper
   that suppresses Sidekiq's own threading and logging noise

⬜ VS Code / RubyMine run-configuration snippets in the example app

⬜ Interactive `perfgate run --watch` for local iteration

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

- Perfgate Cloud / hosted dashboards / long-term history
- User accounts or billing
- Multi-repository analytics
- Production APM or continuous profiling
- Automatic workload discovery (without explicit `:perfgate` tag)
- Browser / E2E measurement
- Distributed or concurrency load testing
- AI-generated diagnoses or automatic code attribution
- Non-Ruby languages
