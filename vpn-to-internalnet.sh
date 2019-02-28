#!/bin/bash

# Local interface
IF_INTERNAL="ens192"

# Internal VPN interface
IF_INT="ppp+"

# VPN Net
NET_INT="172.28.253.64/26"

# NAT
iptables -t nat -A POSTROUTING -s ${NET_INT} -j MASQUERADE -o ${IF_INTERNAL}
iptables -A FORWARD -i ${IF_INT} -o ${IF_INTERNAL} -s ${NET_INT} -j ACCEPT
iptables -A FORWARD -i ${IF_INTERNAL} -o ${IF_INT} -d ${NET_INT} -m state --state RELATED,ESTABLISHED -j ACCEPT

netfilter-persistent save
