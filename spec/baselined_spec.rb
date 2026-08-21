# frozen_string_literal: true

RSpec.describe Baselined do
  it "has a version number" do
    expect(Baselined::VERSION).not_to be nil
  end

  describe ".measure" do
    it "runs the block and returns its value even without an active sample context" do
      expect(described_class.measure { 1 + 1 }).to eq(2)
    end

    it "records the block's duration on the active sample context" do
      context = Baselined::Execution::SampleContext.new(metrics: [:duration])
      Baselined::Execution::SampleContext.current = context

      described_class.measure { sleep 0.01 }

      expect(context.data["duration_ns"]).to be >= 10_000_000
    ensure
      Baselined::Execution::SampleContext.current = nil
    end
  end
end
