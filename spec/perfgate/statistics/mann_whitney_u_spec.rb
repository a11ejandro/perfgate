# frozen_string_literal: true

require "perfgate/statistics/mann_whitney_u"

RSpec.describe Perfgate::Statistics::MannWhitneyU do
  describe ".one_sided_p" do
    it "returns a high p-value when the candidate is clearly not worse" do
      baseline = [10, 11, 9, 10, 12, 11, 10, 9]
      candidate = [10, 9, 11, 10, 9, 10, 11, 10]

      expect(described_class.one_sided_p(baseline, candidate)).to be > 0.3
    end

    it "returns a low p-value when the candidate is clearly worse" do
      baseline = [10, 11, 9, 10, 12, 11, 10, 9]
      candidate = [20, 21, 19, 20, 22, 21, 20, 19]

      expect(described_class.one_sided_p(baseline, candidate)).to be < 0.01
    end

    it "returns 1.0 when either sample set is empty" do
      expect(described_class.one_sided_p([], [1, 2, 3])).to eq(1.0)
      expect(described_class.one_sided_p([1, 2, 3], [])).to eq(1.0)
    end

    it "handles tied values without raising" do
      expect { described_class.one_sided_p([5, 5, 5], [5, 5, 5]) }.not_to raise_error
    end

    it "returns approximately 0.5 for identical distributions" do
      values = [1, 2, 3, 4, 5]

      expect(described_class.one_sided_p(values, values)).to be_within(0.1).of(0.5)
    end
  end
end
