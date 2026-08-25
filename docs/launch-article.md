# Introducing Baseline: a CI-native performance gate for Rails, built on RSpec

*Draft launch article. Adjust tone, add real screenshots/output, and
link a public repository before publishing.*

## The problem

Most Rails teams find out about a performance regression one of two
ways: a customer complains, or an on-call engineer gets paged. Load
testing exists, but it's usually a separate, heavyweight process that
runs occasionally, not on every pull request. The result is that a
change that quietly adds an N+1 query, or turns a fast endpoint into a
slow one, often ships and sits in production for weeks before anyone
notices.

Meanwhile, your team already writes RSpec examples that exercise the
exact code paths that matter -- the checkout flow, the search endpoint,
the background job that processes an order. Those examples know how to
set up the right data and call the right code. What they don't do is
tell you whether that code got slower.

## What Baseline does

Baseline turns selected RSpec examples into repeatable performance
workloads. It runs each one several times in an isolated process,
measures wall-clock duration, SQL query count and duration, and object
allocations, and produces a versioned result bundle. On a pull request,
it compares that bundle against a result from your default branch and
answers one question:

> Did this change introduce a material, reproducible performance
> regression?

The answer comes back as a clear PASS, WARN, or FAIL, with a
console summary and a Markdown report explaining *why*:

```text
Baseline Performance Assurance

Overall: FAIL
Baseline: main@1a2b3c4
Candidate: feature/checkout@9d8e7f6

✗ checkout.create_order
  Duration       281 ms → 337 ms   +19.9%   FAIL
  SQL queries         14 → 19      +5       FAIL
  SQL duration      51 ms → 73 ms  +43.1%   FAIL
  Allocations      18.4k → 19.1k   +3.8%    PASS

Likely signal:
  SQL query count increased by 5.

Compatibility: compatible
Samples: 8 baseline / 8 candidate
```

## Why not just look at duration?

Wall-clock duration on a shared CI runner is noisy. Two runs of
identical code can easily differ by 10-20% just from scheduling noise.
Baseline treats duration as one signal among several, downgrades
low-confidence results instead of crying wolf, and refuses to compare
runs from environments it isn't confident are equivalent -- a different
Ruby or Rails version, a changed workload definition, or an
incompatible dataset all mark a comparison `incompatible` rather than
silently producing a misleading result.

## Built for CI, not a hosted product

There's no account to create and no dashboard to log into. Baseline
stores its result bundles as plain, versioned JSON on your own
filesystem or CI artifact storage. A documented GitHub Actions workflow
downloads your default branch's last result, runs your workloads, and
publishes a job summary -- all with `GITHUB_TOKEN`, no third-party
service in the loop.

## Try it

```ruby
# Gemfile
gem "perfgate", group: :test
```

Tag an existing request spec or job spec with `baseline: true`, wrap the
part you care about in `Perfgate.measure { ... }`, and you have your
first workload. See
[docs/onboarding.md](onboarding.md) for a full walkthrough, including
wiring up the GitHub Actions workflow.

## Where this is going

Baseline is early. The MVP focuses on Rails + RSpec, GitHub Actions,
and a conservative, explainable comparison engine over a broad feature
set. We'd rather earn trust on a narrow surface than ship something
that produces confusing or noisy results. If you try it and hit a
false positive, a confusing report, or a missing feature, please open
an issue -- that feedback is exactly what shapes the next milestone.
