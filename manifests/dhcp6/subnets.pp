# @summary
#   Manages DHCPv6 subnets configuration for Kea.
#
#   This class:
#   - Looks up subnets from Hiera with deep merge
#   - Creates individual subnet JSON files in subnets6.d/
#   - Builds kea-dhcp6-subnets.json with include directives for each subnet file
#   - Supports shared networks for grouping subnets on the same physical link
#
#   The include chain is:
#   kea-dhcp6.conf -> kea-dhcp6-subnets.json -> subnets6.d/*.json
#
#   Subnet IDs are auto-generated from the subnet name if not explicitly provided.
#   This ensures stable, unique IDs without manual assignment.
#
#   You can provide an optional 'name' key in each subnet hash for cleaner filenames:
#     kea::dhcp6::subnets:
#       '2001:db8:1::/64':
#         name: 'office-lan-v6'    # Results in office-lan-v6.json instead of 2001-db8-1---64.json
#         pools: [...]
#
#   Without a name key, filenames are derived from the CIDR:
#     2001:db8:1::/64 -> 2001-db8-1---64.json (colons become dashes, repeated dashes collapsed)
#
#   Shared networks allow grouping subnets on the same physical link:
#     kea::dhcp6::shared_networks:
#       campus-network:
#         interface: eth0
#         subnets:
#           - subnet: '2001:db8:1::/64'
#             pools: [...]
#           - subnet: '2001:db8:2::/64'
#             pools: [...]
#
# @api private
#
class kea::dhcp6::subnets {
  assert_private()

  $subnets_dir = "${kea::config_dir}/subnets6.d"
  $subnets_file = "${kea::config_dir}/kea-dhcp6-subnets.json"
  $shared_networks_dir = "${kea::config_dir}/shared-networks6.d"
  $shared_networks_file = "${kea::config_dir}/kea-dhcp6-shared-networks.json"

  # Create the subnets directory
  file { $subnets_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    purge   => true,
    force   => true,
    recurse => true,
    require => File[$kea::config_dir],
  }

  # Get subnets from the class parameter (passed as array)
  # Convert array to hash keyed by subnet CIDR for consistency
  $param_subnets_array = pick($kea::dhcp6['subnets'], [])
  $param_subnets = $param_subnets_array.reduce({}) |$memo, $subnet| {
    $key = $subnet['subnet']
    $memo + { $key => $subnet }
  }

  # Lookup subnets from Hiera with hash merge strategy
  # This allows subnets to be defined at any level of the hierarchy
  # and merged together
  $hiera_subnets = lookup('kea::dhcp6::subnets', Hash, 'deep', {})

  # Merge both sources - param subnets take precedence
  $all_subnets = $hiera_subnets + $param_subnets

  # Lookup shared networks from Hiera
  $shared_networks = lookup('kea::dhcp6::shared_networks', Hash, 'deep', {})

  # Get sorted subnet names for consistent ordering
  $subnet_names = $all_subnets.keys.sort

  # Create individual subnet files and collect include directives
  $subnet_names.each |String $name| {
    $config = $all_subnets[$name]

    # Generate a stable ID from the name if not provided
    # Using fqdn_rand with the subnet name as seed for consistency
    # Range: 1-2147483647 (Kea uses signed 32-bit integers for subnet ID)
    $auto_id = fqdn_rand(2147483646, "kea-subnet6-${name}") + 1
    $subnet_id = pick($config['id'], $auto_id)

    # Determine filename: prefer user-provided 'name' key, otherwise derive from subnet
    # User-provided name:  'office-lan-v6' -> 'office-lan-v6.json'
    # Derived from subnet: '2001:db8:1::/64' -> '2001-db8-1---64.json' (colons to dashes)
    $user_name = $config['name']
    if $user_name {
      # Sanitize user-provided name, collapse repeated underscores/dashes
      $safe_name_raw = regsubst($user_name, '[^a-zA-Z0-9._-]', '_', 'G')
      $safe_name = regsubst($safe_name_raw, '_+', '_', 'G')
    } else {
      # For IPv6: replace colons with dashes, slash with dash, collapse repeated dashes
      $step1 = regsubst($name, ':', '-', 'G')
      $step2 = regsubst($step1, '/', '-', 'G')
      $safe_name = regsubst($step2, '-+', '-', 'G')
    }
    $filename = "${safe_name}.json"

    # Build the subnet configuration hash
    $base = {
      'id'     => $subnet_id,
      'subnet' => $config['subnet'],
    }

    # Add optional fields only if they exist and are non-empty
    $pools = ('pools' in $config and !$config['pools'].empty) ? {
      true    => { 'pools' => $config['pools'] },
      default => {},
    }

    # DHCPv6 also supports pd-pools for prefix delegation
    $pd_pools = ('pd_pools' in $config and !$config['pd_pools'].empty) ? {
      true    => { 'pd-pools' => $config['pd_pools'] },
      default => {},
    }

    $option_data = ('option_data' in $config and !$config['option_data'].empty) ? {
      true    => { 'option-data' => $config['option_data'] },
      default => {},
    }

    $reservations = ('reservations' in $config and !$config['reservations'].empty) ? {
      true    => { 'reservations' => $config['reservations'] },
      default => {},
    }

    $relay = ('relay' in $config) ? {
      true    => { 'relay' => $config['relay'] },
      default => {},
    }

    $interface = ('interface' in $config) ? {
      true    => { 'interface' => $config['interface'] },
      default => {},
    }

    $interface_id = ('interface_id' in $config) ? {
      true    => { 'interface-id' => $config['interface_id'] },
      default => {},
    }

    $valid_lifetime = ('valid_lifetime' in $config) ? {
      true    => { 'valid-lifetime' => $config['valid_lifetime'] },
      default => {},
    }

    $preferred_lifetime = ('preferred_lifetime' in $config) ? {
      true    => { 'preferred-lifetime' => $config['preferred_lifetime'] },
      default => {},
    }

    $renew_timer = ('renew_timer' in $config) ? {
      true    => { 'renew-timer' => $config['renew_timer'] },
      default => {},
    }

    $rebind_timer = ('rebind_timer' in $config) ? {
      true    => { 'rebind-timer' => $config['rebind_timer'] },
      default => {},
    }

    $rapid_commit = ('rapid_commit' in $config) ? {
      true    => { 'rapid-commit' => $config['rapid_commit'] },
      default => {},
    }

    # Handle extra_config - any additional Kea options
    $extra = ('extra_config' in $config) ? {
      true    => $config['extra_config'],
      default => {},
    }

    # Merge all config pieces
    $subnet_config = $base + $pools + $pd_pools + $option_data + $reservations +
    $relay + $interface + $interface_id + $valid_lifetime + $preferred_lifetime +
    $renew_timer + $rebind_timer + $rapid_commit + $extra

    # Create the individual subnet file
    file { "${subnets_dir}/${filename}":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => stdlib::to_json_pretty($subnet_config),
      require => File[$subnets_dir],
      notify  => Service['isc-kea-dhcp6-server'],
    }
  }

  # Build the subnets JSON file with include directives
  # Derive safe filename using same logic as when creating files
  if $subnet_names.empty {
    $subnets_content = "[]\n"
  } else {
    $include_lines = $subnet_names.map |String $name| {
      $config = $all_subnets[$name]
      $user_name = $config['name']
      if $user_name {
        $safe_name_raw = regsubst($user_name, '[^a-zA-Z0-9._-]', '_', 'G')
        $safe_name = regsubst($safe_name_raw, '_+', '_', 'G')
      } else {
        $step1 = regsubst($name, ':', '-', 'G')
        $step2 = regsubst($step1, '/', '-', 'G')
        $safe_name = regsubst($step2, '-+', '-', 'G')
      }
      "  <?include \"${subnets_dir}/${safe_name}.json\"?>"
    }
    $joined_includes = $include_lines.join(",\n")
    $subnets_content = "[\n${joined_includes}\n]\n"
  }

  file { $subnets_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $subnets_content,
    require => File[$subnets_dir],
    notify  => Service['isc-kea-dhcp6-server'],
  }

  # ============================================================================
  # Shared Networks Support
  # ============================================================================
  # Kea shared networks allow grouping subnets on the same physical link.
  # This is similar to the old ISC DHCP 'shared-network' concept.
  #
  # Configuration structure:
  #   kea::dhcp6::shared_networks:
  #     office-campus:
  #       interface: eth0
  #       option_data: [...]
  #       subnets:
  #         - subnet: '2001:db8:1::/64'
  #           pools: [...]
  #         - subnet: '2001:db8:2::/64'
  #           pools: [...]
  # ============================================================================

  # Create the shared networks directory
  file { $shared_networks_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    purge   => true,
    force   => true,
    recurse => true,
    require => File[$kea::config_dir],
  }

  $shared_network_names = $shared_networks.keys.sort

  # Process each shared network - create individual files
  $shared_network_names.each |String $sn_name| {
    $sn_config = $shared_networks[$sn_name]

    # Build subnet configurations within this shared network
    $sn_subnets = pick($sn_config['subnets'], []).map |$idx, Hash $subnet| {
      # Auto-generate ID if not provided
      $auto_id = fqdn_rand(2147483646, "kea-sn6-${sn_name}-subnet-${idx}") + 1
      $subnet_id = pick($subnet['id'], $auto_id)

      $base = {
        'id'     => $subnet_id,
        'subnet' => $subnet['subnet'],
      }

      $pools = ('pools' in $subnet and !$subnet['pools'].empty) ? {
        true    => { 'pools' => $subnet['pools'] },
        default => {},
      }

      $pd_pools = ('pd_pools' in $subnet and !$subnet['pd_pools'].empty) ? {
        true    => { 'pd-pools' => $subnet['pd_pools'] },
        default => {},
      }

      $option_data = ('option_data' in $subnet and !$subnet['option_data'].empty) ? {
        true    => { 'option-data' => $subnet['option_data'] },
        default => {},
      }

      $reservations = ('reservations' in $subnet and !$subnet['reservations'].empty) ? {
        true    => { 'reservations' => $subnet['reservations'] },
        default => {},
      }

      $relay = ('relay' in $subnet) ? {
        true    => { 'relay' => $subnet['relay'] },
        default => {},
      }

      $interface = ('interface' in $subnet) ? {
        true    => { 'interface' => $subnet['interface'] },
        default => {},
      }

      $interface_id = ('interface_id' in $subnet) ? {
        true    => { 'interface-id' => $subnet['interface_id'] },
        default => {},
      }

      $valid_lifetime = ('valid_lifetime' in $subnet) ? {
        true    => { 'valid-lifetime' => $subnet['valid_lifetime'] },
        default => {},
      }

      $preferred_lifetime = ('preferred_lifetime' in $subnet) ? {
        true    => { 'preferred-lifetime' => $subnet['preferred_lifetime'] },
        default => {},
      }

      $renew_timer = ('renew_timer' in $subnet) ? {
        true    => { 'renew-timer' => $subnet['renew_timer'] },
        default => {},
      }

      $rebind_timer = ('rebind_timer' in $subnet) ? {
        true    => { 'rebind-timer' => $subnet['rebind_timer'] },
        default => {},
      }

      $rapid_commit = ('rapid_commit' in $subnet) ? {
        true    => { 'rapid-commit' => $subnet['rapid_commit'] },
        default => {},
      }

      $extra = ('extra_config' in $subnet) ? {
        true    => $subnet['extra_config'],
        default => {},
      }

      # Merge all config pieces
      $base + $pools + $pd_pools + $option_data + $reservations +
      $relay + $interface + $interface_id + $valid_lifetime + $preferred_lifetime +
      $renew_timer + $rebind_timer + $rapid_commit + $extra
    }

    # Build shared network config
    $sn_base = { 'name' => $sn_name }

    $sn_interface = ('interface' in $sn_config) ? {
      true    => { 'interface' => $sn_config['interface'] },
      default => {},
    }

    $sn_interface_id = ('interface_id' in $sn_config) ? {
      true    => { 'interface-id' => $sn_config['interface_id'] },
      default => {},
    }

    $sn_option_data = ('option_data' in $sn_config and !$sn_config['option_data'].empty) ? {
      true    => { 'option-data' => $sn_config['option_data'] },
      default => {},
    }

    $sn_relay = ('relay' in $sn_config) ? {
      true    => { 'relay' => $sn_config['relay'] },
      default => {},
    }

    $sn_valid_lifetime = ('valid_lifetime' in $sn_config) ? {
      true    => { 'valid-lifetime' => $sn_config['valid_lifetime'] },
      default => {},
    }

    $sn_preferred_lifetime = ('preferred_lifetime' in $sn_config) ? {
      true    => { 'preferred-lifetime' => $sn_config['preferred_lifetime'] },
      default => {},
    }

    $sn_renew_timer = ('renew_timer' in $sn_config) ? {
      true    => { 'renew-timer' => $sn_config['renew_timer'] },
      default => {},
    }

    $sn_rebind_timer = ('rebind_timer' in $sn_config) ? {
      true    => { 'rebind-timer' => $sn_config['rebind_timer'] },
      default => {},
    }

    $sn_rapid_commit = ('rapid_commit' in $sn_config) ? {
      true    => { 'rapid-commit' => $sn_config['rapid_commit'] },
      default => {},
    }

    $sn_extra = ('extra_config' in $sn_config) ? {
      true    => $sn_config['extra_config'],
      default => {},
    }

    # Merge all shared network config pieces
    # lint:ignore:140chars
    $sn_full_config = $sn_base + $sn_interface + $sn_interface_id + $sn_option_data + $sn_relay + $sn_valid_lifetime + $sn_preferred_lifetime + $sn_renew_timer + $sn_rebind_timer + $sn_rapid_commit + $sn_extra + { 'subnet6' => $sn_subnets }
    # lint:endignore

    # Create individual shared network file
    file { "${shared_networks_dir}/${sn_name}.json":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => stdlib::to_json_pretty($sn_full_config),
      require => File[$shared_networks_dir],
      notify  => Service['isc-kea-dhcp6-server'],
    }
  }

  # Build the shared networks JSON file with include directives
  if $shared_network_names.empty {
    $shared_networks_content = "[]\n"
  } else {
    $sn_include_lines = $shared_network_names.map |String $sn_name| {
      "  <?include \"${shared_networks_dir}/${sn_name}.json\"?>"
    }
    $sn_joined_includes = $sn_include_lines.join(",\n")
    $shared_networks_content = "[\n${sn_joined_includes}\n]\n"
  }

  file { $shared_networks_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $shared_networks_content,
    require => File[$shared_networks_dir],
    notify  => Service['isc-kea-dhcp6-server'],
  }
}
