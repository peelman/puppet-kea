# frozen_string_literal: true

require 'spec_helper'

describe 'kea::ddns' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) do
        <<-PUPPET
        class { 'kea':
          ddns => {
            'enable' => true,
          },
        }
        PUPPET
      end

      context 'with minimal configuration' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::ddns') }

        it { is_expected.to contain_package('isc-kea-dhcp-ddns').with_ensure('installed') }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        end

        it do
          is_expected.to contain_service('isc-kea-dhcp-ddns-server').with(
            'ensure'     => 'running',
            'enable'     => true,
            'hasrestart' => true,
            'hasstatus'  => true,
          )
        end

        # Verify config file content
        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"DhcpDdns":}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"ip-address": "127.0.0.1"}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"port": 53001}
          )
        end
      end

      context 'with custom listen address and port' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable'     => true,
              'ip_address' => '0.0.0.0',
              'port'       => 53002,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"ip-address": "0.0.0.0"}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"port": 53002}
          )
        end
      end

      context 'with forward DDNS configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable' => true,
              'forward_ddns' => {
                'ddns_domains' => [
                  {
                    'name' => 'example.com.',
                    'dns_servers' => [
                      {
                        'ip_address' => '192.168.1.1',
                        'port'       => 53,
                      },
                    ],
                  },
                ],
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"forward-ddns":}
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"ddns-domains":.*"name":"example.com."}m
          )
        end
      end

      context 'with reverse DDNS configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable' => true,
              'reverse_ddns' => {
                'ddns_domains' => [
                  {
                    'name' => '1.168.192.in-addr.arpa.',
                    'dns_servers' => [
                      {
                        'ip_address' => '192.168.1.1',
                        'port'       => 53,
                      },
                    ],
                  },
                ],
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"reverse-ddns":}
          )
        end
      end

      context 'with TSIG keys' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable'    => true,
              'tsig_keys' => [
                {
                  'name'      => 'ddns-key',
                  'algorithm' => 'HMAC-SHA256',
                  'secret'    => 'base64encodedkey==',
                },
              ],
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"tsig-keys":.*"name":"ddns-key"}m
          )
        end

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"algorithm":"HMAC-SHA256"}
          )
        end
      end

      context 'with custom DNS server timeout' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable'             => true,
              'dns_server_timeout' => 1000,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"dns-server-timeout": 1000}
          )
        end
      end

      context 'with custom logging' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable'  => true,
              'logging' => {
                'severity'   => 'DEBUG',
                'debuglevel' => 99,
                'output'     => '/var/log/kea/kea-ddns-debug.log',
              },
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/kea/kea-dhcp-ddns.conf').with_content(
            %r{"severity": "DEBUG"}
          )
        end
      end

      context 'with service stopped' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            ddns => {
              'enable'         => true,
              'service_ensure' => 'stopped',
              'service_enable' => false,
            },
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_service('isc-kea-dhcp-ddns-server').with(
            'ensure' => 'stopped',
            'enable' => false,
          )
        end
      end
    end
  end
end
