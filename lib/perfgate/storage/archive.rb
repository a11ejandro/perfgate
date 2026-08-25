# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require "stringio"
require "zlib"

module Perfgate
  module Storage
    # Packs/unpacks the portable baseline-run-<run-id>.tar.gz archive
    # format (spec 18.2), used to move a run bundle outside of a
    # Filesystem adapter's own root -- e.g. as a manually-downloaded CI
    # artifact. Extraction rejects any entry that would escape the
    # destination directory (spec 22: reject path traversal).
    module Archive
      module_function

      def write(archive_path, dir, run_id)
        tar_io = StringIO.new
        Gem::Package::TarWriter.new(tar_io) do |tar|
          Dir.glob("**/*", File::FNM_DOTMATCH, base: dir).each { |entry| add_entry(tar, dir, run_id, entry) }
        end

        Zlib::GzipWriter.open(archive_path) { |gz| gz.write(tar_io.string) }
      end

      def extract(archive_path, into)
        Zlib::GzipReader.open(archive_path) do |gz|
          Gem::Package::TarReader.new(gz) { |tar| extract_entries(tar, into) }
        end
      end

      def add_entry(tar, dir, run_id, entry)
        return if [".", ".."].include?(File.basename(entry))

        source = File.join(dir, entry)
        name = File.join(run_id, entry)
        if File.directory?(source)
          tar.mkdir(name, 0o755)
        else
          tar.add_file(name, 0o644) { |io| io.write(File.read(source)) }
        end
      end

      def extract_entries(tar, into)
        tar.each do |entry|
          destination = safe_destination(into, entry.full_name)
          entry.directory? ? FileUtils.mkdir_p(destination) : extract_file(entry, destination)
        end
      end

      def extract_file(entry, destination)
        FileUtils.mkdir_p(File.dirname(destination))
        File.write(destination, entry.read)
      end

      def safe_destination(into, entry_name)
        base = File.join(into, "runs")
        destination = File.expand_path(File.join(base, entry_name))

        unless destination.start_with?("#{File.expand_path(base)}/")
          raise Perfgate::ResultBundleError, "archive entry #{entry_name.inspect} escapes the destination directory"
        end

        destination
      end
    end
  end
end
