# frozen_string_literal: true

require "active_record"
require "baselined/instrumentation/sql_activity"

RSpec.describe Baselined::Instrumentation::SqlActivity do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      create_table :sql_activity_spec_widgets, force: true do |t|
        t.string :name
      end
    end
  end

  let(:widget_class) do
    Class.new(ActiveRecord::Base) { self.table_name = "sql_activity_spec_widgets" }
  end

  it "counts SQL queries issued between start and finish" do
    widget_class.create!(name: "a")
    widget_class.create!(name: "b")

    started = described_class.start
    widget_class.where(name: "a").to_a
    widget_class.count
    result = described_class.finish(started)

    expect(result["sql_count"]).to eq(2)
  end

  it "accumulates a non-negative cumulative duration" do
    started = described_class.start
    widget_class.count
    result = described_class.finish(started)

    expect(result["sql_duration_ns"]).to be >= 0
  end

  it "does not count queries issued before start or after finish" do
    started = described_class.start
    result = described_class.finish(started)
    widget_class.count # outside the window

    expect(result["sql_count"]).to eq(0)
  end

  it "excludes schema and transaction control statements as noise" do
    started = described_class.start
    widget_class.transaction { widget_class.create!(name: "c") }
    result = described_class.finish(started)

    # Only the INSERT should count; BEGIN/COMMIT ("TRANSACTION" events)
    # are excluded.
    expect(result["sql_count"]).to eq(1)
  end
end
