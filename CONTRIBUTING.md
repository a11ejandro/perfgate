# Contributing to Baseline

Thanks for considering a contribution. Baseline is early and the scope
is deliberately narrow -- see
[baseline_oss_mvp_technical_spec_and_roadmap.md](../baseline_oss_mvp_technical_spec_and_roadmap.md)
for the authoritative product and technical specification. If you're
proposing something not covered there, please open an issue to discuss
scope before sending a large pull request.

## Development setup

```bash
git clone <your fork>
cd baseline
bin/setup
```

This installs dependencies via Bundler. `bin/console` gives you an
interactive prompt with the gem loaded.

## Running the checks

```bash
bundle exec rspec     # unit tests
bundle exec rubocop   # style and complexity checks
```

Both must pass before a pull request will be merged; `rake` (no
arguments) runs both.

## Coding conventions

- This project has a firm house rule: when RuboCop flags a file for
  length or complexity (`Metrics/MethodLength`, `Metrics/ClassLength`,
  `Metrics/ModuleLength`, etc.), **extract a smaller method or a new
  collaborator class/module** rather than raising the limit in
  `.rubocop.yml`. Several modules in `lib/baseline/comparison/` and
  `lib/baseline/cli/` exist specifically because of this rule -- follow
  that pattern.
- Favor small, single-purpose classes and modules over large ones.
  Keep public interfaces documented with a short module/class comment
  explaining the "why", not just the "what".
- New behavior should ship with unit tests. Regression-injection style
  tests (seed a known regression, assert Baseline detects it) are
  especially valuable for comparison/policy logic.
- Don't add a new runtime dependency without discussing it first --
  the spec favors using Ruby/Rails standard library and already-present
  gems (e.g. `rubygems/package` and `zlib` for archives) over adding
  new ones.

## Commit and PR style

- Write commit messages and PR descriptions the way you'd want to read
  them in `git log`: an imperative-mood subject line, and a body that
  explains *why* when it's not obvious from the diff.
- Keep pull requests scoped to one milestone or one deliverable where
  possible; it makes review much faster.
- Reference the relevant spec section (e.g. "spec 20.3") in the PR
  description when implementing a specific documented behavior.

## Reporting bugs

Open a GitHub issue with:

- Baseline version, Ruby version, Rails version, RSpec version;
- your `baseline.yml` (redacted if needed);
- the command you ran and its full output;
- what you expected vs. what happened.

## Reporting security issues

Please don't file security vulnerabilities as public issues -- see
[SECURITY.md](SECURITY.md) instead.
