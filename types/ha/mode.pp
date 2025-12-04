# @summary Valid HA modes for Kea DHCP
#
# @see https://kea.readthedocs.io/en/latest/arm/hooks.html#ha-modes
#
type Kea::Ha::Mode = Enum['hot-standby', 'load-balancing', 'passive-backup']
