# frozen_string_literal: true

require 'spec_helper'

describe 'kea::repo' do
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
        it { is_expected.to contain_class('kea::repo') }

        # Keyrings directory
        it { is_expected.to contain_file('/etc/apt/keyrings').with_ensure('directory') }

        # GPG key download
        it { is_expected.to contain_exec('download-isc-kea-3-0-key') }
        it { is_expected.to contain_file('/etc/apt/keyrings/isc-kea.gpg').with_ensure('file') }

        # DEB822 format apt source
        case os
        when /debian/
          it do
            is_expected.to contain_apt__source('isc-kea-3-0').with(
              'source_format' => 'sources',
              'location'      => ['https://dl.cloudsmith.io/public/isc/kea-3-0/deb/debian'],
              'repos'         => ['main'],
              'types'         => ['deb'],
            )
          end
        when /ubuntu/
          it do
            is_expected.to contain_apt__source('isc-kea-3-0').with(
              'source_format' => 'sources',
              'location'      => ['https://dl.cloudsmith.io/public/isc/kea-3-0/deb/ubuntu'],
              'repos'         => ['main'],
              'types'         => ['deb'],
            )
          end
        end

        it do
          is_expected.to contain_apt__source('isc-kea-3-0').with(
            'keyring' => '/etc/apt/keyrings/isc-kea.gpg',
          )
        end
      end

      context 'with custom repo version' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'kea':
            repo_version => '3-1',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_apt__source('isc-kea-3-1').with(
            'location' => %r{kea-3-1},
          )
        end

        it { is_expected.to contain_exec('download-isc-kea-3-1-key') }
      end
    end
  end
end
