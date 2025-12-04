# frozen_string_literal: true

require 'beaker-rspec'
require 'beaker-puppet'
require 'json'

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

# Helper to send a command to Kea via control socket
# @param host [Host] The beaker host to run the command on
# @param command [String] The Kea command name (e.g., 'status-get', 'ha-heartbeat')
# @param socket [String] Path to the control socket
# @param service [String] Optional service for command routing
# @param arguments [Hash] Optional arguments for the command
# @return [Hash] Parsed JSON response from Kea (first element if array)
def send_kea_command(host, command, socket: '/run/kea/kea4-ctrl-socket.sock', service: nil, arguments: nil)
  cmd = { 'command' => command }
  cmd['service'] = [service] if service
  cmd['arguments'] = arguments if arguments

  json_cmd = cmd.to_json
  # Use socat to send command to control socket
  result = on(host, "echo '#{json_cmd}' | socat - UNIX-CONNECT:#{socket}", accept_all_exit_codes: true)

  if result.exit_code.zero? && !result.stdout.empty?
    begin
      parsed = JSON.parse(result.stdout)
      # Kea API returns an array of responses - extract first element
      parsed.is_a?(Array) ? parsed[0] : parsed
    rescue JSON::ParserError
      { 'result' => 1, 'text' => 'Failed to parse response', 'raw' => result.stdout }
    end
  else
    { 'result' => 1, 'text' => result.stderr }
  end
end

# Helper to get HA status from a Kea server
# @param host [Host] The beaker host
# @param socket [String] Path to the control socket
# @return [Hash, nil] The HA status hash or nil if not available
def get_ha_status(host, socket: '/run/kea/kea4-ctrl-socket.sock')
  response = send_kea_command(host, 'status-get', socket: socket)
  return nil unless response.is_a?(Hash)
  return nil unless response['result']&.zero? && response['arguments']

  ha_info = response.dig('arguments', 'high-availability')
  return nil unless ha_info.is_a?(Array) && !ha_info.empty?

  ha_info[0]
end

# Helper to wait for HA to reach a specific state
# @param host [Host] The beaker host
# @param expected_state [String] The expected HA state (e.g., 'hot-standby', 'load-balancing', 'ready')
# @param timeout [Integer] Maximum seconds to wait
# @param socket [String] Path to the control socket
# @return [Boolean] True if state was reached, false on timeout
def wait_for_ha_state(host, expected_state, timeout: 30, socket: '/run/kea/kea4-ctrl-socket.sock')
  start_time = Time.now
  last_state = nil

  while (Time.now - start_time) < timeout
    ha_status = get_ha_status(host, socket: socket)

    if ha_status
      local_state = ha_status.dig('ha-servers', 'local', 'state')
      last_state = local_state

      # Handle states that indicate success
      case expected_state
      when 'hot-standby', 'load-balancing'
        # Primary should be in the HA mode state, standby in 'ready' or the mode
        return true if local_state == expected_state || local_state == 'ready'
      else
        return true if local_state == expected_state
      end
    end

    sleep 2
  end

  # Log the last known state for debugging
  puts "Timeout waiting for HA state '#{expected_state}'. Last state: '#{last_state}'"
  false
end

# Helper to check if HA peer is in touch (communicating)
# @param host [Host] The beaker host
# @param socket [String] Path to the control socket
# @return [Boolean] True if remote peer is in touch
def ha_peer_in_touch?(host, socket: '/run/kea/kea4-ctrl-socket.sock')
  ha_status = get_ha_status(host, socket: socket)
  return false unless ha_status

  ha_status.dig('ha-servers', 'remote', 'in-touch') == true
end

# Helper to get host by role in multi-node setup
# @param role [Symbol] The role to find (e.g., :primary, :standby)
# @return [Host, nil] The host with that role or nil
def host_with_role(role)
  hosts.find { |h| h[:roles].include?(role.to_s) }
end
