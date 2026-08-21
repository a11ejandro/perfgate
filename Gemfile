# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in baselined.gemspec
gemspec

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop", "~> 1.21"

group :development, :test do
  # Used by the Milestone 0 spikes and by the SQL instrumentation specs,
  # which exercise real ActiveSupport::Notifications events rather than
  # stubbing them.
  gem "activerecord", "~> 7.1"
  gem "sqlite3", "~> 1.7"
end
