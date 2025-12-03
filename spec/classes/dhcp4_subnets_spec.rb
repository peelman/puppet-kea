# frozen_string_literal: true

require 'spec_helper'

describe 'kea::dhcp4::subnets' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with no subnets defined' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/subnets4.d').with(
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0755',
            'purge'  => true,
            'force'  => true,
            'recurse' => true,
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4-subnets.json').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end

        # Empty array when no subnets
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4-subnets.json').with_content(
            %r{^\[\s*\]$}m
          )
        end

        # Shared networks directory should exist
        it do
          is_expected.to contain_file('/etc/kea/shared-networks4.d').with(
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0755',
            'purge'  => true,
            'force'  => true,
            'recurse' => true,
          )
        end

        # Shared networks file should exist (empty array)
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4-shared-networks.json').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end
      end

      context 'with subnets from Hiera' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
            },
          }
          PUPPET
        end

        let(:params) do
          {}
        end

        # Simulate Hiera lookup by setting up automatic parameter lookup
        let(:hieradata) { 'dhcp4_subnets' }

        # For this test we need to provide data differently
        # We'll use the class parameters directly in pre_condition
      end

      context 'with single subnet' do
        let(:pre_condition) do
          <<-PUPPET
          # Define lookup functions for testing
          function kea::dhcp4_subnets() {
            {
              'office' => {
                'subnet'  => '192.168.1.0/24',
                'pools'   => [{ 'pool' => '192.168.1.100 - 192.168.1.200' }],
                'option_data' => [
                  { 'name' => 'routers', 'data' => '192.168.1.1' },
                ],
              },
            }
          }

          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/subnets4.d').with_ensure('directory')
        end
      end

      context 'with subnet with user-provided name' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'subnets'    => [
                {
                  'name'   => 'office-lan',
                  'subnet' => '192.168.1.0/24',
                  'pools'  => [{ 'pool' => '192.168.1.100 - 192.168.1.200' }],
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        # Should use the user-provided name for the filename
        it do
          is_expected.to contain_file('/etc/kea/subnets4.d/office-lan.json').with_ensure('file')
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4-subnets.json').with_content(
            %r{subnets4\.d/office-lan\.json}
          )
        end
      end

      context 'with subnet without name (uses CIDR)' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'subnets'    => [
                {
                  'subnet' => '192.168.1.0/24',
                  'pools'  => [{ 'pool' => '192.168.1.100 - 192.168.1.200' }],
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        # Should use CIDR with slash replaced by dash: 192.168.1.0-24.json
        it do
          is_expected.to contain_file('/etc/kea/subnets4.d/192.168.1.0-24.json').with_ensure('file')
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4-subnets.json').with_content(
            %r{subnets4\.d/192\.168\.1\.0-24\.json}
          )
        end
      end
    end
  end
end
