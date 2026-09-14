# Example Rails + RSpec App

Placeholder for the example Rails application used to demonstrate and
integration-test Perfgate (see section 8 and Prompt 2 of the technical
specification). The full app is not yet scaffolded.

`spec/requests/checkout_spec.rb` and `spec/jobs/invoice_job_spec.rb`
are illustrative workload examples (Milestone 2 deliverables: a
request-spec example and a job-spec example, spec section 13.7). They
show the intended `perfgate:`-tagged, `Perfgate.measure`-wrapped shape
once a real Rails app backs this directory; they are not executed by
CI yet since there's no app for them to run against.

`perfgate.yml` declares the fixture dataset and keeps the example in advisory
mode. A real deployment should replace those identifiers with its reproducible
dataset recipe and opt into blocking only after A/A and injected-regression
calibration on its own runners.

## CI usage

`.github/workflows/perfgate.yml` reproduces the conceptual workflow
from spec section 19.1: it downloads whatever `perfgate-main` artifact
the last successful main-branch build published, runs the current
branch's workloads and compares them against it in one step (`perfgate
run --output .perfgate/current --compare .perfgate/reference --format
markdown`), publishes the resulting `summary.md` to the job summary,
and re-uploads the artifact when building main itself.

This is deliberately the MVP-level version the spec calls for:

- No GitHub App or API-based artifact lookup -- just the fixed
  `perfgate-main` artifact name via `actions/download-artifact`.
  `continue-on-error: true` covers the very first run, before any such
  artifact exists; `perfgate run --compare` then reports a missing
  baseline instead of crashing.
- Perfgate verifies bundle checksums and run fingerprints, but this workflow
  does not authenticate that the downloaded artifact came from a successful
  protected-branch run at or before the PR's merge base. A real deployment
  should tighten artifact selection and trust with a dedicated action.
- Job summary only (spec 19.2); no sticky PR comment or check
  annotation yet.
