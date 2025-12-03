# @summary
#   Main class for ISC Kea DHCP server management.
#   Installs and configures ISC Kea from Cloudsmith repositories.
#
# @param repo_version
#   The Kea repository version to use (e.g., '3-0', '2-6', 'dev').
#   Defaults to '3-0' (current LTS).
#
# @param manage_repo
#   Whether to manage the Cloudsmith apt repository.
#
# @param dhcp4
#   Hash of DHCPv4 server configuration options.
#   Set to undef or empty hash to disable DHCPv4.
#
# @param dhcp6
#   Hash of DHCPv6 server configuration options.
#   Set to undef or empty hash to disable DHCPv6.
#
# @param ddns
#   Hash of DHCP-DDNS server configuration options.
#   Set to undef or empty hash to disable DDNS.
#
# @param hooks_package
#   Whether to install the open source hooks package.
#
# @param mysql_backend
#   Whether to install MySQL backend support.
#
# @param postgresql_backend
#   Whether to install PostgreSQL backend support.
#
# @param config_dir
#   Base configuration directory for Kea.
#
# @param run_dir
#   Runtime directory for PID files and sockets.
#
# @param log_dir
#   Log directory for Kea services.
#
# @param lib_dir
#   Library directory for lease files and state.
#
# @example Basic usage with DHCPv4 only
#   class { 'kea':
#     dhcp4 => {
#       enable => true,
#     },
#   }
#
# @example Full configuration via Hiera
#   kea::dhcp4:
#     enable: true
#     interfaces: ['eth0']
#     subnets:
#       - id: 1
#         subnet: '192.168.1.0/24'
#         pools:
#           - pool: '192.168.1.100 - 192.168.1.200'
#
class kea (
  # Repository settings
  String[1]           $repo_version        = '3-0',
  Boolean             $manage_repo         = true,

  # Component toggles - use hashes for grouped config
  Optional[Hash]      $dhcp4               = undef,
  Optional[Hash]      $dhcp6               = undef,
  Optional[Hash]      $ddns                = undef,

  # Package options
  Boolean             $hooks_package       = true,
  Boolean             $mysql_backend       = false,
  Boolean             $postgresql_backend  = false,

  # Directory configuration
  Stdlib::Absolutepath $config_dir         = '/etc/kea',
  Stdlib::Absolutepath $run_dir            = '/run/kea',
  Stdlib::Absolutepath $log_dir            = '/var/log/kea',
  Stdlib::Absolutepath $lib_dir            = '/var/lib/kea',
) {
  # Validate OS family
  unless $facts['os']['family'] == 'Debian' {
    fail("kea module only supports Debian-based systems. Detected: ${facts['os']['family']}")
  }

  # Repository management
  if $manage_repo {
    contain kea::repo
  }

  # Install common package (required by all components)
  contain kea::install

  # Ensure directories exist
  file { [$config_dir, $run_dir, $log_dir, $lib_dir]:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Configure components based on provided hashes
  if $dhcp4 and $dhcp4['enable'] {
    contain kea::dhcp4
  }

  if $dhcp6 and $dhcp6['enable'] {
    contain kea::dhcp6
  }

  if $ddns and $ddns['enable'] {
    contain kea::ddns
  }

  # Establish ordering
  if $manage_repo {
    Class['kea::repo']
    -> Class['kea::install']
  }

  Class['kea::install']
  -> File[$config_dir]
  -> File[$run_dir]
  -> File[$log_dir]
  -> File[$lib_dir]
}
