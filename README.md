# Perfgate

Perfgate is an open-source, CI-native performance assurance tool for Ruby on
Rails applications. It converts selected RSpec examples into repeatable
performance workloads, measures application-level signals (duration, SQL
activity, allocations, GC), compares a pull request against a compatible
default-branch baseline, and produces a clear PASS/WARN/FAIL merge-gate
decision.

> Did this change introduce a material, reproducible performance regression?

## Installation

Add to your Gemfile:

```ruby
gem "perfgate", group: :test
```

## Usage

Tag an RSpec example with `perfgate: true` and wrap the part you want
measured in `Perfgate.measure`:

```ruby
RSpec.describe "Checkout", type: :request, perfgate: true do
  it "creates an order" do
    sign_in(create(:user))
    cart = create(:cart, :with_line_items)

    Perfgate.measure { post "/checkout", params: { cart_id: cart.id } }

    expect(response).to have_http_status(:created)
  end
end
```

Then run it:

```bash
bundle exec perfgate run --output .perfgate/current
bundle exec perfgate compare --baseline .perfgate/main --candidate .perfgate/current
```

`perfgate run` also accepts `--compare PATH` to run and compare against a
reference bundle in one step, and `--format markdown` to render a Markdown
report instead of the console summary. Combined, this is what a CI job needs:

```bash
bundle exec perfgate run \
  --output .perfgate/current \
  --compare .perfgate/reference \
  --format markdown
```

This writes a `summary.md` file into `--output` alongside the run bundle, so
it can be published as a GitHub Actions job summary. See
[docs/onboarding.md](docs/onboarding.md) for a full walkthrough and
[examples/rails-rspec-app](examples/rails-rspec-app) for a full example
workflow, including the artifact download/upload steps that carry a baseline
result between CI runs.

## Docs

- [Architecture](docs/architecture.md) - layered pipeline, key design decisions, how to add a metric
- [Onboarding guide](docs/onboarding.md) - first-run walkthrough for an existing Rails/RSpec app
- [Compatibility matrix](docs/compatibility.md) - supported Ruby, Rails, and database versions
- [Telemetry contract](docs/telemetry.md) - what is (and is never) collected
- [Roadmap](ROADMAP.md) - what's done, what's next, what's out of scope

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/a11ejandro/perfgate).
See the contribution guide for scope, principles, and the implementation
constraints that pull requests are expected to follow.

## License

Perfgate is available as open source under the terms of the
[Apache License 2.0](LICENSE).
