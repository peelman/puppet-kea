# @summary
#   Defines a DHCPv6 subnet for Kea (for direct resource declaration).
#
#   Note: This defined type is DEPRECATED in favor of defining subnets in Hiera
#   under kea::dhcp6::subnets. The Hiera approach allows for automatic deep merging
#   across hierarchy levels and auto-generates subnet IDs.
#
#   If you still want to use this defined type, subnets will be created as
#   individual JSON files in subnets6.d/ and included via the include chain.
#
# @param subnet
#   The subnet in CIDR notation (e.g., '2001:db8:1::/64').
#
# @param id
#   Optional unique numeric identifier for the subnet. If not provided,
#   a stable ID will be auto-generated from the resource name.
#
# @param pools
#   Array of pool definitions. Each pool is a hash with at minimum a 'pool' key.
#
# @param pd_pools
#   Array of prefix delegation pool definitions for DHCPv6.
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
# @param interface_id
#   Interface ID for relay agent (used for subnet selection).
#
# @param valid_lifetime
#   Lease valid lifetime for this subnet (overrides global).
#
# @param preferred_lifetime
#   Preferred lifetime for this subnet (overrides global).
#
# @param renew_timer
#   T1 renew timer for this subnet (overrides global).
#
# @param rebind_timer
#   T2 rebind timer for this subnet (overrides global).
#
# @param rapid_commit
#   Enable rapid commit for this subnet.
#
# @param extra_config
#   Hash of additional Kea subnet configuration options.
#
# @example Basic subnet (prefer Hiera instead)
#   kea::dhcp6::subnet { 'office-lan-v6':
#     subnet => '2001:db8:1::/64',
#     pools  => [
#       { 'pool' => '2001:db8:1::100 - 2001:db8:1::200' },
#     ],
#     option_data => [
#       { 'name' => 'dns-servers', 'data' => '2001:db8:1::1' },
#     ],
#   }
#
define kea::dhcp6::subnet (
  Stdlib::IP::Address::V6::CIDR $subnet,
  Optional[Integer]             $id                 = undef,
  Array[Hash]                   $pools              = [],
  Array[Hash]                   $pd_pools           = [],
  Array[Hash]                   $option_data        = [],
  Array[Hash]                   $reservations       = [],
  Optional[Hash]                $relay              = undef,
  Optional[String[1]]           $interface          = undef,
  Optional[String[1]]           $interface_id       = undef,
  Optional[Integer]             $valid_lifetime     = undef,
  Optional[Integer]             $preferred_lifetime = undef,
  Optional[Integer]             $renew_timer        = undef,
  Optional[Integer]             $rebind_timer       = undef,
  Optional[Boolean]             $rapid_commit       = undef,
  Hash                          $extra_config       = {},
) {
  # Validate that we have the main class included
  unless defined(Class['kea']) {
    fail('You must include the kea class before declaring kea::dhcp6::subnet resources')
  }

  # Generate a stable ID from the name if not provided
  $auto_id = fqdn_rand(2147483646, "kea-subnet6-${name}") + 1
  $subnet_id = pick($id, $auto_id)

  # Sanitize name for filename
  $safe_name = regsubst($name, '[^a-zA-Z0-9_-]', '_', 'G')
  $subnets_dir = "${kea::config_dir}/subnets6.d"

  # Build the subnet configuration hash
  $base = {
    'id'     => $subnet_id,
    'subnet' => $subnet,
  }

  $pools_config = $pools.empty ? {
    true    => {},
    default => { 'pools' => $pools },
  }

  $pd_pools_config = $pd_pools.empty ? {
    true    => {},
    default => { 'pd-pools' => $pd_pools },
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

  $interface_id_config = $interface_id ? {
    undef   => {},
    default => { 'interface-id' => $interface_id },
  }

  $rapid_commit_config = $rapid_commit ? {
    undef   => {},
    default => { 'rapid-commit' => $rapid_commit },
  }

  $lifetime_config = {
    'valid-lifetime'     => $valid_lifetime,
    'preferred-lifetime' => $preferred_lifetime,
    'renew-timer'        => $renew_timer,
    'rebind-timer'       => $rebind_timer,
  }.filter |$k, $v| { $v =~ NotUndef }

  # Merge all config pieces
  $subnet_config = $base + $pools_config + $pd_pools_config + $options_config +
  $reservations_config + $relay_config + $interface_config +
  $interface_id_config + $rapid_commit_config + $lifetime_config + $extra_config

  # Create the individual subnet file
  file { "${subnets_dir}/${safe_name}.json":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => stdlib::to_json_pretty($subnet_config),
    require => File[$subnets_dir],
    notify  => Service['isc-kea-dhcp6-server'],
  }
}
