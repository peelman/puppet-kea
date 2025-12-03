# @summary
#   Manages the Kea DHCPv6 server.
#
# @api private
#
class kea::dhcp6 {
  assert_private()

  # Extract configuration from the dhcp6 hash
  $config = $kea::dhcp6

  # Merge defaults with provided config
  $service_ensure = pick($config['service_ensure'], 'running')
  $service_enable = pick($config['service_enable'], true)
  $config_file    = pick($config['config_file'], "${kea::config_dir}/kea-dhcp6.conf")

  # Include subnets management (creates subnets6.d directory and resources)
  contain kea::dhcp6::subnets

  # Install DHCPv6 package
  package { 'isc-kea-dhcp6':
    ensure  => installed,
    require => Class['kea::install'],
  }

  # Configuration file
  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('kea/kea-dhcp6.conf.epp', {
        'config'     => $config,
        'config_dir' => $kea::config_dir,
        'run_dir'    => $kea::run_dir,
        'log_dir'    => $kea::log_dir,
        'lib_dir'    => $kea::lib_dir,
    }),
    require => Package['isc-kea-dhcp6'],
    notify  => Service['isc-kea-dhcp6-server'],
  }

  # Service management
  # Note: On Debian/Ubuntu, the real service name is isc-kea-dhcp6-server
  service { 'isc-kea-dhcp6-server':
    ensure     => $service_ensure,
    enable     => $service_enable,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package['isc-kea-dhcp6'],
      File[$config_file],
      Class['kea::dhcp6::subnets'],
    ],
  }
}
