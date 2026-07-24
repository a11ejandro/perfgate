# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "baseline/storage/filesystem"

RSpec.describe Baseline::Storage::Filesystem do
  let(:run_result) do
    {
      "schema_version" => 1,
      "run_id" => "11111111-1111-1111-1111-111111111111",
      "created_at" => "2024-01-01T00:00:00Z",
      "workloads" => [{ "id" => "w1", "status" => "completed", "error" => nil, "samples" => [], "summary" => {} }]
    }
  end

  around do |example|
    Dir.mktmpdir { |dir| @root = dir and example.run }
  end

  subject(:storage) { described_class.new(root: @root) }

  describe "#save_run" do
    it "writes run.json, manifest.json, and checksums.json under runs/<run_id>" do
      dir = storage.save_run(run_result)

      expect(dir).to eq(File.join(@root, "runs", run_result["run_id"]))
      %w[run.json manifest.json checksums.json].each do |file|
        expect(File.exist?(File.join(dir, file))).to be true
      end
    end

    it "records the workload ids in the manifest" do
      dir = storage.save_run(run_result)
      manifest = JSON.parse(File.read(File.join(dir, "manifest.json")))

      expect(manifest["workload_ids"]).to eq(["w1"])
    end
  end

  describe "#load_run" do
    it "round-trips a saved run result" do
      storage.save_run(run_result)

      expect(storage.load_run(run_result["run_id"])).to eq(run_result)
    end

    it "raises ResultBundleError when the run does not exist" do
      expect { storage.load_run("does-not-exist") }.to raise_error(Baseline::ResultBundleError, /no run result/)
    end

    it "raises ResultBundleError when the checksum has been tampered with" do
      storage.save_run(run_result)
      run_json_path = File.join(@root, "runs", run_result["run_id"], "run.json")
      File.write(run_json_path, JSON.pretty_generate(run_result.merge("run_id" => "tampered")))

      expect { storage.load_run(run_result["run_id"]) }.to raise_error(Baseline::ResultBundleError, /checksum mismatch/)
    end
  end

  describe "#list_runs" do
    it "lists saved run ids" do
      storage.save_run(run_result)
      other = run_result.merge("run_id" => "22222222-2222-2222-2222-222222222222")
      storage.save_run(other)

      expect(storage.list_runs).to contain_exactly(run_result["run_id"], other["run_id"])
    end

    it "returns an empty array when no runs have been saved" do
      expect(storage.list_runs).to eq([])
    end
  end

  describe "#save_comparison" do
    it "is not implemented yet" do
      expect { storage.save_comparison({}) }.to raise_error(NotImplementedError)
    end
  end
end
