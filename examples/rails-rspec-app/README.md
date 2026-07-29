# Example Rails + RSpec App

Placeholder for the example Rails application used to demonstrate and
integration-test Baseline (see section 8 and Prompt 2 of the technical
specification). The full app is not yet scaffolded.

`spec/requests/checkout_spec.rb` and `spec/jobs/invoice_job_spec.rb`
are illustrative workload examples (Milestone 2 deliverables: a
request-spec example and a job-spec example, spec section 13.7). They
show the intended `baseline:`-tagged, `Baseline.measure`-wrapped shape
once a real Rails app backs this directory; they are not executed by
CI yet since there's no app for them to run against.

## CI usage

`.github/workflows/baseline.yml` reproduces the conceptual workflow
from spec section 19.1: it downloads whatever `baseline-main` artifact
the last successful main-branch build published, runs the current
branch's workloads and compares them against it in one step (`baseline
run --output .baseline/current --compare .baseline/reference --format
markdown`), publishes the resulting `summary.md` to the job summary,
and re-uploads the artifact when building main itself.

This is deliberately the MVP-level version the spec calls for:

- No GitHub App or API-based artifact lookup -- just the fixed
  `baseline-main` artifact name via `actions/download-artifact`.
  `continue-on-error: true` covers the very first run, before any such
  artifact exists; `baseline run --compare` then reports a missing
  baseline instead of crashing.
- No provenance checking (spec 19.3) beyond what
  `actions/download-artifact` already gives you for free -- there's no
  verification here that the artifact came from a successful run, the
  configured default branch, or a commit at or before the PR's base.
  A real deployment should tighten this with a small composite action
  once one exists.
- Job summary only (spec 19.2); no sticky PR comment or check
  annotation yet.
