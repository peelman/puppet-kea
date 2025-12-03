# @summary
#   Installs common Kea packages.
#
# @api private
#
class kea::install {
  assert_private()

  # Common package is always required
  # Only require apt::update if we're managing the repository
  if $kea::manage_repo {
    package { 'isc-kea-common':
      ensure  => installed,
      require => Class['apt::update'],
    }
  } else {
    package { 'isc-kea-common':
      ensure => installed,
    }
  }

  # Admin tools package
  package { 'isc-kea-admin':
    ensure  => installed,
    require => Package['isc-kea-common'],
  }

  # Optional hooks package
  if $kea::hooks_package {
    package { 'isc-kea-hooks':
      ensure  => installed,
      require => Package['isc-kea-common'],
    }
  }

  # Optional MySQL backend
  if $kea::mysql_backend {
    package { 'isc-kea-mysql':
      ensure  => installed,
      require => Package['isc-kea-common'],
    }
  }

  # Optional PostgreSQL backend
  if $kea::postgresql_backend {
    package { 'isc-kea-pgsql':
      ensure  => installed,
      require => Package['isc-kea-common'],
    }
  }
}
