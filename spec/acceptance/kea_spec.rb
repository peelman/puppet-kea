# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'kea class' do
  context 'with dhcp4 enabled' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp4 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'subnets'    => [
            {
              'id'     => 1,
              'subnet' => '192.168.100.0/24',
              'pools'  => [
                { 'pool' => '192.168.100.100 - 192.168.100.200' }
              ],
              'option-data' => [
                { 'name' => 'routers', 'data' => '192.168.100.1' },
                { 'name' => 'domain-name-servers', 'data' => '8.8.8.8, 8.8.4.4' }
              ]
            }
          ]
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      # First run - should make changes
      apply_manifest(manifest, catch_failures: true)
      # Second run - should be idempotent
      apply_manifest(manifest, catch_changes: true)
    end

    describe package('isc-kea-common') do
      it { is_expected.to be_installed }
    end

    describe package('isc-kea-dhcp4') do
      it { is_expected.to be_installed }
    end

    describe package('isc-kea-admin') do
      it { is_expected.to be_installed }
    end

    describe file('/etc/kea') do
      it { is_expected.to be_directory }
      it { is_expected.to be_owned_by 'root' }
    end

    describe file('/etc/kea/kea-dhcp4.conf') do
      it { is_expected.to be_file }
      it { is_expected.to be_owned_by 'root' }
      its(:content) { is_expected.to match(/"Dhcp4":/) }
      its(:content) { is_expected.to match(/"subnet4":/) }
      its(:content) { is_expected.to match(/192\.168\.100\.0\/24/) }
    end

    describe 'kea-dhcp4 config syntax' do
      it 'is valid JSON and passes kea-dhcp4 -t check' do
        result = shell('kea-dhcp4 -t /etc/kea/kea-dhcp4.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp4-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe 'systemctl status' do
      it 'shows isc-kea-dhcp4-server as active' do
        result = shell('systemctl status isc-kea-dhcp4-server', acceptable_exit_codes: [0])
        expect(result.stdout).to match(/Active: active \(running\)/)
      end
    end
  end

  context 'with dhcp6 enabled' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp6 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'subnets'    => [
            {
              'id'     => 1,
              'subnet' => '2001:db8:1::/64',
              'pools'  => [
                { 'pool' => '2001:db8:1::100 - 2001:db8:1::200' }
              ]
            }
          ]
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe package('isc-kea-dhcp6') do
      it { is_expected.to be_installed }
    end

    describe file('/etc/kea/kea-dhcp6.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/"Dhcp6":/) }
      its(:content) { is_expected.to match(/"subnet6":/) }
      its(:content) { is_expected.to match(/2001:db8:1::\/64/) }
    end

    describe 'kea-dhcp6 config syntax' do
      it 'is valid JSON and passes kea-dhcp6 -t check' do
        result = shell('kea-dhcp6 -t /etc/kea/kea-dhcp6.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp6-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe 'systemctl status' do
      it 'shows isc-kea-dhcp6-server as active' do
        result = shell('systemctl status isc-kea-dhcp6-server', acceptable_exit_codes: [0])
        expect(result.stdout).to match(/Active: active \(running\)/)
      end
    end
  end

  context 'with ddns enabled' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        ddns => {
          'enable'       => true,
          'forward_ddns' => {
            'ddns_domains' => [
              {
                'name'        => 'example.com.',
                'dns_servers' => [
                  { 'ip_address' => '127.0.0.1', 'port' => 53 }
                ]
              }
            ]
          }
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe package('isc-kea-dhcp-ddns') do
      it { is_expected.to be_installed }
    end

    describe file('/etc/kea/kea-dhcp-ddns.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/"DhcpDdns":/) }
    end

    describe 'kea-dhcp-ddns config syntax' do
      it 'is valid JSON and passes kea-dhcp-ddns -t check' do
        result = shell('kea-dhcp-ddns -t /etc/kea/kea-dhcp-ddns.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp-ddns-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe 'systemctl status' do
      it 'shows isc-kea-dhcp-ddns-server as active' do
        result = shell('systemctl status isc-kea-dhcp-ddns-server', acceptable_exit_codes: [0])
        expect(result.stdout).to match(/Active: active \(running\)/)
      end
    end
  end

  context 'with all components enabled' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp4 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'subnets'    => [
            {
              'id'     => 1,
              'subnet' => '10.0.0.0/24',
              'pools'  => [
                { 'pool' => '10.0.0.100 - 10.0.0.200' }
              ]
            }
          ]
        },
        dhcp6 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'subnets'    => [
            {
              'id'     => 1,
              'subnet' => '2001:db8:2::/64',
              'pools'  => [
                { 'pool' => '2001:db8:2::100 - 2001:db8:2::200' }
              ]
            }
          ]
        },
        ddns => {
          'enable' => true,
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe 'all services running' do
      it 'has isc-kea-dhcp4-server running' do
        result = shell('systemctl is-active isc-kea-dhcp4-server', acceptable_exit_codes: [0])
        expect(result.stdout.strip).to eq('active')
      end

      it 'has isc-kea-dhcp6-server running' do
        result = shell('systemctl is-active isc-kea-dhcp6-server', acceptable_exit_codes: [0])
        expect(result.stdout.strip).to eq('active')
      end

      it 'has isc-kea-dhcp-ddns-server running' do
        result = shell('systemctl is-active isc-kea-dhcp-ddns-server', acceptable_exit_codes: [0])
        expect(result.stdout.strip).to eq('active')
      end
    end

    describe 'all configs valid' do
      it 'kea-dhcp4.conf is valid' do
        result = shell('kea-dhcp4 -t /etc/kea/kea-dhcp4.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end

      it 'kea-dhcp6.conf is valid' do
        result = shell('kea-dhcp6 -t /etc/kea/kea-dhcp6.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end

      it 'kea-dhcp-ddns.conf is valid' do
        result = shell('kea-dhcp-ddns -t /etc/kea/kea-dhcp-ddns.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end
  end
end
