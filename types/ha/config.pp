# @summary High Availability configuration for Kea DHCP
#
# Configures the HA hook library for DHCPv4 or DHCPv6
#
# @example Hot-standby configuration
#   {
#     mode        => 'hot-standby',
#     this_server => 'server1',
#     peers       => {
#       'server1' => { url => 'http://192.168.1.10:8000/', role => 'primary' },
#       'server2' => { url => 'http://192.168.1.11:8000/', role => 'standby' },
#     },
#   }
#
# @example Load-balancing with custom timers
#   {
#     mode               => 'load-balancing',
#     this_server        => 'server1',
#     heartbeat_delay    => 10000,
#     max_response_delay => 60000,
#     peers              => {
#       'server1' => { url => 'http://192.168.1.10:8000/', role => 'primary' },
#       'server2' => { url => 'http://192.168.1.11:8000/', role => 'secondary' },
#     },
#   }
#
type Kea::Ha::Config = Struct[{
    mode                              => Kea::Ha::Mode,
    Optional[this_server]             => String[1],
    peers                             => Hash[String[1], Kea::Ha::Peer],
    Optional[heartbeat_delay]         => Integer[1000],
    Optional[max_response_delay]      => Integer[1000],
    Optional[max_ack_delay]           => Integer[1000],
    Optional[max_unacked_clients]     => Integer[0],
    Optional[max_rejected_lease_updates] => Integer[0],
    Optional[sync_timeout]            => Integer[1000],
    Optional[sync_page_limit]         => Integer[1],
    Optional[delayed_updates_limit]   => Integer[0],
    Optional[send_lease_updates]      => Boolean,
    Optional[sync_leases]             => Boolean,
    Optional[wait_backup_ack]         => Boolean,
    Optional[multi_threading]         => Struct[{
        Optional[enable_multi_threading]    => Boolean,
        Optional[http_dedicated_listener]   => Boolean,
        Optional[http_listener_threads]     => Integer[1],
        Optional[http_client_threads]       => Integer[1],
    }],
    Optional[state_machine]           => Struct[{
        Optional[states]                    => Array[Hash],
    }],
}]
