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

**Status:** Pre-alpha. This gem is currently a skeleton; no commands are
implemented yet. Do not use in production.

## Installation

Not yet published to RubyGems.org. To use during development, add to your
Gemfile pointing at a local path or git ref:

```ruby
gem "baseline", path: "../baseline"
```

## Usage

```bash
bundle exec baseline init
bundle exec baseline run
```

(Not yet implemented — see the roadmap's development milestones.)

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
