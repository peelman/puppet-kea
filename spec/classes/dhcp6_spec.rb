# frozen_string_literal: true

require 'spec_helper'

describe 'kea::dhcp6' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) do
        <<-PUPPET
        class { 'kea':
          dhcp6 => {
            'enable' => true,
            'interfaces' => ['eth0'],
          },
        }
        PUPPET
      end

      context 'with minimal configuration' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::dhcp6') }
        it { is_expected.to contain_class('kea::dhcp6::subnets') }

        it { is_expected.to contain_package('isc-kea-dhcp6').with_ensure('installed') }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end

        it do
          is_expected.to contain_service('isc-kea-dhcp6-server').with(
            'ensure'     => 'running',
            'enable'     => true,
            'hasrestart' => true,
            'hasstatus'  => true,
          )
        end

        # Verify config file content
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"Dhcp6":}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"interfaces": \["eth0"\]}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"valid-lifetime": 4000}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"preferred-lifetime": 3000}
          )
        end
      end

      context 'with custom lifetimes' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'             => true,
              'interfaces'         => ['eth0'],
              'valid_lifetime'     => 7200,
              'preferred_lifetime' => 5400,
              'renew_timer'        => 1800,
              'rebind_timer'       => 3600,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"valid-lifetime": 7200}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"preferred-lifetime": 5400}
          )
        end
      end

      context 'with MySQL backend' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            mysql_backend => true,
            dhcp6 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'lease_database' => {
                'type'     => 'mysql',
                'name'     => 'kea_leases6',
                'host'     => 'db.example.com',
                'port'     => 3306,
                'user'     => 'kea_user',
                'password' => 'secret123',
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"type": "mysql"}
          )
        end
      end

      context 'with DDNS enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'                   => true,
              'interfaces'               => ['eth0'],
              'ddns_send_updates'        => true,
              'ddns_qualifying_suffix'   => 'example.com',
              'ddns_replace_client_name' => 'when-not-present',
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"ddns-send-updates": true}
          )
        end
      end

      context 'with global options' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'      => true,
              'interfaces'  => ['eth0'],
              'option_data' => [
                {
                  'name' => 'dns-servers',
                  'data' => '2001:db8::1, 2001:db8::2',
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"option-data":.*"name":"dns-servers"}m
          )
        end
      end

      context 'with expired leases processing' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'expired_leases_processing' => {
                'reclaim_timer_wait_time'         => 10,
                'flush_reclaimed_timer_wait_time' => 25,
                'hold_reclaimed_time'             => 3600,
                'max_reclaim_leases'              => 100,
                'max_reclaim_time'                => 250,
                'unwarned_reclaim_cycles'         => 5,
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"expired-leases-processing":}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"reclaim-timer-wait-time": 10}
          )
        end
      end

      context 'with sanity checks' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'        => true,
              'interfaces'    => ['eth0'],
              'sanity_checks' => {
                'lease_checks' => 'fix-del',
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"sanity-checks":.*"lease-checks": "fix-del"}m
          )
        end
      end

      context 'with tee times and allocators' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'              => true,
              'interfaces'          => ['eth0'],
              'calculate_tee_times' => true,
              't1_percent'          => 0.5,
              't2_percent'          => 0.8,
              'allocator'           => 'random',
              'pd_allocator'        => 'iterative',
            },
          }
          PUPPET
        end
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"calculate-tee-times": true}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"allocator": "random"}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"pd-allocator": "iterative"}
          )
        end
      end

      context 'with store extended info' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'              => true,
              'interfaces'          => ['eth0'],
              'store_extended_info' => true,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp6.conf').with_content(
            %r{"store-extended-info": true}
          )
        end
      end

      context 'with service stopped' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp6 => {
              'enable'         => true,
              'service_ensure' => 'stopped',
              'service_enable' => false,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_service('isc-kea-dhcp6-server').with(
            'ensure' => 'stopped',
            'enable' => false,
          )
        end
      end
    end
  end
end
