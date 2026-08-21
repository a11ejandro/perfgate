# frozen_string_literal: true

require_relative "lib/baselined/version"

Gem::Specification.new do |spec|
  spec.name = "baselined"
  spec.version = Baselined::VERSION
  spec.authors = ["Alexander Potrakhov"]
  spec.email = ["bendthe@gmail.com"]

  spec.summary = "CI-native performance regression assurance for Rails and RSpec."
  spec.description = "Baseline converts selected RSpec examples into repeatable performance " \
                     "workloads, measures application-level signals (duration, SQL activity, " \
                     "allocations, GC), compares a pull request against a compatible " \
                     "default-branch baseline, and produces a clear CI merge-gate decision."
  spec.homepage = "https://github.com/baseline-oss/baselined"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ spikes/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", "~> 3.12"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
