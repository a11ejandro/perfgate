# frozen_string_literal: true

require "perfgate/comparison/metric_decision"
require "perfgate/config"

RSpec.describe Perfgate::Comparison::MetricDecision do
  let(:config) { Perfgate::Config.default }

  # Duration samples are always raw nanoseconds (spec 13.1), and the
  # default minimum_absolute_ms threshold is 10ms. Scale these fixtures
  # up from small illustrative integers into a realistic ~100ms
  # request-duration range so absolute-change comparisons exercise real
  # thresholds instead of accidentally sitting below every noise floor.
  def duration_scale
    100_000
  end

  def stable_samples(median, count: 8)
    Array.new(count) { |i| (median + (i.even? ? 1 : -1)) * duration_scale }
  end

  describe ".call" do
    it "is inconclusive when either sample set is below the minimum sample size" do
      result = described_class.call(metric: :duration, baseline_samples: [10, 11], candidate_samples: [10, 11],
                                    config: config)

      expect(result["decision"]).to eq("inconclusive")
      expect(result).to include("baseline_sample_size" => 2, "candidate_sample_size" => 2)
    end

    it "passes when the candidate is not meaningfully different from the baseline" do
      baseline = [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map { |v| v * duration_scale }
      candidate = [985, 1025, 995, 1005, 1000, 1035, 975, 1010].map { |v| v * duration_scale }

      result = described_class.call(metric: :duration, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["decision"]).to eq("pass")
    end

    it "fails when a duration regression is both practically and statistically significant" do
      baseline = stable_samples(1000)
      candidate = stable_samples(1300)

      result = described_class.call(metric: :duration, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["decision"]).to eq("fail")
      expect(result["practically_significant"]).to be true
      expect(result["change_percent"]).to be > 0
    end

    it "does not turn a precise regression into a pass solely because a noise flag is set" do
      noisy_config = Perfgate::Config.default
      noisy_config.to_h[:comparison][:noise_ratio_threshold] = 0.0

      baseline = stable_samples(1000)
      candidate = stable_samples(1300)

      result = described_class.call(metric: :duration, baseline_samples: baseline, candidate_samples: candidate,
                                    config: noisy_config)

      expect(result["noisy"]).to be true
      expect(result["decision"]).to eq("fail")
    end

    it "is inconclusive when uncertainty overlaps the MEI without a material point estimate" do
      baseline = [900, 1100, 950, 1050, 1000, 1080, 920, 1020].map { |v| v * duration_scale }
      candidate = [1000, 1200, 1050, 1150, 1100, 1180, 1020, 1120].map { |v| v * duration_scale }

      result = described_class.call(metric: :duration, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["decision"]).to eq("inconclusive")
    end

    it "does not warn on a change that clears the noise floor by p-value alone but is below the absolute minimum" do
      baseline = [1000, 1002, 999, 1001, 1000, 1002, 998, 1001].map { |v| v * duration_scale }
      candidate = [1001, 1003, 1000, 1002, 1001, 1003, 999, 1002].map { |v| v * duration_scale }

      result = described_class.call(metric: :duration, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["decision"]).to eq("pass")
    end

    it "passes a material improvement because thresholds are directional" do
      baseline = stable_samples(1300)
      candidate = stable_samples(1000)

      result = described_class.call(metric: :duration, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["change_percent"]).to be < -20
      expect(result["decision"]).to eq("pass")
      expect(result.dig("interval", "percent", "upper")).to be < 0
    end

    it "compares sql_count deterministically instead of statistically" do
      baseline = Array.new(8, 10)
      candidate = Array.new(8, 11)

      result = described_class.call(metric: :sql_count, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["confidence"]).to be_nil
      expect(result["decision"]).to eq("warn")
    end

    it "passes sql_count when the candidate issues fewer or equal queries" do
      baseline = Array.new(8, 5)
      candidate = Array.new(8, 5)

      result = described_class.call(metric: :sql_count, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["decision"]).to eq("pass")
    end

    it "fails sql_count when the increase clears the failure percentage" do
      baseline = Array.new(8, 5)
      candidate = Array.new(8, 10)

      result = described_class.call(metric: :sql_count, baseline_samples: baseline, candidate_samples: candidate,
                                    config: config)

      expect(result["decision"]).to eq("fail")
    end


    it "is inconclusive when a supposedly deterministic count varies within a run" do
      result = described_class.call(metric: :sql_count, baseline_samples: [5, 5, 6, 5, 5],
                                    candidate_samples: [6, 6, 6, 6, 6], config: config)

      expect(result["decision"]).to eq("inconclusive")
      expect(result["rule"]).to include("varied within a run")
    end

    it "warns rather than raising when a count increases from a zero baseline" do
      result = described_class.call(metric: :sql_count, baseline_samples: Array.new(5, 0),
                                    candidate_samples: Array.new(5, 1), config: config)

      expect(result["decision"]).to eq("warn")
      expect(result["change_percent"]).to be_nil
    end
  end
end
