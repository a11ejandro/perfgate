#!/usr/bin/env ruby
# frozen_string_literal: true

# Milestone 0 spike: how noisy is wall-clock duration measurement on this
# machine, using nothing but the standard library?
#
# This is throwaway exploratory code, not part of the gem's public API.
# It exists to answer (informally, locally) some of the open questions in
# section 33 of the spec before we commit to an execution-engine design:
#
#   - How many warmup iterations does it take for timings to stabilize?
#   - What's the coefficient of variation we should expect from a "quiet"
#     workload, so we know what counts as noise vs. signal later?
#
# Usage:
#   ruby spikes/duration_measurement.rb
#   ruby spikes/duration_measurement.rb --slow-percent 20

require "optparse"

options = { warmup: 5, samples: 30, slow_percent: 0 }
OptionParser.new do |opts|
  opts.on("--warmup N", Integer, "warmup iterations (default 5)") { |v| options[:warmup] = v }
  opts.on("--samples N", Integer, "measured samples (default 30)") { |v| options[:samples] = v }
  opts.on("--slow-percent N", Integer, "artificially slow down the workload by N% (default 0)") do |v|
    options[:slow_percent] = v
  end
end.parse!

# A stand-in "workload": some string/array churn plus a tiny sleep to
# simulate a request doing real work. Deliberately not sqlite/AR yet —
# that's spike 2.
def workload(slow_percent)
  data = Array.new(500) { |i| "item-#{i}" }
  data.each_with_object({}) { |item, acc| acc[item] = item.upcase }
  base_sleep = 0.002
  sleep(base_sleep * (1 + (slow_percent / 100.0)))
end

def measure_once
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
end

def mean(values)
  values.sum / values.size.to_f
end

def stddev(values)
  m = mean(values)
  variance = values.sum { |v| (v - m)**2 } / values.size.to_f
  Math.sqrt(variance)
end

puts "warmup=#{options[:warmup]} samples=#{options[:samples]} slow_percent=#{options[:slow_percent]}"

options[:warmup].times { measure_once { workload(options[:slow_percent]) } }

durations = Array.new(options[:samples]) { measure_once { workload(options[:slow_percent]) } }

durations_ms = durations.map { |d| d * 1000.0 }
m = mean(durations_ms)
sd = stddev(durations_ms)
cv = sd / m

puts format("mean=%.4fms stddev=%.4fms cv=%.2f%% min=%.4fms max=%.4fms",
            m, sd, cv * 100, durations_ms.min, durations_ms.max)
