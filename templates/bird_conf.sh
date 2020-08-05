#!/bin/bash

# Terraform Supplied Variables
floatingIp='${floating_ip}'
floatingCIDR='${floating_cidr}'
floatingNetmask='${floating_netmask}'

# BGP Prerequisites
apt update -y
apt install bird -y
mv /etc/bird/bird.conf /etc/bird/bird.conf.old
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
sysctl -p

# Add IP to loopback
cat <<-EOF >> /etc/network/interfaces

auto lo:0
iface lo:0 inet static
   address $floatingIp
   netmask $floatingNetmask
EOF
ifup lo:0

# Gather BGP variables
localAsn=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].customer_as`
bgpPassEnabled=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].md5_enabled`
bgpPass=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].md5_password`
multihop=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].multihop`
peer1=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].peer_ips[0]`
peer2=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].peer_ips[1]`
peerAs=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].peer_as`
customerIp=`curl -s https://metadata.packet.net/metadata | jq -r .bgp_neighbors[0].customer_ip`

# Configure Bird
cat <<-EOF > /etc/bird/bird.conf
filter packet_bgp {
    if net = $floatingIp/$floatingCIDR then accept;
}
router id $customerIp;
protocol direct {
    interface "lo";
}
protocol kernel {
    scan time 10;
    persist;
    import all;
    export all;
}
protocol device {
    scan time 10;
}
protocol bgp packet1 {
    export filter packet_bgp;
    local as $localAsn;
    neighbor $peer1 as $peerAs;
    #__PASSWORD__
    #__MULTI_HOP__
}
EOF

if [ "$peer2" != "null" ]; then
cat <<-EOF >> /etc/bird/bird.conf
protocol bgp packet2 {
    export filter packet_bgp;
    local as $localAsn;
    neighbor $peer2 as $peerAs;
    #__PASSWORD__
    #__MULTI_HOP__
}
EOF
fi

if [ "$multihop" == "true" ]; then
    sed -i "s/#__MULTI_HOP__/multihop 4;/g" /etc/bird/bird.conf
fi

if [ "$bgpPassEnabled" == "true" ]; then
    sed -i "s/#__PASSWORD__/password \"$bgpPass\";/g" /etc/bird/bird.conf
fi

systemctl restart bird.service