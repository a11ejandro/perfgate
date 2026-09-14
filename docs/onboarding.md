# Design-Partner Onboarding Guide

This is the walkthrough for an early adopter team installing Perfgate
for the first time, aimed squarely at Milestone 5's exit criterion:
completing installation without the maintainer touching your repo.

It reflects what's actually implemented today. `perfgate init`,
`report`, `doctor`, and `schema` are not built yet -- everything below
uses only `perfgate run` and `perfgate compare`.

## 1. Add the gem

```ruby
# Gemfile
gem "perfgate", path: "../baseline", group: :test # or a git ref, until published
```

```bash
bundle install
```

A missing `perfgate.yml` is accepted for exploratory runs, but its missing
dataset provenance makes comparisons INCOMPARABLE. Create the smallest useful
declaration before comparing runs:

```yaml
dataset:
  id: checkout-fixtures
  schema_version: "1"
  generator_version: "2026-09"
  seed: 12345
  scale: small
  cache_state: cold
```

The remaining defaults are 8 measured samples, 2 warmup iterations, a
seven-day maximum age for a historical baseline, and advisory policy mode.

## 2. Tag your first workload

Pick one existing request spec, job spec, or similar RSpec example
that exercises a code path you care about. Add a `perfgate` metadata hash with
the claim the workload supports and the responsible owner, and wrap only the
part you want measured in `Perfgate.measure`:

```ruby
RSpec.describe "Checkout", type: :request,
          perfgate: {
            claim: "Checkout latency and database work do not materially deteriorate",
            owner: "payments-platform@example.com"
          } do
  it "creates an order" do
    sign_in(create(:user))
    cart = create(:cart, :with_line_items)

    Perfgate.measure do
      post "/checkout", params: { cart_id: cart.id }
    end

    expect(response).to have_http_status(:created)
  end
end
```

Only code inside `Perfgate.measure` is timed and has its SQL/allocation
metrics collected -- sign-in, fixture creation, and response assertions
outside the block are excluded on purpose (spec section 9.3).

See [examples/rails-rspec-app/spec/requests/checkout_spec.rb](../examples/rails-rspec-app/spec/requests/checkout_spec.rb)
and [.../spec/jobs/invoice_job_spec.rb](../examples/rails-rspec-app/spec/jobs/invoice_job_spec.rb)
for a request-spec and a job-spec example side by side.

## 3. Run it locally

```bash
bundle exec perfgate run --output .perfgate/current
```

This discovers every `perfgate`-tagged example, runs its warmup
+ samples in an isolated process, and writes a versioned result bundle
to `.perfgate/current/runs/<run-id>/`.

## 4. Compare two runs

Run it again (ideally after making a change you'd expect to matter),
then compare:

```bash
bundle exec perfgate compare \
  --baseline .perfgate/current \
  --candidate .perfgate/new-run \
  --output .perfgate/comparisons
```

You'll get a console report with an effect estimate, interval, sample counts,
MEI decision rule, metric outcome, comparability details, and overall policy
outcome. Advisory mode exits zero even when the evidence outcome is FAIL.

## 5. Wire up CI

Copy [examples/rails-rspec-app/.github/workflows/perfgate.yml](../examples/rails-rspec-app/.github/workflows/perfgate.yml)
into `.github/workflows/` in your repository. It:

1. downloads the last `perfgate-main` artifact (if one exists yet);
2. runs `perfgate run --compare .perfgate/reference --format markdown`,
   which runs your workloads and compares them in one step;
3. publishes the resulting `summary.md` to the GitHub job summary;
4. re-uploads the artifact when building `main`, so the next PR has
   something to compare against.

The very first run on a repository will have nothing to compare
against yet -- `perfgate run --compare` detects the missing baseline
and reports it as a warning rather than failing the build. After the
first successful `main` build, every subsequent PR compares against
it.

## 6. Reading your first result

- **PASS**: the upper uncertainty bound excludes the configured warning MEI.
- **WARN**: the point estimate suggests deterioration or policy has a
  reservation, but the evidence does not support a blocking result.
- **FAIL**: the lower uncertainty bound exceeds the configured failure MEI
  (or a stable deterministic metric crosses its failure rule).
- **INCONCLUSIVE**: the comparison is valid in principle but is underpowered,
  unstable, missing observations, or interrupted by an execution error.
- **INCOMPARABLE**: required provenance is missing or important conditions or
  the workload definition changed.

The "Likely signal" line is a deterministic hint, not a root-cause diagnosis.

## 7. Opt into blocking only after calibration

Perfgate defaults to `policy.mode: advisory`. Before changing it, run repeated
A/A trials and injected regressions through the same CI workflow. Confirm an
acceptable suite-level false-FAIL rate, rerun stability, and power at each
declared minimum effect. Then opt in explicitly:

```yaml
policy:
  mode: blocking
```

The current implementation uses an independent historical-baseline design. It
records that design in every result, enforces baseline age and fingerprints,
and uses a Bonferroni-adjusted bootstrap interval, but it does not provide the
stronger same-worker interleaved control/candidate design.

## Getting help

If something doesn't work as described here, or the report doesn't
make sense, please open an issue (see
[CONTRIBUTING.md](../CONTRIBUTING.md)) rather than working around it
silently -- unclear reports and rough edges in exactly this kind of
first-run experience are the most valuable thing for us to hear about
right now.
