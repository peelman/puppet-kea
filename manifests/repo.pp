# @summary
#   Manages the ISC Cloudsmith repository for Kea packages.
#
# @api private
#
class kea::repo {
  assert_private()

  $repo_version = $kea::repo_version

  # Determine OS-specific repository details
  $os_codename = $facts['os']['distro']['codename']
  $os_name_lower = downcase($facts['os']['name'])

  # Repository configuration
  $repo_url = "https://dl.cloudsmith.io/public/isc/kea-${repo_version}/deb/${os_name_lower}"

  # ISC Cloudsmith GPG key details
  # Key ID B16C44CD45514C3C is used by Kea 3.0+
  $gpg_key_url = "https://dl.cloudsmith.io/public/isc/kea-${repo_version}/gpg.B16C44CD45514C3C.key"
  $keyring_path = '/etc/apt/keyrings/isc-kea.gpg'

  # Ensure keyrings directory exists
  file { '/etc/apt/keyrings':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Download and dearmor the GPG key to the keyrings directory
  exec { "download-isc-kea-${repo_version}-key":
    command => "/usr/bin/curl -fsSL ${gpg_key_url} | /usr/bin/gpg --dearmor -o ${keyring_path}",
    creates => $keyring_path,
    require => File['/etc/apt/keyrings'],
  }

  # Set proper permissions on keyring
  file { $keyring_path:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Exec["download-isc-kea-${repo_version}-key"],
  }

  # Add the repository using DEB822 format
  apt::source { "isc-kea-${repo_version}":
    source_format => 'sources',
    comment       => "ISC Kea ${repo_version} Repository",
    enabled       => true,
    types         => ['deb'],
    location      => [$repo_url],
    release       => [$os_codename],
    repos         => ['main'],
    keyring       => $keyring_path,
    notify_update => true,
    require       => File[$keyring_path],
  }
}
