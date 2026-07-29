# Design-Partner Onboarding Guide

This is the walkthrough for an early adopter team installing Baseline
for the first time, aimed squarely at Milestone 5's exit criterion:
completing installation without the maintainer touching your repo.

It reflects what's actually implemented today. `baseline init`,
`report`, `doctor`, and `schema` are not built yet -- everything below
uses only `baseline run` and `baseline compare`.

## 1. Add the gem

```ruby
# Gemfile
gem "baseline", path: "../baseline", group: :test # or a git ref, until published
```

```bash
bundle install
```

No `baseline.yml` is required to get started -- a missing config file
is treated as pure defaults (8 samples, 2 warmup iterations, all
metrics enabled). Add one later once you want to tune thresholds or
policy.

## 2. Tag your first workload

Pick one existing request spec, job spec, or similar RSpec example
that exercises a code path you care about. Add `baseline: true` to its
metadata, and wrap only the part you want measured in
`Baseline.measure`:

```ruby
RSpec.describe "Checkout", type: :request, baseline: true do
  it "creates an order" do
    sign_in(create(:user))
    cart = create(:cart, :with_line_items)

    Baseline.measure do
      post "/checkout", params: { cart_id: cart.id }
    end

    expect(response).to have_http_status(:created)
  end
end
```

Only code inside `Baseline.measure` is timed and has its SQL/allocation
metrics collected -- sign-in, fixture creation, and response assertions
outside the block are excluded on purpose (spec section 9.3).

See [examples/rails-rspec-app/spec/requests/checkout_spec.rb](../examples/rails-rspec-app/spec/requests/checkout_spec.rb)
and [.../spec/jobs/invoice_job_spec.rb](../examples/rails-rspec-app/spec/jobs/invoice_job_spec.rb)
for a request-spec and a job-spec example side by side.

## 3. Run it locally

```bash
bundle exec baseline run --output .baseline/current
```

This discovers every `baseline: true`-tagged example, runs its warmup
+ samples in an isolated process, and writes a versioned result bundle
to `.baseline/current/runs/<run-id>/`.

## 4. Compare two runs

Run it again (ideally after making a change you'd expect to matter),
then compare:

```bash
bundle exec baseline compare \
  --baseline .baseline/current \
  --candidate .baseline/new-run \
  --output .baseline/comparisons
```

You'll get a console report with a PASS/WARN/FAIL decision per metric,
an overall decision, and a nonzero exit code on FAIL -- see the report
format in the main [README](../README.md#usage).

## 5. Wire up CI

Copy [examples/rails-rspec-app/.github/workflows/baseline.yml](../examples/rails-rspec-app/.github/workflows/baseline.yml)
into `.github/workflows/` in your repository. It:

1. downloads the last `baseline-main` artifact (if one exists yet);
2. runs `baseline run --compare .baseline/reference --format markdown`,
   which runs your workloads and compares them in one step;
3. publishes the resulting `summary.md` to the GitHub job summary;
4. re-uploads the artifact when building `main`, so the next PR has
   something to compare against.

The very first run on a repository will have nothing to compare
against yet -- `baseline run --compare` detects the missing baseline
and reports it as a warning rather than failing the build. After the
first successful `main` build, every subsequent PR compares against
it.

## 6. Reading your first result

- **PASS**: no metric regressed beyond its configured threshold with
  statistical confidence. Merge as usual.
- **WARN**: something changed, but not enough to be treated as a
  blocking regression (e.g. a metric moved but wasn't statistically
  significant, or the workload/environment changed in a way the
  default policy doesn't block on). Worth a look, not a blocker.
- **FAIL**: a metric both changed by more than its practical threshold
  *and* is statistically significant given the sample noise. The
  console/Markdown report's "Likely signal" line names the most
  probable contributing metric (e.g. "SQL query count increased by
  5") -- it's a deterministic hint, not a root-cause diagnosis.

## Getting help

If something doesn't work as described here, or the report doesn't
make sense, please open an issue (see
[CONTRIBUTING.md](../CONTRIBUTING.md)) rather than working around it
silently -- unclear reports and rough edges in exactly this kind of
first-run experience are the most valuable thing for us to hear about
right now.
