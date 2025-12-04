# @summary Valid HA roles for Kea DHCP
#
# @see https://kea.readthedocs.io/en/latest/arm/hooks.html#ha-modes
#
# Role availability depends on mode:
# - hot-standby: primary, standby
# - load-balancing: primary, secondary
# - passive-backup: primary, backup
#
type Kea::Ha::Role = Enum['primary', 'secondary', 'standby', 'backup']
