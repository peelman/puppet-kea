# frozen_string_literal: true

require 'spec_helper'

describe 'kea::dhcp4' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) do
        <<-PUPPET
        class { 'kea':
          dhcp4 => {
            'enable' => true,
            'interfaces' => ['eth0'],
          },
        }
        PUPPET
      end

      context 'with minimal configuration' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::dhcp4') }
        it { is_expected.to contain_class('kea::dhcp4::subnets') }

        it { is_expected.to contain_package('isc-kea-dhcp4').with_ensure('installed') }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end

        it do
          is_expected.to contain_service('isc-kea-dhcp4-server').with(
            'ensure'     => 'running',
            'enable'     => true,
            'hasrestart' => true,
            'hasstatus'  => true,
          )
        end

        # Verify config file content
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"Dhcp4":}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"interfaces": \["eth0"\]}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"valid-lifetime": 4000}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"lease-database":.*"type": "memfile"}m
          )
        end
      end

      context 'with custom lifetimes' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'         => true,
              'interfaces'     => ['eth0'],
              'valid_lifetime' => 7200,
              'renew_timer'    => 1800,
              'rebind_timer'   => 3600,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"valid-lifetime": 7200}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"renew-timer": 1800}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"rebind-timer": 3600}
          )
        end
      end

      context 'with MySQL backend' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            mysql_backend => true,
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'lease_database' => {
                'type'     => 'mysql',
                'name'     => 'kea_leases',
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
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"type": "mysql"}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"name": "kea_leases"}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"host": "db.example.com"}
          )
        end
      end

      context 'with PostgreSQL backend' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            postgresql_backend => true,
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'lease_database' => {
                'type'     => 'postgresql',
                'name'     => 'kea_db',
                'host'     => 'pgsql.example.com',
                'port'     => 5432,
                'user'     => 'kea',
                'password' => 'secret',
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"type": "postgresql"}
          )
        end
      end

      context 'with DDNS enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
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
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"ddns-send-updates": true}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"ddns-qualifying-suffix": "example.com"}
          )
        end
      end

      context 'with global options' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'      => true,
              'interfaces'  => ['eth0'],
              'option_data' => [
                {
                  'name' => 'domain-name-servers',
                  'data' => '8.8.8.8, 8.8.4.4',
                },
                {
                  'name' => 'domain-name',
                  'data' => 'example.com',
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"option-data":.*"name":"domain-name-servers"}m
          )
        end
      end

      context 'with hooks libraries' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'          => true,
              'interfaces'      => ['eth0'],
              'hooks_libraries' => [
                {
                  'library' => '/usr/lib/x86_64-linux-gnu/kea/hooks/libdhcp_lease_cmds.so',
                },
                {
                  'library' => '/usr/lib/x86_64-linux-gnu/kea/hooks/libdhcp_stat_cmds.so',
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"hooks-libraries":.*libdhcp_lease_cmds.so}m
          )
        end
      end

      context 'with client classes' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'         => true,
              'interfaces'     => ['eth0'],
              'client_classes' => [
                {
                  'name' => 'voip-phones',
                  'test' => "substring(option[60].hex,0,6) == 'Polycom'",
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"client-classes":.*"name":"voip-phones"}m
          )
        end
      end

      context 'with expired leases processing' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
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
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"expired-leases-processing":}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"reclaim-timer-wait-time": 10}
          )
        end
      end

      context 'with sanity checks' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
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
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"sanity-checks":.*"lease-checks": "fix-del"}m
          )
        end
      end

      context 'with tee times configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'              => true,
              'interfaces'          => ['eth0'],
              'calculate_tee_times' => true,
              't1_percent'          => 0.5,
              't2_percent'          => 0.8,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"calculate-tee-times": true}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"t1-percent": 0.5}
          )
        end
      end

      context 'with allocator configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'allocator'  => 'random',
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"allocator": "random"}
          )
        end
      end

      context 'with custom logging' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'logging'    => {
                'severity'   => 'DEBUG',
                'debuglevel' => 50,
                'output'     => '/var/log/kea/kea-dhcp4-debug.log',
                'maxsize'    => 20971520,
                'maxver'     => 10,
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"severity": "DEBUG"}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"debuglevel": 50}
          )
        end
      end

      context 'with service stopped' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'         => true,
              'service_ensure' => 'stopped',
              'service_enable' => false,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_service('isc-kea-dhcp4-server').with(
            'ensure' => 'stopped',
            'enable' => false,
          )
        end
      end

      context 'with HA hot-standby configuration' do
        let(:facts) do
          os_facts.merge(
            'networking' => {
              'fqdn' => 'server1.example.com',
            },
          )
        end
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'ha'         => {
                'mode'        => 'hot-standby',
                'this_server' => 'server1.example.com',
                'peers'       => {
                  'server1.example.com' => {
                    'url'  => 'http://192.168.1.10:8000/',
                    'role' => 'primary',
                  },
                  'server2.example.com' => {
                    'url'  => 'http://192.168.1.11:8000/',
                    'role' => 'standby',
                  },
                },
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes the HA hook library' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{libdhcp_ha\.so}
          )
        end

        it 'includes the HA mode' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"mode":"hot-standby"}
          )
        end

        it 'includes this-server-name' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"this-server-name":"server1\.example\.com"}
          )
        end

        it 'includes peer configuration' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"url":"http://192\.168\.1\.10:8000/"}
          )
        end
      end

      context 'with HA load-balancing configuration' do
        let(:facts) do
          os_facts.merge(
            'networking' => {
              'fqdn' => 'server1.example.com',
            },
          )
        end
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'ha'         => {
                'mode'               => 'load-balancing',
                'this_server'        => 'server1.example.com',
                'heartbeat_delay'    => 5000,
                'max_response_delay' => 30000,
                'peers'              => {
                  'server1.example.com' => {
                    'url'  => 'http://192.168.1.10:8000/',
                    'role' => 'primary',
                  },
                  'server2.example.com' => {
                    'url'  => 'http://192.168.1.11:8000/',
                    'role' => 'secondary',
                  },
                },
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes the load-balancing mode' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"mode":"load-balancing"}
          )
        end

        it 'includes custom heartbeat delay' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"heartbeat-delay":5000}
          )
        end
      end

      context 'with HA auto-detection of this_server' do
        let(:facts) do
          os_facts.merge(
            'networking' => {
              'fqdn' => 'server2.example.com',
            },
          )
        end
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'ha'         => {
                'mode'  => 'hot-standby',
                'peers' => {
                  'server1.example.com' => {
                    'url'  => 'http://192.168.1.10:8000/',
                    'role' => 'primary',
                  },
                  'server2.example.com' => {
                    'url'  => 'http://192.168.1.11:8000/',
                    'role' => 'standby',
                  },
                },
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it 'auto-detects this-server-name from FQDN' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{"this-server-name":"server2\.example\.com"}
          )
        end
      end

      context 'with HA invalid this_server' do
        let(:facts) do
          os_facts.merge(
            'networking' => {
              'fqdn' => 'unknown.example.com',
            },
          )
        end
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'ha'         => {
                'mode'  => 'hot-standby',
                'peers' => {
                  'server1.example.com' => {
                    'url'  => 'http://192.168.1.10:8000/',
                    'role' => 'primary',
                  },
                  'server2.example.com' => {
                    'url'  => 'http://192.168.1.11:8000/',
                    'role' => 'standby',
                  },
                },
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.and_raise_error(%r{HA this_server.*must be one of the defined peers}) }
      end

      context 'with HA invalid role for mode' do
        let(:facts) do
          os_facts.merge(
            'networking' => {
              'fqdn' => 'server1.example.com',
            },
          )
        end
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'     => true,
              'interfaces' => ['eth0'],
              'ha'         => {
                'mode'        => 'hot-standby',
                'this_server' => 'server1.example.com',
                'peers'       => {
                  'server1.example.com' => {
                    'url'  => 'http://192.168.1.10:8000/',
                    'role' => 'primary',
                  },
                  'server2.example.com' => {
                    'url'  => 'http://192.168.1.11:8000/',
                    'role' => 'secondary',
                  },
                },
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.and_raise_error(%r{HA mode 'hot-standby' requires roles 'primary' or 'standby'}) }
      end

      context 'with HA and existing hooks_libraries' do
        let(:facts) do
          os_facts.merge(
            'networking' => {
              'fqdn' => 'server1.example.com',
            },
          )
        end
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            dhcp4 => {
              'enable'          => true,
              'interfaces'      => ['eth0'],
              'hooks_libraries' => [
                {
                  'library' => '/usr/lib/x86_64-linux-gnu/kea/hooks/libdhcp_lease_cmds.so',
                },
              ],
              'ha'              => {
                'mode'        => 'hot-standby',
                'this_server' => 'server1.example.com',
                'peers'       => {
                  'server1.example.com' => {
                    'url'  => 'http://192.168.1.10:8000/',
                    'role' => 'primary',
                  },
                  'server2.example.com' => {
                    'url'  => 'http://192.168.1.11:8000/',
                    'role' => 'standby',
                  },
                },
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes both the existing hook and HA hook' do
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{libdhcp_lease_cmds\.so}
          )
          is_expected.to contain_file('/etc/kea/kea-dhcp4.conf').with_content(
            %r{libdhcp_ha\.so}
          )
        end
      end
    end
  end
end
