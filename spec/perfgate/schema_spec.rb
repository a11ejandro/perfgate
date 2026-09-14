# frozen_string_literal: true

require "json"
require "perfgate/comparison/engine"
require "perfgate/serialization/run_result"

RSpec.describe "evidence JSON Schemas" do
  def schema(name)
    JSON.parse(File.read(File.expand_path("../../schemas/#{name}", __dir__)))
  end

  it "publishes the complete run-result v2 evidence fields" do
    document = schema("run-result-v2.schema.json")

    expect(document.dig("properties", "schema_version", "const")).to eq(
      Perfgate::Serialization::RunResult::SCHEMA_VERSION
    )
    expect(document["required"]).to include("fingerprint", "experiment_plan", "analysis_configuration", "policy")
    workload = document.dig("properties", "workloads", "items")
    expect(workload["required"]).to include("assurance", "source", "exclusions", "samples")
  end

  it "defines comparison metrics rather than accepting placeholder workload objects" do
    document = schema("comparison-result-v2.schema.json")

    expect(document.dig("properties", "schema_version", "const")).to eq(Perfgate::Comparison::Engine::SCHEMA_VERSION)
    expect(document.dig("definitions", "metric", "required")).to include(
      "estimand", "interval", "thresholds", "rule", "baseline_sample_size", "candidate_sample_size"
    )
    expect(document.dig("definitions", "workload", "additionalProperties")).to be(false)
  end
end
