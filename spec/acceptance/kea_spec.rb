# frozen_string_literal: true

require_relative 'spec_helper_acceptance'

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
      it { is_expected.to be_owned_by '_kea' }
    end

    describe file('/etc/kea/kea-dhcp4.conf') do
      it { is_expected.to be_file }
      it { is_expected.to be_owned_by 'root' }
      its(:content) { is_expected.to match(/"Dhcp4":/) }
      its(:content) { is_expected.to match(/"subnet4":/) }
    end

    describe file('/etc/kea/kea-dhcp4-subnets.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{<\?include "/etc/kea/subnets4.d/192\.168\.100\.0-24\.json"\?>}) }
    end

    describe file('/etc/kea/subnets4.d/192.168.100.0-24.json') do
      it { is_expected.to be_file }
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
    end

    describe file('/etc/kea/kea-dhcp6-subnets.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{<\?include "/etc/kea/subnets6.d/2001-db8-1-64\.json"\?>}) }
    end

    describe file('/etc/kea/subnets6.d/2001-db8-1-64.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{2001:db8:1::/64}) }
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
                'dns-servers' => [
                  { 'ip-address' => '127.0.0.1', 'port' => 53 }
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

  # ============================================================================
  # Complex Configuration Tests
  # ============================================================================

  context 'with multiple subnets and named files' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp4 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'valid_lifetime' => 7200,
          'renew_timer'    => 1800,
          'rebind_timer'   => 3600,
          'option_data'    => [
            { 'name' => 'domain-name', 'data' => 'example.com' },
            { 'name' => 'domain-name-servers', 'data' => '10.0.0.1, 10.0.0.2' },
          ],
          'subnets' => [
            {
              'name'   => 'office-lan',
              'subnet' => '10.10.0.0/24',
              'pools'  => [
                { 'pool' => '10.10.0.100 - 10.10.0.200' }
              ],
              'option_data' => [
                { 'name' => 'routers', 'data' => '10.10.0.1' },
              ],
              'reservations' => [
                {
                  'hw-address' => '00:11:22:33:44:55',
                  'ip-address' => '10.10.0.10',
                  'hostname'   => 'printer1',
                },
                {
                  'hw-address' => '00:11:22:33:44:56',
                  'ip-address' => '10.10.0.11',
                  'hostname'   => 'printer2',
                },
              ],
            },
            {
              'name'   => 'guest-wifi',
              'subnet' => '10.20.0.0/24',
              'pools'  => [
                { 'pool' => '10.20.0.50 - 10.20.0.250' }
              ],
              'option_data' => [
                { 'name' => 'routers', 'data' => '10.20.0.1' },
              ],
              'valid_lifetime' => 3600,
            },
            {
              'subnet' => '10.30.0.0/24',
              'pools'  => [
                { 'pool' => '10.30.0.100 - 10.30.0.200' }
              ],
              'option_data' => [
                { 'name' => 'routers', 'data' => '10.30.0.1' },
              ],
            },
          ],
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe file('/etc/kea/subnets4.d/office-lan.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/10\.10\.0\.0\/24/) }
      its(:content) { is_expected.to match(/00:11:22:33:44:55/) }
      its(:content) { is_expected.to match(/printer1/) }
    end

    describe file('/etc/kea/subnets4.d/guest-wifi.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/10\.20\.0\.0\/24/) }
      its(:content) { is_expected.to match(/"valid-lifetime": 3600/) }
    end

    # Unnamed subnet uses CIDR format
    describe file('/etc/kea/subnets4.d/10.30.0.0-24.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/10\.30\.0\.0\/24/) }
    end

    describe file('/etc/kea/kea-dhcp4-subnets.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/office-lan\.json/) }
      its(:content) { is_expected.to match(/guest-wifi\.json/) }
      its(:content) { is_expected.to match(/10\.30\.0\.0-24\.json/) }
    end

    describe 'kea-dhcp4 config syntax' do
      it 'is valid' do
        result = shell('kea-dhcp4 -t /etc/kea/kea-dhcp4.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp4-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end

  context 'with shared networks' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp4 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
        },
      }

      # Shared networks via Hiera simulation - use class resource
      file { '/etc/kea/shared-networks4.d/campus-building-a.json':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => '{
  "name": "campus-building-a",
  "interface": "eth0",
  "subnet4": [
    {
      "id": 100,
      "subnet": "192.168.10.0/24",
      "pools": [{ "pool": "192.168.10.100 - 192.168.10.200" }],
      "option-data": [{ "name": "routers", "data": "192.168.10.1" }]
    },
    {
      "id": 101,
      "subnet": "192.168.11.0/24",
      "pools": [{ "pool": "192.168.11.100 - 192.168.11.200" }],
      "option-data": [{ "name": "routers", "data": "192.168.11.1" }]
    }
  ]
}',
        require => File['/etc/kea/shared-networks4.d'],
        notify  => Service['isc-kea-dhcp4-server'],
      }

      # Update shared networks include file
      file { '/etc/kea/kea-dhcp4-shared-networks.json':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => '[
  <?include "/etc/kea/shared-networks4.d/campus-building-a.json"?>
]
',
        require => File['/etc/kea/shared-networks4.d/campus-building-a.json'],
        notify  => Service['isc-kea-dhcp4-server'],
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe file('/etc/kea/shared-networks4.d') do
      it { is_expected.to be_directory }
    end

    describe file('/etc/kea/shared-networks4.d/campus-building-a.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/"name": "campus-building-a"/) }
      its(:content) { is_expected.to match(/192\.168\.10\.0\/24/) }
      its(:content) { is_expected.to match(/192\.168\.11\.0\/24/) }
    end

    describe file('/etc/kea/kea-dhcp4-shared-networks.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/campus-building-a\.json/) }
    end

    describe 'kea-dhcp4 config syntax' do
      it 'is valid' do
        result = shell('kea-dhcp4 -t /etc/kea/kea-dhcp4.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp4-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end

  context 'with DHCPv6 prefix delegation' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp6 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'subnets'    => [
            {
              'name'   => 'isp-customers',
              'subnet' => '2001:db8::/32',
              'pools'  => [
                { 'pool' => '2001:db8::1000 - 2001:db8::2000' }
              ],
              'pd_pools' => [
                {
                  'prefix'        => '2001:db8:1::',
                  'prefix-len'    => 48,
                  'delegated-len' => 56,
                },
                {
                  'prefix'        => '2001:db8:2::',
                  'prefix-len'    => 48,
                  'delegated-len' => 60,
                },
              ],
              'option_data' => [
                { 'name' => 'dns-servers', 'data' => '2001:db8::53' },
              ],
            },
          ],
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe file('/etc/kea/subnets6.d/isp-customers.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{2001:db8::/32}) }
      its(:content) { is_expected.to match(/"pd-pools"/) }
      its(:content) { is_expected.to match(/"delegated-len": 56/) }
      its(:content) { is_expected.to match(/"delegated-len": 60/) }
    end

    describe 'kea-dhcp6 config syntax' do
      it 'is valid' do
        result = shell('kea-dhcp6 -t /etc/kea/kea-dhcp6.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp6-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end

  context 'with DDNS integration' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp4 => {
          'enable'                      => true,
          'interfaces'                  => ['eth0'],
          'ddns_send_updates'           => true,
          'ddns_qualifying_suffix'      => 'internal.example.com',
          'ddns_override_client_update' => true,
          'ddns_replace_client_name'    => 'when-not-present',
          'subnets' => [
            {
              'name'   => 'ddns-enabled-net',
              'subnet' => '172.16.0.0/24',
              'pools'  => [
                { 'pool' => '172.16.0.100 - 172.16.0.200' }
              ],
              'option_data' => [
                { 'name' => 'routers', 'data' => '172.16.0.1' },
              ],
            },
          ],
        },
        ddns => {
          'enable' => true,
          'forward_ddns' => {
            'ddns_domains' => [
              {
                'name'        => 'internal.example.com.',
                'dns_servers' => [
                  { 'ip_address' => '127.0.0.1', 'port' => 53 }
                ],
              },
            ],
          },
          'reverse_ddns' => {
            'ddns_domains' => [
              {
                'name'        => '16.172.in-addr.arpa.',
                'dns_servers' => [
                  { 'ip_address' => '127.0.0.1', 'port' => 53 }
                ],
              },
            ],
          },
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe file('/etc/kea/kea-dhcp4.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/"ddns-send-updates": true/) }
      its(:content) { is_expected.to match(/"ddns-qualifying-suffix": "internal.example.com"/) }
      its(:content) { is_expected.to match(/"ddns-override-client-update": true/) }
    end

    describe file('/etc/kea/kea-dhcp-ddns.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/internal\.example\.com\./) }
      its(:content) { is_expected.to match(/16\.172\.in-addr\.arpa\./) }
    end

    describe 'all configs valid' do
      it 'kea-dhcp4.conf is valid' do
        result = shell('kea-dhcp4 -t /etc/kea/kea-dhcp4.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end

      it 'kea-dhcp-ddns.conf is valid' do
        result = shell('kea-dhcp-ddns -t /etc/kea/kea-dhcp-ddns.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp4-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe service('isc-kea-dhcp-ddns-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end

  context 'with client classes and conditional options' do
    let(:manifest) do
      <<-PUPPET
      class { 'kea':
        dhcp4 => {
          'enable'     => true,
          'interfaces' => ['eth0'],
          'client_classes' => [
            {
              'name' => 'voip-phones',
              'test' => "substring(option[60].hex,0,6) == 'Polyco'",
              'option-data' => [
                { 'name' => 'tftp-server-name', 'data' => 'tftp.example.com' },
              ],
            },
            {
              'name' => 'workstations',
              'test' => "not member('voip-phones')",
            },
          ],
          'subnets' => [
            {
              'name'   => 'voip-net',
              'subnet' => '10.100.0.0/24',
              'pools'  => [
                {
                  'pool'          => '10.100.0.100 - 10.100.0.200',
                  'client-class'  => 'voip-phones',
                },
                {
                  'pool'          => '10.100.0.10 - 10.100.0.50',
                  'client-class'  => 'workstations',
                },
              ],
              'option_data' => [
                { 'name' => 'routers', 'data' => '10.100.0.1' },
              ],
            },
          ],
        },
      }
      PUPPET
    end

    it 'applies idempotently' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    describe file('/etc/kea/kea-dhcp4.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/"client-classes"/) }
      its(:content) { is_expected.to match(/voip-phones/) }
      its(:content) { is_expected.to match(/tftp-server-name/) }
    end

    describe file('/etc/kea/subnets4.d/voip-net.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(/"client-class"/) }
    end

    describe 'kea-dhcp4 config syntax' do
      it 'is valid' do
        result = shell('kea-dhcp4 -t /etc/kea/kea-dhcp4.conf', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe service('isc-kea-dhcp4-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
