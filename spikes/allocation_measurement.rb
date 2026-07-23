#!/usr/bin/env ruby
# frozen_string_literal: true

# Milestone 0 spike: how stable are Ruby object-allocation counts as a
# performance signal, across repeated runs of the same workload?
#
# Throwaway exploratory code, not part of the gem's public API.

GC.disable # avoid a GC pause landing mid-measurement and skewing one sample

def workload(extra_allocations: false)
  data = Array.new(200) { |i| "item-#{i}" }
  hash = data.each_with_object({}) { |item, acc| acc[item] = item.upcase }
  hash.values.map(&:downcase)
  Array.new(50) { {} } if extra_allocations
end

def measure_allocations
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
end

# warmup so any lazy allocation (e.g. symbol interning, constant lookups)
# has already happened before we start measuring
3.times { measure_allocations { workload } }

samples = Array.new(10) { measure_allocations { workload } }
puts "baseline allocations per run: #{samples}"
puts "baseline: min=#{samples.min} max=#{samples.max} (identical? #{samples.uniq.size == 1})"

samples_extra = Array.new(10) { measure_allocations { workload(extra_allocations: true) } }
puts "\ncandidate (+50 hashes) allocations per run: #{samples_extra}"
puts "candidate: min=#{samples_extra.min} max=#{samples_extra.max} (identical? #{samples_extra.uniq.size == 1})"

diff = samples_extra.min - samples.max
puts "\nworst-case delta between baseline and candidate: #{diff}"

GC.enable
