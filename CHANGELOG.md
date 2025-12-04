# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.5] - 2024-12-04

### Added
- Structured High Availability (HA) support for DHCPv4 and DHCPv6
  - Hot-standby mode: active/passive failover
  - Load-balancing mode: active/active with automatic failover
  - Passive-backup mode: simple backup without state sync (Kea 2.4+)
- New type aliases for HA configuration validation:
  - `Kea::Ha::Mode` - validates HA mode values
  - `Kea::Ha::Role` - validates peer role values
  - `Kea::Ha::Peer` - validates peer configuration structure
  - `Kea::Ha::Config` - validates complete HA configuration
- Automatic `this_server` detection from `$facts['networking']['fqdn']`
- HA hook library automatically merged with user-specified hooks
- Comprehensive validation for HA peer configurations
- Acceptance tests for HA configurations (hot-standby, load-balancing, custom hooks)

## [0.0.4] - 2024-12-03

### Fixed
- Corrected Puppet Forge API authentication in release workflow

## [0.0.3] - 2024-12-03

### Added
- Initial public release to Puppet Forge
- DHCPv4 server support with modular subnet configuration
- DHCPv6 server support with prefix delegation
- DHCP-DDNS integration for dynamic DNS updates
- Shared networks support for DHCPv4 and DHCPv6
- MySQL and PostgreSQL backend support
- Hook libraries configuration
- Client classes support
- Comprehensive Hiera-driven configuration
- Automatic subnet ID generation using `fqdn_rand()`
- Human-readable subnet filenames (e.g., `192.168.1.0-24.json`)
- Deep merge support for distributing subnets across Hiera hierarchy

### Notes
- Requires Puppet 8.0.0 or later
- Only supports Debian and Ubuntu (Debian family)
- Uses ISC Kea 3.x from Cloudsmith repositories
