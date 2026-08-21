# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "rubygems/package"
require "stringio"
require "zlib"
require "baselined/storage/filesystem"

RSpec.describe Baselined::Storage::Filesystem do
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
      expect { storage.load_run("does-not-exist") }.to raise_error(Baselined::ResultBundleError, /no run result/)
    end

    it "raises ResultBundleError when the checksum has been tampered with" do
      storage.save_run(run_result)
      run_json_path = File.join(@root, "runs", run_result["run_id"], "run.json")
      File.write(run_json_path, JSON.pretty_generate(run_result.merge("run_id" => "tampered")))

      expect { storage.load_run(run_result["run_id"]) }.to raise_error(Baselined::ResultBundleError, /checksum mismatch/)
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
    it "writes the comparison document under comparisons/<comparison-id>.json" do
      comparison_result = { "schema_version" => 1, "baseline_run_id" => "b", "candidate_run_id" => "c",
                            "decision" => "pass" }

      path = storage.save_comparison(comparison_result)

      expect(path).to match(%r{comparisons/[0-9a-f-]{36}\.json\z})
      expect(JSON.parse(File.read(path))).to eq(comparison_result)
    end

    it "generates a distinct comparison id on each call" do
      first = storage.save_comparison({ "decision" => "pass" })
      second = storage.save_comparison({ "decision" => "pass" })

      expect(first).not_to eq(second)
    end
  end

  describe "#export_archive / #import_archive" do
    it "round-trips a run bundle through a baseline-run-<run-id>.tar.gz archive" do
      storage.save_run(run_result)

      archive_path = storage.export_archive(run_result["run_id"])
      expect(archive_path).to eq(File.join(@root, "baseline-run-#{run_result["run_id"]}.tar.gz"))

      into = Dir.mktmpdir
      other = described_class.new(root: into)
      run_dir = other.import_archive(archive_path, into: into)

      expect(other.load_run(run_dir)).to eq(run_result)
    ensure
      FileUtils.remove_entry(into) if into
    end

    it "raises ResultBundleError when exporting a run that does not exist" do
      expect { storage.export_archive("does-not-exist") }.to raise_error(Baselined::ResultBundleError, /no run bundle/)
    end

    it "rejects an archive entry that attempts path traversal on import" do
      archive_path = File.join(@root, "malicious.tar.gz")
      write_malicious_archive(archive_path)

      expect { storage.import_archive(archive_path, into: @root) }
        .to raise_error(Baselined::ResultBundleError, /escapes the destination directory/)
    end
  end

  def write_malicious_archive(archive_path)
    tar_io = StringIO.new
    Gem::Package::TarWriter.new(tar_io) do |tar|
      tar.add_file("../../etc/evil.json", 0o644) { |io| io.write("{}") }
    end
    Zlib::GzipWriter.open(archive_path) { |gz| gz.write(tar_io.string) }
  end
end
