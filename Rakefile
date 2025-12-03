# frozen_string_literal: true

require 'bundler/setup'
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'
require 'metadata-json-lint/rake_task'

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