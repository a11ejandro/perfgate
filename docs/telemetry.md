# Telemetry Specification

Baseline collects **no telemetry by default**. This document specifies
the opt-in telemetry payload as designed in the technical specification
(section 22), so that anyone considering enabling it -- or auditing
whether Baseline is safe to run in a sensitive environment -- can see
exactly what would be sent and what never would be, before any
transmission code exists.

## Current status

As of this release, telemetry is **not implemented**. The
`telemetry.enabled` configuration key exists and defaults to `false`
(see `lib/baseline/config/defaults.rb`), but no code path currently
reads it to make a network request. This document describes the
contract that any future telemetry implementation must honor.

## Opt-in only

- Telemetry is off unless a user explicitly sets `telemetry.enabled:
  true` in `baseline.yml`, or an equivalent explicit environment
  override.
- There is no implicit opt-in through usage, installation, or CI
  execution.
- Baseline must function identically, with no missing features and no
  degraded behavior, whether telemetry is enabled or not.
- A telemetry send failure (network error, timeout, malformed
  response) must never affect Baseline's exit code, comparison result,
  or CLI output. Telemetry is best-effort and fire-and-forget.

## Permitted payload fields

If enabled, a telemetry event may only ever contain:

- Baseline version
- Ruby version
- Rails version
- RSpec version
- operating system
- CI provider
- number of workloads
- enabled metric names
- command success/failure category
- an anonymous installation ID (randomly generated, not derived from
  any repository or organization identifier)

## Never transmitted, under any configuration

- repository name or URL
- organization name
- source file names
- workload names
- metric *values* (durations, SQL counts, allocation counts, etc.)
- SQL text or bind values
- environment variable values
- commit SHA
- IP-derived geolocation, beyond whatever is inherent to receiving an
  HTTP request (Baseline itself never resolves or stores this)

## Why this split

The permitted fields are enough to answer aggregate product questions
("which Ruby/Rails versions are people actually running Baseline
against?", "does the CLI usually succeed or fail?") without being able
to reconstruct anything about a specific codebase, its performance
characteristics, or its data. This mirrors the broader security and
privacy requirements in spec section 22: no source code leaves the
process, and no mandatory network requests exist regardless of the
telemetry setting.

## Implementing telemetry (future work)

When telemetry transmission is implemented, it must:

1. Be added behind the existing `telemetry.enabled` flag, defaulting
   to `false`.
2. Serialize only the permitted fields above, ideally validated by a
   JSON schema the way run/comparison results already are.
3. Fail silently (log at most, never raise) on any transmission error.
4. Be documented in this file, including the exact endpoint and
   retention policy, before it ships in a release.
