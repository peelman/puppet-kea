# frozen_string_literal: true

require 'spec_helper'

describe 'kea::dhcp6::subnets' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with no subnets defined' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/subnets6.d').with(
            'ensure'  => 'directory',
            'owner'   => 'root',
            'group'   => 'root',
            'mode'    => '0755',
            'purge'   => true,
            'force'   => true,
            'recurse' => true,
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6-subnets.json').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end

        # Empty array when no subnets
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6-subnets.json').with_content(
            %r{^\[\s*\]$}m
          )
        end

        # Shared networks directory should exist
        it do
          is_expected.to contain_file('/etc/kea/shared-networks6.d').with(
            'ensure'  => 'directory',
            'owner'   => 'root',
            'group'   => 'root',
            'mode'    => '0755',
            'purge'   => true,
            'force'   => true,
            'recurse' => true,
          )
        end

        # Shared networks file should exist (empty array)
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6-shared-networks.json').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end
      end

      context 'with subnet with user-provided name' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'subnets'    => [
                {
                  'name'   => 'office-lan-v6',
                  'subnet' => '2001:db8:1::/64',
                  'pools'  => [{ 'pool' => '2001:db8:1::100 - 2001:db8:1::200' }],
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        # Should use the user-provided name for the filename
        it do
          is_expected.to contain_file('/etc/kea/subnets6.d/office-lan-v6.json').with_ensure('file')
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6-subnets.json').with_content(
            %r{subnets6\.d/office-lan-v6\.json}
          )
        end
      end

      context 'with subnet without name (uses CIDR)' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'subnets'    => [
                {
                  'subnet' => '2001:db8:1::/64',
                  'pools'  => [{ 'pool' => '2001:db8:1::100 - 2001:db8:1::200' }],
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        # Should use CIDR with colons/slashes as dashes, collapsed: 2001-db8-1-64.json
        it do
          is_expected.to contain_file('/etc/kea/subnets6.d/2001-db8-1-64.json').with_ensure('file')
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6-subnets.json').with_content(
            %r{subnets6\.d/2001-db8-1-64\.json}
          )
        end
      end
    end
  end
end
