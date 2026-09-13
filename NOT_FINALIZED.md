# Not Finalized

## CLI commands not yet built

| Command | What it should do | Spec section |
|---|---|---|
| `perfgate init` | Scaffold `perfgate.yml` with commented defaults and an example workload block | §6.1 |
| `perfgate doctor` | Pre-flight check: Ruby/Rails version, RSpec integration present, storage path writable, config valid | Phase 2 |
| `perfgate schema` | Print the canonical JSON Schema for run-result or comparison-result to stdout | Phase 2 |
| `perfgate report` | Re-render a saved comparison result in any supported format without re-running workloads | Phase 2 |

`init` and `doctor` directly affect first-run experience and are the highest priority.

---

## Memory metric not implemented

`metrics.memory` config key exists and is accepted by the schema validator,
but the collector is absent. `Instrumentation::REGISTRY` has no `:memory` entry.

File: `lib/perfgate/instrumentation.rb:19` — comment says "not yet implemented".

Safe to ship as-is (the config key silently has no effect), but the docs
(`docs/compatibility.md`) describe it as opt-in and experimental — should either
implement it or document clearly that it is deferred.

---

## CI matrix gap

`docs/compatibility.md` lists Ruby 3.2–3.4 and Rails 7.1/7.2/8.0 as supported,
but the repo's own CI (`.github/workflows/main.yml`) only tests Ruby 3.2.2 + SQLite.

No PostgreSQL or MySQL adapter tests. No Rails 7.2/8.0 matrix row.

Not a hard blocker for a first release, but should be noted in the release
announcement and closed before claiming broad compatibility.
