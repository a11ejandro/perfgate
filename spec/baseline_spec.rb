# frozen_string_literal: true

RSpec.describe Baseline do
  it "has a version number" do
    expect(Baseline::VERSION).not_to be nil
  end

  describe ".measure" do
    it "is not implemented yet" do
      expect { described_class.measure }.to raise_error(NotImplementedError)
    end
  end
end
