# @summary
#   Defines a DHCPv4 subnet for Kea (for direct resource declaration).
#
#   Note: This defined type is DEPRECATED in favor of defining subnets in Hiera
#   under kea::dhcp4::subnets. The Hiera approach allows for automatic deep merging
#   across hierarchy levels and auto-generates subnet IDs.
#
#   If you still want to use this defined type, subnets will be created as
#   individual JSON files in subnets4.d/ and included via the include chain.
#
# @param subnet
#   The subnet in CIDR notation (e.g., '192.168.1.0/24').
#
# @param id
#   Optional unique numeric identifier for the subnet. If not provided,
#   a stable ID will be auto-generated from the resource name.
#
# @param pools
#   Array of pool definitions. Each pool is a hash with at minimum a 'pool' key.
#
# @param option_data
#   Array of DHCP options for this subnet.
#
# @param reservations
#   Array of host reservations for this subnet.
#
# @param relay
#   Relay agent configuration for this subnet.
#
# @param interface
#   Interface to use for this subnet (optional, for directly connected subnets).
#
# @param valid_lifetime
#   Lease valid lifetime for this subnet (overrides global).
#
# @param renew_timer
#   T1 renew timer for this subnet (overrides global).
#
# @param rebind_timer
#   T2 rebind timer for this subnet (overrides global).
#
# @param extra_config
#   Hash of additional Kea subnet configuration options.
#
# @example Basic subnet (prefer Hiera instead)
#   kea::dhcp4::subnet { 'office-lan':
#     subnet => '192.168.1.0/24',
#     pools  => [
#       { 'pool' => '192.168.1.100 - 192.168.1.200' },
#     ],
#     option_data => [
#       { 'name' => 'routers', 'data' => '192.168.1.1' },
#       { 'name' => 'domain-name-servers', 'data' => '192.168.1.1' },
#     ],
#   }
#
define kea::dhcp4::subnet (
  Stdlib::IP::Address::V4::CIDR $subnet,
  Optional[Integer]             $id               = undef,
  Array[Hash]                   $pools            = [],
  Array[Hash]                   $option_data      = [],
  Array[Hash]                   $reservations     = [],
  Optional[Hash]                $relay            = undef,
  Optional[String[1]]           $interface        = undef,
  Optional[Integer]             $valid_lifetime   = undef,
  Optional[Integer]             $renew_timer      = undef,
  Optional[Integer]             $rebind_timer     = undef,
  Hash                          $extra_config     = {},
) {
  # Validate that we have the main class included
  unless defined(Class['kea']) {
    fail('You must include the kea class before declaring kea::dhcp4::subnet resources')
  }

  # Generate a stable ID from the name if not provided
  $auto_id = fqdn_rand(2147483646, "kea-subnet-${name}") + 1
  $subnet_id = pick($id, $auto_id)

  # Sanitize name for filename
  $safe_name = regsubst($name, '[^a-zA-Z0-9_-]', '_', 'G')
  $subnets_dir = "${kea::config_dir}/subnets4.d"

  # Build the subnet configuration hash
  $base = {
    'id'     => $subnet_id,
    'subnet' => $subnet,
  }

  $pools_config = $pools.empty ? {
    true    => {},
    default => { 'pools' => $pools },
  }

  $options_config = $option_data.empty ? {
    true    => {},
    default => { 'option-data' => $option_data },
  }

  $reservations_config = $reservations.empty ? {
    true    => {},
    default => { 'reservations' => $reservations },
  }

  $relay_config = $relay ? {
    undef   => {},
    default => { 'relay' => $relay },
  }

  $interface_config = $interface ? {
    undef   => {},
    default => { 'interface' => $interface },
  }

  $lifetime_config = {
    'valid-lifetime' => $valid_lifetime,
    'renew-timer'    => $renew_timer,
    'rebind-timer'   => $rebind_timer,
  }.filter |$k, $v| { $v =~ NotUndef }

  # Merge all config pieces
  $subnet_config = $base + $pools_config + $options_config +
  $reservations_config + $relay_config +
  $interface_config + $lifetime_config + $extra_config

  # Create the individual subnet file
  file { "${subnets_dir}/${safe_name}.json":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => stdlib::to_json_pretty($subnet_config),
    require => File[$subnets_dir],
    notify  => Service['isc-kea-dhcp4-server'],
  }
}
