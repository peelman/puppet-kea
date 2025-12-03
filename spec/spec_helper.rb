# frozen_string_literal: true

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

# Configure SimpleCov for code coverage
if ENV['COVERAGE'] == 'yes'
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    track_files 'manifests/**/*.pp'
    enable_coverage :branch
  end

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Console
  ])
end

# Default facts for all tests
default_facts = {
  puppetversion: Puppet.version,
  facterversion: Facter.version,
}

RSpec.configure do |c|
  c.default_facts = default_facts
  c.hiera_config = File.expand_path(File.join(__FILE__, '..', 'fixtures', 'hiera.yaml'))
  c.mock_with :rspec
  c.before :each do
    # Set log level to warning but don't output to console by default
    Puppet::Util::Log.level = :warning
  end
  c.after(:suite) do
    RSpec::Puppet::Coverage.report!
  end
end

# Suppress "Found multiple default providers for file: posix, windows" warnings
# by setting the default provider for file type before tests run
if Puppet::Type.type(:file).respond_to?(:defaultprovider=)
  Puppet::Type.type(:file).defaultprovider = Puppet::Type.type(:file).provider(:posix)
end

# Helper method to load structured facts
def on_supported_os_filtered
  on_supported_os.select do |os, _facts|
    os =~ /^(debian|ubuntu)/
  end
end
