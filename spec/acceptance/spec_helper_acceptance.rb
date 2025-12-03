# frozen_string_literal: true

require 'beaker-rspec'
require 'beaker-puppet'

# Include the BeakerPuppet DSL for install_puppet_on, copy_module_to, etc.
include BeakerPuppet

RSpec.configure do |c|
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install Puppet agent on all hosts
    hosts.each do |host|
      # Install required packages for systemd and Puppet installation
      on host, 'apt-get update && apt-get install -y systemd systemd-sysv curl gnupg wget'

      # Install Puppet agent from Puppetlabs repo (puppet8 for apt 10+ compatibility)
      install_puppet_agent_on(host, puppet_collection: 'puppet8')

      # Add puppet paths to the environment
      host[:type] = 'aio'
      add_aio_defaults_on(host)
      add_puppet_paths_on(host)
    end

    # Copy module to hosts
    copy_module_to(hosts, source: '.', module_name: 'kea')

    # Install dependencies from Puppet Forge
    # apt >= 10.0.0 is required for DEB822 format (latest version will be installed)
    on hosts, puppet('module', 'install', 'puppetlabs-apt')
    on hosts, puppet('module', 'install', 'puppetlabs-stdlib')
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
