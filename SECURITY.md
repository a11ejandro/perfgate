# Security Policy

## Supported versions

Baseline is pre-1.0. Security fixes are made against the latest release
on the default branch; there is no long-term support branch yet.

| Version | Supported |
| ------- | --------- |
| latest  | yes       |
| < 0.1   | no        |

## Reporting a vulnerability

Please do not open a public GitHub issue for suspected security
vulnerabilities. Instead, use GitHub's private
[vulnerability reporting](https://github.com/baseline-oss/baseline/security/advisories/new)
feature, or email the maintainer directly at bendthe@gmail.com with:

- a description of the issue and its potential impact;
- steps to reproduce, or a minimal repro case;
- the Baseline version, Ruby version, and Rails version involved.

You should receive an acknowledgment within 5 business days. We'll work
with you to understand and confirm the issue, agree on a disclosure
timeline, and credit you in the release notes unless you'd prefer to
stay anonymous.

## What's in scope

- The `baseline` gem's CLI, execution engine, comparison/policy logic,
  and filesystem storage adapter.
- Archive import handling (path traversal, malformed archives).
- Anything that could cause Baseline to execute untrusted code,
  deserialize untrusted data unsafely, or exfiltrate source code, SQL,
  or environment values it isn't supposed to touch (see the data
  handling guarantees in the technical specification, section 22).

## What's out of scope

- The example Rails application under `examples/`, which is
  illustrative only and not meant to be run as a real service.
- Vulnerabilities that require the attacker to already control
  `baseline.yml` or the workload specs in a repository that has
  chosen to run Baseline (i.e. arbitrary Ruby code a repository owner
  chose to execute in their own CI).

## Baseline's security posture

By design, Baseline:

- makes no mandatory network requests;
- never sends source code, SQL text, bind values, or environment
  values off the machine it runs on;
- treats imported result bundles and archives as untrusted input,
  parses them as JSON (never `Marshal` or other Ruby object
  deserialization formats), and rejects path traversal in archive
  entries;
- keeps telemetry opt-in and disabled by default (see
  [docs/telemetry.md](docs/telemetry.md)).

A vulnerability report that Baseline violates one of these guarantees
is always in scope, even if it wasn't listed above.
