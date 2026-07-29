# frozen_string_literal: true

require "baseline/statistics/summary"

RSpec.describe Baseline::Statistics::Summary do
  describe ".call" do
    it "returns zeroed stats for an empty sample set" do
      expect(described_class.call([])).to eq(
        "mean" => 0, "median" => 0, "min" => 0, "max" => 0, "mad" => 0, "p90" => 0, "count" => 0
      )
    end

    it "computes mean and median for an odd-sized sample set" do
      summary = described_class.call([10, 20, 30])

      expect(summary["mean"]).to eq(20)
      expect(summary["median"]).to eq(20)
    end

    it "reports min, max, and count alongside the central tendency stats" do
      summary = described_class.call([10, 20, 30])

      expect(summary["min"]).to eq(10)
      expect(summary["max"]).to eq(30)
      expect(summary["count"]).to eq(3)
    end

    it "interpolates the median for an even-sized sample set" do
      summary = described_class.call([10, 20, 30, 40])

      expect(summary["median"]).to eq(25)
    end

    it "is insensitive to sample order" do
      expect(described_class.call([5, 1, 3])).to eq(described_class.call([1, 3, 5]))
    end

    it "reports p90 as close to the top of the distribution" do
      summary = described_class.call((1..100).to_a)

      expect(summary["p90"]).to be_within(1).of(90)
    end

    it "reports zero MAD for a constant sample set" do
      expect(described_class.call([42, 42, 42])["mad"]).to eq(0)
    end
  end
end
