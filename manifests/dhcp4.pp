# @summary
#   Manages the Kea DHCPv4 server.
#
# @api private
#
class kea::dhcp4 {
  assert_private()

  # Extract configuration from the dhcp4 hash
  $config = $kea::dhcp4

  # Merge defaults with provided config
  $service_ensure = pick($config['service_ensure'], 'running')
  $service_enable = pick($config['service_enable'], true)
  $config_file    = pick($config['config_file'], "${kea::config_dir}/kea-dhcp4.conf")

  # Include subnets management (creates subnets.d directory and resources)
  contain kea::dhcp4::subnets

  # Install DHCPv4 package
  package { 'isc-kea-dhcp4':
    ensure  => installed,
    require => Class['kea::install'],
  }

  # Configuration file
  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('kea/kea-dhcp4.conf.epp', {
        'config'     => $config,
        'config_dir' => $kea::config_dir,
        'run_dir'    => $kea::run_dir,
        'log_dir'    => $kea::log_dir,
        'lib_dir'    => $kea::lib_dir,
    }),
    require => Package['isc-kea-dhcp4'],
    notify  => Service['isc-kea-dhcp4-server'],
  }

  # Service management
  # Note: On Debian/Ubuntu, the real service name is isc-kea-dhcp4-server
  service { 'isc-kea-dhcp4-server':
    ensure     => $service_ensure,
    enable     => $service_enable,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package['isc-kea-dhcp4'],
      File[$config_file],
      Class['kea::dhcp4::subnets'],
    ],
  }
}
