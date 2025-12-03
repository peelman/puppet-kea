# @summary
#   Manages the Kea DHCP-DDNS server.
#
# @api private
#
class kea::ddns {
  assert_private()

  # Extract configuration from the ddns hash
  $config = $kea::ddns

  # Merge defaults with provided config
  $service_ensure = pick($config['service_ensure'], 'running')
  $service_enable = pick($config['service_enable'], true)
  $config_file    = pick($config['config_file'], "${kea::config_dir}/kea-dhcp-ddns.conf")

  # Install DHCP-DDNS package
  package { 'isc-kea-dhcp-ddns':
    ensure  => installed,
    require => Class['kea::install'],
  }

  # Configuration file
  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('kea/kea-dhcp-ddns.conf.epp', {
        'config'     => $config,
        'config_dir' => $kea::config_dir,
        'run_dir'    => $kea::run_dir,
        'log_dir'    => $kea::log_dir,
        'lib_dir'    => $kea::lib_dir,
    }),
    require => Package['isc-kea-dhcp-ddns'],
    notify  => Service['isc-kea-dhcp-ddns-server'],
  }

  # Service management
  # Note: On Debian/Ubuntu, the real service name is isc-kea-dhcp-ddns-server
  service { 'isc-kea-dhcp-ddns-server':
    ensure     => $service_ensure,
    enable     => $service_enable,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package['isc-kea-dhcp-ddns'],
      File[$config_file],
    ],
  }
}
