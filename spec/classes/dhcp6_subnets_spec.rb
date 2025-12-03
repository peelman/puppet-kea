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
      end
    end
  end
end
