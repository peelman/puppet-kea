# frozen_string_literal: true

require 'bundler/setup'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'
require 'metadata-json-lint/rake_task'

# Load Blacksmith tasks for Forge publishing
begin
  require 'puppet_blacksmith/rake_tasks'
rescue LoadError
  # Blacksmith not installed - skip release tasks
end

# Load Beaker tasks if gems are available
begin
  require 'beaker-rspec/rake_task'

  # Create beaker tasks for each nodeset
  Dir['spec/acceptance/nodesets/*.yml'].each do |nodeset|
    name = File.basename(nodeset, '.yml')
    desc "Run acceptance tests on #{name}"
    RSpec::Core::RakeTask.new("beaker:#{name}") do |t|
      ENV['BEAKER_setfile'] = nodeset
      t.pattern = 'spec/acceptance/**/*_spec.rb'
      t.rspec_opts = ['--color']
    end
  end
rescue LoadError
  # Beaker gems not installed - skip acceptance tasks
end

PuppetLint.configuration.send('disable_80chars')
PuppetLint.configuration.send('disable_140chars')
PuppetLint.configuration.relative_pattern = ['manifests/**/*.pp']
# Exclude spec fixtures, packaged files and any vendored/bundled gems so linting
# doesn't scan gem fixtures under vendor/bundle which caused the CI failures.
PuppetLint.configuration.ignore_paths = ['spec/**/*.pp', 'pkg/**/*.pp', 'vendor/**/*', '.bundle/**/*']

# Puppet Syntax configuration - exclude the same vendored paths
PuppetSyntax.exclude_paths = ['spec/**/*', 'pkg/**/*', 'vendor/**/*', '.bundle/**/*']

desc 'Run all validation and tests'
task default: [:validate, :lint, :metadata_lint, :spec]

desc 'Run syntax, lint, and spec tests'
task test: [:syntax, :lint, :spec]

desc 'Generate documentation coverage report'
task :doc do
  sh 'puppet strings generate --format markdown'
end