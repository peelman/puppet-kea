# frozen_string_literal: true

source 'https://rubygems.org'

gem 'puppet', ENV.fetch('PUPPET_GEM_VERSION', '>= 7.0'), require: false
gem 'facterdb', require: false

group :development, :test do
  gem 'rake'
  gem 'rspec'
  gem 'rspec-puppet', '~> 4.0'
  gem 'rspec-puppet-facts'
  gem 'puppetlabs_spec_helper', '>= 7.0'
  gem 'metadata-json-lint'
  gem 'puppet-lint'
  gem 'puppet-syntax'
end

group :acceptance do
  gem 'beaker'
  gem 'beaker-puppet'
  gem 'beaker-rspec'
  gem 'beaker-docker'
  gem 'beaker-puppet_install_helper'
  gem 'beaker-module_install_helper'
end
