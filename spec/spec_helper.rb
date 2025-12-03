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
  c.before :each do
    # Avoid spec failures due to various issues
    Puppet::Util::Log.level = :warning
    Puppet::Util::Log.newdestination(:console)
  end
  c.after(:suite) do
    RSpec::Puppet::Coverage.report!
  end
end

# Helper method to load structured facts
def on_supported_os_filtered
  on_supported_os.select do |os, _facts|
    os =~ /^(debian|ubuntu)/
  end
end
