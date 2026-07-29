# Baseline

Baseline is an open-source, CI-native performance assurance tool for Ruby on
Rails applications. It converts selected RSpec examples into repeatable
performance workloads, measures application-level signals (duration, SQL
activity, allocations, GC), compares a pull request against a compatible
default-branch baseline, and produces a clear PASS/WARN/FAIL merge-gate
decision.

> Did this change introduce a material, reproducible performance regression?

See [baseline_oss_mvp_technical_spec_and_roadmap.md](../baseline_oss_mvp_technical_spec_and_roadmap.md)
for the full product and technical specification driving this implementation.

**Status:** Early development. `run` and `compare` are implemented and
covered by tests; `init`, `report`, `doctor`, and `schema` are not yet
built. See the roadmap for what's still missing before a public MVP
release.

## Installation

Not yet published to RubyGems.org. To use during development, add to your
Gemfile pointing at a local path or git ref:

```ruby
gem "baseline", path: "../baseline", group: :test
```

## Usage

Tag an RSpec example with `baseline: true` and wrap the part you want
measured in `Baseline.measure`:

```ruby
RSpec.describe "Checkout", type: :request, baseline: true do
  it "creates an order" do
    sign_in(create(:user))
    cart = create(:cart, :with_line_items)

    Baseline.measure { post "/checkout", params: { cart_id: cart.id } }

    expect(response).to have_http_status(:created)
  end
end
```

Then run it:

```bash
bundle exec baseline run --output .baseline/current
bundle exec baseline compare --baseline .baseline/main --candidate .baseline/current
```

`baseline run` also accepts `--compare PATH` to run and compare against a
reference bundle in one step, and `--format markdown` to render a Markdown
report instead of the console summary. Combined, this is what a CI job needs:

```bash
bundle exec baseline run \
  --output .baseline/current \
  --compare .baseline/reference \
  --format markdown
```

This writes a `summary.md` file into `--output` alongside the run bundle, so
it can be published as a GitHub Actions job summary. See
[docs/onboarding.md](docs/onboarding.md) for a full walkthrough and
[examples/rails-rspec-app](examples/rails-rspec-app) for a full example
workflow, including the artifact download/upload steps that carry a baseline
result between CI runs.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome once the repository has a public
home. See the technical specification for scope, principles, and the
implementation constraints that pull requests are expected to follow.

## License

Baseline is available as open source under the terms of the
[Apache License 2.0](LICENSE).
