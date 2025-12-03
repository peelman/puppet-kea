# frozen_string_literal: true

require 'spec_helper'

describe 'kea::install' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) do
        <<-PUPPET
        class { 'kea': }
        PUPPET
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('kea::install') }

        it do
          is_expected.to contain_package('isc-kea-common').with(
            'ensure' => 'installed',
          )
        end

        it do
          is_expected.to contain_package('isc-kea-hooks').with(
            'ensure' => 'installed',
          )
        end

        # Default: no MySQL or PostgreSQL
        it { is_expected.not_to contain_package('isc-kea-mysql') }
        it { is_expected.not_to contain_package('isc-kea-pgsql') }
      end

      context 'with MySQL backend' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            mysql_backend => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_package('isc-kea-mysql').with(
            'ensure' => 'installed',
          )
        end
      end

      context 'with PostgreSQL backend' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            postgresql_backend => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_package('isc-kea-pgsql').with(
            'ensure' => 'installed',
          )
        end
      end

      context 'with both backends' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            mysql_backend      => true,
            postgresql_backend => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('isc-kea-mysql') }
        it { is_expected.to contain_package('isc-kea-pgsql') }
      end

      context 'without hooks package' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            hooks_package => false,
          }
          PUPPET
        end
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('isc-kea-hooks') }
      end
    end
  end
end
