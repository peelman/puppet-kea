# frozen_string_literal: true

require 'beaker-rspec'
require 'beaker-puppet'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'

# Install Puppet agent on all hosts
run_puppet_install_helper unless ENV['BEAKER_provision'] == 'no'

RSpec.configure do |c|
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module dependencies
    hosts.each do |host|
      # Install required packages for systemd in Docker
      on host, 'apt-get update && apt-get install -y systemd systemd-sysv curl gnupg'

      # Copy module to host
      copy_module_to(host, source: File.dirname(__dir__) + '/..', module_name: 'kea')

      # Install dependencies from metadata.json
      on host, puppet('module', 'install', 'puppetlabs-apt', '--version', '>=9.0.0 <11.0.0')
      on host, puppet('module', 'install', 'puppetlabs-stdlib', '--version', '>=9.0.0 <10.0.0')
    end
  end
end

# Helper to apply manifest and check for idempotency
def apply_manifest_on_with_retry(host, manifest, opts = {})
  apply_manifest_on(host, manifest, opts)
end

# Helper to check if a service is running
def service_running?(host, service_name)
  result = on(host, "systemctl is-active #{service_name}", accept_all_exit_codes: true)
  result.exit_code.zero?
end

# Helper to check config syntax
def kea_config_valid?(host, config_file, daemon = 'kea-dhcp4')
  result = on(host, "#{daemon} -t #{config_file}", accept_all_exit_codes: true)
  result.exit_code.zero?
end
