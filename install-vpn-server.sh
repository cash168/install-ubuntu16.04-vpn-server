#!/bin/bash

SHAREDKEY="1234567890"
VPNLOGIN="user"
VPNPASSWORD="1234567890"

# Public interface
IF_EXT="eth0"

# Internal VPN interface
IF_INT="ppp+"

IP_EXT="x.x.x.x"

apt-get update
apt-get install strongswan xl2tpd mc -y

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

sudo apt-get -y install iptables-persistent

echo "%any %any : PSK \"$SHAREDKEY\"">/etc/ipsec.secrets

echo "config setup
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    nat_traversal=yes
    protostack=netkey
    charondebug=\"ike 5, knl 5, cfg 5, net 5, esp 5, dmn 5,  mgr 5\"

conn l2tpvpn
    type=transport
    authby=secret
    pfs=no
    rekey=no
    keyingtries=1
    left=%any
    leftprotoport=udp/l2tp
    leftid=$IP_EXT
    right=%any
    rightprotoport=udp/%any
    auto=add
    keyexchange=ikev1
    ike=aes256gcm16-aes256gcm12-aes128gcm16-aes128gcm12-sha256-sha1-modp2048-modp4096-modp1024,aes256-aes128-sha256-sha1-modp2048-modp4096-modp1024,3des-sha1-modp1024!
    esp=aes128gcm12-aes128gcm16-aes256gcm12-aes256gcm16-modp2048-modp4096-modp1024,aes128-aes256-sha1-sha256-modp2048-modp4096-modp1024,aes128-sha1-modp2048,aes128-sha1-modp1024,3des-sha1-modp1024,aes128-aes256-sha1-sha256,aes128-sha1,3des-sha1!
">/etc/ipsec.conf

service strongswan restart

echo "[global]
port = 1701
access control = no
ipsec saref = yes
force userspace = yes

auth file = /etc/ppp/chap-secrets

[lns default]
ip range = 172.28.253.96-172.28.253.126
local ip = 172.28.253.65

name = l2tpserver

pppoptfile = /etc/ppp/options.xl2tpd

flow bit = yes
exclusive = no
hidden bit = no
length bit = yes
require authentication = yes
require chap = yes
refuse pap = yes">/etc/xl2tpd/xl2tpd.conf


echo "noccp
auth
crtscts
mtu 1410
mru 1410
nodefaultroute
lock
noproxyarp
silent
modem
asyncmap 0
hide-password
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4">/etc/ppp/options.xl2tpd

service xl2tpd restart

# VPN Net
NET_INT="172.28.253.64/26"

# Clear
iptables -F
iptables -F -t nat

# Set default rule
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

# Allow lo
iptables -A INPUT -i lo -j ACCEPT

# Allow VPN
iptables -A INPUT -i ${IF_INT} -s ${NET_INT} -j ACCEPT

# Allow ipsec
iptables -A INPUT -p udp -m policy --dir in --pol ipsec -m udp --dport 1701 -j ACCEPT
iptables -A INPUT -p esp -j ACCEPT
iptables -A INPUT -p ah -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

# Allow SSH
iptables -A INPUT -m tcp -p tcp --dport 22 -j ACCEPT

# Allow established
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# NAT
iptables -t nat -A POSTROUTING -s ${NET_INT} -j MASQUERADE -o ${IF_EXT}
iptables -A FORWARD -i ${IF_INT} -o ${IF_EXT} -s ${NET_INT} -j ACCEPT
iptables -A FORWARD -i ${IF_EXT} -o ${IF_INT} -d ${NET_INT} -m state --state RELATED,ESTABLISHED -j ACCEPT

netfilter-persistent save

echo "net.ipv4.ip_forward=1">>/etc/sysctl.conf

sysctl -p /etc/sysctl.conf

#Creating VPN user
echo "\"$VPNLOGIN\" l2tpserver \"$VPNPASSWORD\" *
">>/etc/ppp/chap-secrets

echo "All done.."
echo "Edit /etc/ppp/chap-secrets for configuring VPN users..."
