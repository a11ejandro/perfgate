#!/usr/bin/env ruby
# frozen_string_literal: true

# Milestone 0 spike: can we reliably count SQL queries and their
# cumulative duration for a workload using ActiveSupport::Notifications,
# without a full Rails app?
#
# Throwaway exploratory code, not part of the gem's public API.

require "bundler/setup"
require "active_record"
require "active_support/notifications"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :widgets, force: true do |t|
    t.string :name
    t.integer :quantity
  end
end

class Widget < ActiveRecord::Base
end

50.times { |i| Widget.create!(name: "widget-#{i}", quantity: i) }

# Collector mirroring what the real instrumentation module (section 13.2)
# will need: query count + cumulative duration, with a way to exclude
# schema/transaction chatter later if that turns out to be noisy.
class SqlCollector
  attr_reader :count, :duration_ms, :events

  def initialize
    @count = 0
    @duration_ms = 0.0
    @events = []
  end

  def subscribe
    ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
      next if payload[:name] == "SCHEMA"

      @count += 1
      @duration_ms += (finish - start) * 1000.0
      @events << payload[:sql]
    end
  end
end

def workload(extra_query: false)
  Widget.where("quantity > ?", 10).to_a
  Widget.find_by(name: "widget-5")
  Widget.count
  Widget.where(quantity: 42).update_all(quantity: 43) if extra_query
end

collector = SqlCollector.new
collector.subscribe

workload
puts "baseline workload: queries=#{collector.count} sql_duration_ms=#{collector.duration_ms.round(3)}"

collector2 = SqlCollector.new
collector2.subscribe
workload(extra_query: true)
puts "candidate workload (+1 query): queries=#{collector2.count} sql_duration_ms=#{collector2.duration_ms.round(3)}"

puts "\nsample captured statements:"
collector2.events.each { |sql| puts "  #{sql}" }
