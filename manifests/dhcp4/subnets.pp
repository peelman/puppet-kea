# @summary
#   Manages DHCPv4 subnets configuration for Kea.
#
#   This class:
#   - Looks up subnets from Hiera with deep merge
#   - Creates individual subnet JSON files in subnets4.d/
#   - Builds kea-dhcp4-subnets.json with include directives for each subnet file
#
#   The include chain is:
#   kea-dhcp4.conf -> kea-dhcp4-subnets.json -> subnets4.d/*.json
#
#   Subnet IDs are auto-generated from the subnet name if not explicitly provided.
#   This ensures stable, unique IDs without manual assignment.
#
# @api private
#
class kea::dhcp4::subnets {
  assert_private()

  $subnets_dir = "${kea::config_dir}/subnets4.d"
  $subnets_file = "${kea::config_dir}/kea-dhcp4-subnets.json"

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

  # Lookup subnets from Hiera with hash merge strategy
  # This allows subnets to be defined at any level of the hierarchy
  # and merged together
  $hiera_subnets = lookup('kea::dhcp4::subnets', Hash, 'deep', {})

  # Get sorted subnet names for consistent ordering
  $subnet_names = $hiera_subnets.keys.sort

  # Create individual subnet files and collect include directives
  $subnet_names.each |String $name| {
    $config = $hiera_subnets[$name]

    # Generate a stable ID from the name if not provided
    # Using fqdn_rand with the subnet name as seed for consistency
    # Range: 1-2147483647 (Kea uses signed 32-bit integers for subnet ID)
    $auto_id = fqdn_rand(2147483646, "kea-subnet-${name}") + 1
    $subnet_id = pick($config['id'], $auto_id)

    # Sanitize name for filename
    $safe_name = regsubst($name, '[^a-zA-Z0-9_-]', '_', 'G')
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

    $valid_lifetime = ('valid_lifetime' in $config) ? {
      true    => { 'valid-lifetime' => $config['valid_lifetime'] },
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

    # Handle extra_config - any additional Kea options
    $extra = ('extra_config' in $config) ? {
      true    => $config['extra_config'],
      default => {},
    }

    # Merge all config pieces
    # lint:ignore:140chars
    $subnet_config = $base + $pools + $option_data + $reservations + $relay + $interface + $valid_lifetime + $renew_timer + $rebind_timer + $extra
    # lint:endignore

    # Create the individual subnet file
    file { "${subnets_dir}/${filename}":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => stdlib::to_json_pretty($subnet_config),
      require => File[$subnets_dir],
      notify  => Service['isc-kea-dhcp4-server'],
    }
  }

  # Build the subnets JSON file with include directives
  if $subnet_names.empty {
    $subnets_content = "[]\n"
  } else {
    $include_lines = $subnet_names.map |String $name| {
      $safe_name = regsubst($name, '[^a-zA-Z0-9_-]', '_', 'G')
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
    notify  => Service['isc-kea-dhcp4-server'],
  }
}
