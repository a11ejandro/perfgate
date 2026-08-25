# Compatibility Matrix

Baseline's target support matrix, per the technical specification
(section 23):

| Component        | Target                                  |
| ----------------- | ---------------------------------------- |
| Ruby              | 3.2, 3.3, 3.4                            |
| Rails              | 7.1, 7.2, 8.0                            |
| RSpec Core         | 3.12+                                    |
| Database           | PostgreSQL and MySQL, via Active Record  |
| CI runner          | Linux (GitHub Actions)                   |
| Local development  | macOS, best-effort                       |
| Windows            | Not supported in the MVP                 |

## What this repository's own CI currently exercises

This is a gap to close before a public release, not a promise already
kept. As of Milestone 5, this repository's own test suite
(`.github/workflows/ruby.yml`) only runs:

- Ruby 3.2.2
- ActiveRecord 7.1 + SQLite (used by the SQL instrumentation specs,
  which exercise real `ActiveSupport::Notifications` events rather
  than stubs)
- No MySQL, no PostgreSQL, no Rails 7.2/8.0, no Ruby 3.3/3.4

Closing this gap means:

- adding a Ruby version matrix (3.2, 3.3, 3.4) to the CI workflow;
- adding a Rails version matrix (7.1, 7.2, 8.0) via Appraisal or a
  similar Gemfile-matrix approach;
- adding a PostgreSQL and a MySQL service to CI and running the SQL
  instrumentation specs against both, not just SQLite;
- verifying `perfgate doctor` (once implemented) correctly classifies
  any of the above outside this matrix as incompatible rather than
  silently comparing.

## Fingerprint compatibility, not just supported versions

Being in the target matrix is necessary but not sufficient for two
runs to be compared. `Fingerprints::Compatibility` (Milestone 3) is
the actual gate: it compares Ruby engine/version, Rails version,
Baseline's own major version, database adapter/version, and the
workload's own definition and dataset hashes, and marks a comparison
`incompatible` if any of the "strict" fields differ. The matrix above
describes what Baseline is *tested against* -- the fingerprint
mechanism is what protects a specific comparison from ever silently
running across incompatible environments.
