# frozen_string_literal: true

require 'spec_helper'

describe 'kea' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea') }
        it { is_expected.to contain_class('kea::repo') }
        it { is_expected.to contain_class('kea::install') }

        it { is_expected.not_to contain_class('kea::dhcp4') }
        it { is_expected.not_to contain_class('kea::dhcp6') }
        it { is_expected.not_to contain_class('kea::ddns') }

        # Repository management (uses versioned resource name)
        it { is_expected.to contain_apt__source('isc-kea-3-0') }

        # Common package
        it { is_expected.to contain_package('isc-kea-common').with_ensure('installed') }
        it { is_expected.to contain_package('isc-kea-hooks').with_ensure('installed') }
        it { is_expected.not_to contain_package('isc-kea-mysql') }
        it { is_expected.not_to contain_package('isc-kea-pgsql') }
      end

      context 'with manage_repo disabled' do
        let(:params) { { manage_repo: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('kea::repo') }
        it { is_expected.not_to contain_apt__source('isc-kea-3-0') }
      end

      context 'with custom repo_version' do
        let(:params) { { repo_version: '2-6' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_apt__source('isc-kea-2-6') }
      end

      context 'with mysql_backend enabled' do
        let(:params) { { mysql_backend: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('isc-kea-mysql').with_ensure('installed') }
      end

      context 'with postgresql_backend enabled' do
        let(:params) { { postgresql_backend: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('isc-kea-pgsql').with_ensure('installed') }
      end

      context 'with hooks_package disabled' do
        let(:params) { { hooks_package: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('isc-kea-hooks') }
      end

      context 'with custom directories' do
        let(:params) do
          {
            config_dir: '/opt/kea/etc',
            run_dir: '/opt/kea/run',
            log_dir: '/opt/kea/log',
            lib_dir: '/opt/kea/lib',
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with dhcp4 enabled' do
        let(:params) do
          {
            dhcp4: {
              'enable' => true,
              'interfaces' => ['eth0'],
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::dhcp4') }
      end

      context 'with dhcp6 enabled' do
        let(:params) do
          {
            dhcp6: {
              'enable' => true,
              'interfaces' => ['eth0'],
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::dhcp6') }
      end

      context 'with ddns enabled' do
        let(:params) do
          {
            ddns: {
              'enable' => true,
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::ddns') }
      end
    end
  end
end
