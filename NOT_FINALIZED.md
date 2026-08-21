# Not Finalized

## Blocker — gem name taken

`baseline` is already published on RubyGems.org (by John Mair / banisterfiend).

**Must resolve before any `gem push`.**

Candidate names: `baseline-rails`, `baseline-rspec`, `baseline-ci`, `baselined`.

Once chosen: rename gem in `baseline.gemspec`, `lib/baseline/version.rb`,
`lib/baseline.rb` entry point, `exe/baseline`, `CHANGELOG`, `ROADMAP`,
README, and all docs.

---

## CLI commands not yet built

| Command | What it should do | Spec section |
|---|---|---|
| `baseline init` | Scaffold `baseline.yml` with commented defaults and an example workload block | §6.1 |
| `baseline doctor` | Pre-flight check: Ruby/Rails version, RSpec integration present, storage path writable, config valid | Phase 2 |
| `baseline schema` | Print the canonical JSON Schema for run-result or comparison-result to stdout | Phase 2 |
| `baseline report` | Re-render a saved comparison result in any supported format without re-running workloads | Phase 2 |

`init` and `doctor` directly affect first-run experience and are the highest priority.

---

## Memory metric not implemented

`metrics.memory` config key exists and is accepted by the schema validator,
but the collector is absent. `Instrumentation::REGISTRY` has no `:memory` entry.

File: `lib/baseline/instrumentation.rb:19` — comment says "not yet implemented".

Safe to ship as-is (the config key silently has no effect), but the docs
(`docs/compatibility.md`) describe it as opt-in and experimental — should either
implement it or document clearly that it is deferred.

---

## README status note is stale

`README.md` still reads:

> **Status:** Early development. `run` and `compare` are implemented and
> covered by tests; `init`, `report`, `doctor`, and `schema` are not yet built.

This needs to be updated before publishing — either to reflect what is missing
or removed once `init`/`doctor` are built.

---

## CI matrix gap

`docs/compatibility.md` lists Ruby 3.2–3.4 and Rails 7.1/7.2/8.0 as supported,
but the repo's own CI (`github/workflows/main.yml`) only tests Ruby 3.2.2 + SQLite.

No PostgreSQL or MySQL adapter tests. No Rails 7.2/8.0 matrix row.

Not a hard blocker for a first release, but should be noted in the release
announcement and closed before claiming broad compatibility.

---

## No GitHub remote

The git repo at `baseline/` has 7 commits and no remote.
`spec.homepage` in the gemspec points to `https://github.com/baseline-oss/baseline`
which does not exist yet.

Must push before publishing so RubyGems.org can resolve the source link and
`spec.files` (`git ls-files`) captures everything correctly.

---

## CHANGELOG not updated for release

The `[Unreleased]` block contains all milestone work but has never been
promoted to a dated `[0.1.0]` entry. The existing `[0.1.0]` line at the
bottom just says "Initial release".

Needs a proper dated entry before tagging and pushing.
