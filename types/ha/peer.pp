# @summary HA peer configuration
#
# Defines a peer in the HA cluster
#
# @example
#   {
#     url  => 'http://192.168.1.10:8000/',
#     role => 'primary',
#   }
#
type Kea::Ha::Peer = Struct[{
    url                     => Stdlib::HTTPUrl,
    role                    => Kea::Ha::Role,
    Optional[auto_failover] => Boolean,
}]
