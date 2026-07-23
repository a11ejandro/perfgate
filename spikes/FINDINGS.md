# Milestone 0 — Technical Validation Findings

Local spikes only (this machine, not a GitHub-hosted runner — see the
"deferred" note at the bottom). Scripts live in `spikes/` and are throwaway,
not part of the gem's public API.

## Exit criterion (spec section 28)

> The team can detect a seeded 20% duration regression and an added SQL
> query with an acceptably low false-positive rate.

**Met, on this machine, for these synthetic workloads.** See details below.

## 1. Duration measurement (`spikes/duration_measurement.rb`)

- `Process.clock_gettime(Process::CLOCK_MONOTONIC)` gives a clean, low-noise
  signal for a small synthetic workload (~2.4ms) after 5 warmup iterations.
- Coefficient of variation: ~2.5–3.5% across repeated runs.
- A seeded +20% slowdown shifted the mean far outside that noise band
  (2.41ms → 3.56ms), easily separable.
- Open question this doesn't answer yet: GitHub-hosted runners are known
  to be noisier than a local dev machine (shared/virtualized CPU). This
  needs a real CI run before trusting these thresholds (see deferred
  spike below and open question 1 in the spec).

## 2. SQL instrumentation (`spikes/sql_instrumentation.rb`)

- `ActiveSupport::Notifications.subscribe("sql.active_record")` reliably
  captures every query with duration, using a plain sqlite3 in-memory DB
  (no full Rails app required for the spike).
- Filtering `payload[:name] == "SCHEMA"` cleanly excludes DDL/schema noise.
- Correctly distinguished 3 queries (baseline) vs 4 queries (candidate
  with one extra `update_all`).
- Still open: which other event names/payloads should be excluded by
  default in real apps (e.g. `SCHEMA`, cached query notifications,
  transaction BEGIN/COMMIT) — this is open question 9 in the spec and
  needs a broader survey against a real Rails app's query log.

## 3. Allocation measurement (`spikes/allocation_measurement.rb`)

- `GC.stat(:total_allocated_objects)` deltas (with `GC.disable` around the
  measured block) were **perfectly deterministic** for the baseline
  workload across 10 runs (995 every time).
- The candidate workload (+50 hash allocations) showed only 995→1046-1048,
  i.e. a couple of allocations of run-to-run jitter, still trivially
  distinguishable from the baseline.
- This is the cleanest signal of the three — worth leaning on it as a
  corroborating metric per open question 4 in the spec ("should duration
  failures require corroboration from a resource metric?").

## 4. Regression-injection experiment (`spikes/regression_injection.rb`)

40 trials per scenario, 15 samples + 3 warmup per trial, on the duration
workload:

| Method                          | False positives (no real change) | Detection rate (+20% seeded) |
|----------------------------------|-----------------------------------|-------------------------------|
| Threshold (10%/20% cutoffs)      | 0/40                               | 40/40                         |
| Mann-Whitney U (p < 0.05)        | 5/40 (~expected at α=0.05)         | 40/40                         |

Both methods work well on this clean synthetic workload. The threshold
method is simpler to explain in a report and had zero false positives
here; Mann-Whitney U's false-positive rate roughly tracked its stated
significance level, which is reassuring but means it needs a stricter
p-value cutoff (or a practical-significance floor on top of it, as the
spec already proposes in section 16) to avoid nuisance alarms at typical
CI volumes (many workloads × many PRs).

**Recommendation for Milestone 1/6 design:** don't pick one exclusively.
Follow the spec's existing design (section 16): require *both* a
practical-threshold breach *and* statistical significance before FAIL,
using WARN for practical-only or statistical-only signals. This spike
didn't have to choose between them to hit the exit criterion — it
confirms the layered approach is reasonable, it doesn't settle open
question 3 (whether Mann-Whitney U specifically is the best default test)
on its own.

## Deferred

- Repeatability study on GitHub-hosted runners (needs a pushed repo +
  Actions workflow) — real noise on shared CI hardware is very likely
  higher than what we saw locally. Do this before finalizing default
  sample counts/thresholds in `baseline.yml`.

## Answers to open questions this touched (spec section 33)

- Q3 (Mann-Whitney U as default?) — workable, not yet conclusively
  better/worse than the simpler threshold method at this scale; revisit
  once real noisy CI data exists.
- Q4 (should duration failures require corroboration?) — allocations are
  a strong, cheap, deterministic corroborating signal; worth requiring
  for FAIL (not just WARN) in a future milestone.
- Q9 (which SQL events to exclude by default) — `SCHEMA` confirmed noisy
  and excludable; full default exclude-list still needs a real Rails app
  to validate against (see examples/rails-rspec-app, not yet built).
- Q11 (false-positive target on public GitHub-hosted runners) — still
  open, blocked on the deferred CI repeatability study above.
