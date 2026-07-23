#!/usr/bin/env ruby
# frozen_string_literal: true

# Milestone 0 spike: regression-injection experiment.
#
# Runs the duration workload from spike 1 many times under two conditions
# (no change vs a seeded +20% slowdown) and checks how well a simple
# threshold comparison and a Mann-Whitney U test tell them apart, versus
# how often they'd cry wolf on two truly-identical runs.
#
# This is the thing the exit criterion in spec section 28 ("detect a
# seeded 20% duration regression... with an acceptably low false-positive
# rate") is actually asking us to validate before committing to a
# comparison method (see spec section 16 and open question 3 in section 33).
#
# Throwaway exploratory code, not part of the gem's public API.

SAMPLES = 15
WARMUP = 3
TRIALS = 40
THRESHOLD_WARNING_PERCENT = 10
THRESHOLD_FAILURE_PERCENT = 20

def workload(slow_percent)
  data = Array.new(500) { |i| "item-#{i}" }
  data.each_with_object({}) { |item, acc| acc[item] = item.upcase }
  sleep(0.002 * (1 + (slow_percent / 100.0)))
end

def measure_once(slow_percent)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  workload(slow_percent)
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
end

def sample_run(slow_percent)
  WARMUP.times { measure_once(slow_percent) }
  Array.new(SAMPLES) { measure_once(slow_percent) * 1000.0 }
end

def mean(values)
  values.sum / values.size.to_f
end

# Simple, explainable comparison mirroring the "practical thresholds" idea
# in spec section 11/16: percent change in means against fixed cutoffs.
def threshold_decision(baseline_samples, candidate_samples)
  base_mean = mean(baseline_samples)
  cand_mean = mean(candidate_samples)
  percent_change = ((cand_mean - base_mean) / base_mean) * 100

  if percent_change >= THRESHOLD_FAILURE_PERCENT
    :fail
  elsif percent_change >= THRESHOLD_WARNING_PERCENT
    :warn
  else
    :pass
  end
end

# Mann-Whitney U with a normal approximation, one-sided (candidate slower
# than baseline). No external gem, so we can run this without dependencies
# in a real spec runner later.
def mann_whitney_u_one_sided_p(baseline_samples, candidate_samples)
  combined = baseline_samples.map { |v| [v, :base] } + candidate_samples.map { |v| [v, :cand] }
  sorted = combined.sort_by { |v, _| v }

  ranks = Array.new(sorted.size)
  i = 0
  while i < sorted.size
    j = i
    j += 1 while j + 1 < sorted.size && sorted[j + 1][0] == sorted[i][0]
    avg_rank = ((i + 1) + (j + 1)) / 2.0
    (i..j).each { |k| ranks[k] = avg_rank }
    i = j + 1
  end

  rank_sum_cand = sorted.each_index.sum { |k| sorted[k][1] == :cand ? ranks[k] : 0 }

  n1 = baseline_samples.size
  n2 = candidate_samples.size
  u_cand = rank_sum_cand - (n2 * (n2 + 1) / 2.0)

  mean_u = n1 * n2 / 2.0
  std_u = Math.sqrt(n1 * n2 * (n1 + n2 + 1) / 12.0)
  return 0.5 if std_u.zero?

  # We want P(candidate slower) -> larger U for candidate (more pairs
  # where candidate > baseline) is evidence of being slower, so we want
  # the upper-tail probability.
  z = (u_cand - mean_u) / std_u
  0.5 * Math.erfc(z / Math.sqrt(2))
end

def run_trial(baseline_slow_percent, candidate_slow_percent)
  baseline_samples = sample_run(baseline_slow_percent)
  candidate_samples = sample_run(candidate_slow_percent)
  {
    threshold: threshold_decision(baseline_samples, candidate_samples),
    mwu_p: mann_whitney_u_one_sided_p(baseline_samples, candidate_samples)
  }
end

puts "Running #{TRIALS} trials per scenario (samples=#{SAMPLES}, warmup=#{WARMUP})...\n\n"

# Scenario A: no real change (false-positive check)
no_change_results = Array.new(TRIALS) { run_trial(0, 0) }
threshold_false_positives = no_change_results.count { |r| r[:threshold] != :pass }
mwu_false_positives_at_95 = no_change_results.count { |r| r[:mwu_p] < 0.05 }

puts "Scenario A — no real change (should mostly PASS / high p-value):"
puts "  threshold false-positive rate: #{threshold_false_positives}/#{TRIALS}"
puts "  Mann-Whitney false-positive rate (p<0.05): #{mwu_false_positives_at_95}/#{TRIALS}"

# Scenario B: seeded +20% slowdown (should be caught)
regression_results = Array.new(TRIALS) { run_trial(0, 20) }
threshold_caught = regression_results.count { |r| r[:threshold] == :fail }
mwu_caught_at_95 = regression_results.count { |r| r[:mwu_p] < 0.05 }

puts "\nScenario B — seeded +20% slowdown (should mostly FAIL / low p-value):"
puts "  threshold detection rate (FAIL): #{threshold_caught}/#{TRIALS}"
puts "  Mann-Whitney detection rate (p<0.05): #{mwu_caught_at_95}/#{TRIALS}"
