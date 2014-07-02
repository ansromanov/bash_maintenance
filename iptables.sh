#!/bin/sh

# Load modules
modprobe ip_gre
modprobe ip_nat_pptp

# Aliases
LOCAL=192.168.120.0/24
WAN=eth0 # internet
LAN=eth1 # local area 192.168.120.0/24
VPN=ppp+ # pptp server

# Iptables path
IPT="/sbin/iptables"


# Delete all rules
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X


# Policy - decline all connections
$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP


# Allow loopback traffic
$IPT -A INPUT  -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT


# Allow established connections
$IPT -I INPUT  1 -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPT -I OUTPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPT -I FORWARD 1 -m state --state ESTABLISHED,RELATED -j ACCEPT


# Don't forward from the outside to the outside. (we are not a public router)
$IPT -A FORWARD -i $WAN -o $WAN -j REJECT

## PPTP server forward to LAN
#$IPT -A FORWARD -p TCP --dport 1723 -j LOG --log-prefix "IPTables-FORW_PPTP: " --log-level 4
#$IPT -A FORWARD -p TCP --dport 1723 -j ACCEPT                          # PPTP
#$IPT -A FORWARD -p GRE -j LOG --log-prefix "IPTables-FORW_PPTP_GRE: " --log-level 4
#$IPT -A FORWARD -p GRE -j ACCEPT                                               # GRE Protocol (PPTP)

# Allow outgoing traffic from local network
$IPT -A FORWARD -i $LAN -o $WAN -j ACCEPT                                               # Allow local networking

# Masquerade.
#$IPT -t nat -A POSTROUTING -o $LAN  -j MASQUERADE
$IPT -t nat -A POSTROUTING -o $WAN -s 192.168.10.0/24 -j MASQUERADE
#$IPT -t nat -A POSTROUTING -o $VPN -j MASQUERADE
#$IPT -t nat -A POSTROUTING -j MASQUERADE

# Blacklist IP's
# iptables -A INPUT -s "BLOCK_THIS_IP" -j DROP


# Whitelist IP's
#iptables -A INPUT -s 92.255.155.112/32 -j ACCEPT


# Allow LAN users forwarding protocols - more secure
#$IPT -A FORWARD -i $LAN -p TCP --dport 1024:65535 -j ACCEPT                            # Dymamic ports
#$IPT -A FORWARD -i $LAN -p UDP --dport 1024:65535 -j ACCEPT                            # Dymamic ports
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP -m multiport --dports 80,443 -j ACCEPT          # HTTP, HTTPS
#$IPT -A FORWARD -i $LAN -o $WAN -p UDP -m multiport --dports 80,443 -j ACCEPT          # HTTP, HTTPS
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP -m multiport --dports 465,993 -j ACCEPT         # SMTP, IMAP
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP --dport 5222 -j ACCEPT                          # ICQ
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP -m multiport --dports 22,7322 -j ACCEPT         # SSH
#$IPT -A FORWARD -i $LAN -o $WAN -p ICMP --icmp-type 8 -j ACCEPT                                # Ping
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP --dport 5938 -j ACCEPT                          # Teamviewer
#$IPT -A FORWARD -i $LAN -o $WAN -p UDP --dport 5938 -j ACCEPT                          # Teamviewer
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP --dport 3389 -j ACCEPT                          # RDP
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP --dport 2466 -j ACCEPT                          # RDP 1C
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP -m multiport --dports 20,21,990 -j ACCEPT                       # FTP
#$IPT -A FORWARD -i $LAN -o $WAN -p UDP --dport 123 -j ACCEPT                           # NTP
#$IPT -A FORWARD -i $LAN -p TCP --dport 53 -j ACCEPT                                    # DNS Requests
#$IPT -A FORWARD -i $LAN -p UDP --dport 53 -j ACCEPT                                    # DNS Requests
#$IPT -A FORWARD -i $LAN -o $WAN -p TCP --dport 1723 -j ACCEPT                                  # PPTP
#$IPT -A FORWARD -i $LAN -o $WAN -p GRE -j ACCEPT                                               # GRE Protocol (PPTP)

# PPTP Forwarding
$IPT -A FORWARD -p GRE -j ACCEPT
#$IPT -A FORWARD -i $WAN -p TCP -m multiport --dports 1723 -j ACCEPT
$IPT -A FORWARD p TCP -m multiport --dports 1723 -j ACCEPT
$IPT -t nat -A PREROUTING -p tcp -d 92.255.155.114 --dport 1723 -j DNAT --to-destination 192.168.120.74:1723
$IPT -t nat -A POSTROUTING -p tcp -d 192.168.120.74 --dport 1723 -j SNAT --to-source 92.255.155.114

# VPN clients access to local network
$IPT -A FORWARD -i $VPN -o $LAN -p TCP -m multiport --dports 53,135 -j ACCEPT                                   # DNS Requests
$IPT -A FORWARD -i $VPN -o $LAN -p UDP --dport 53 -j ACCEPT                                     # DNS Requests
$IPT -A FORWARD -i $VPN -o $LAN -p UDP -m multiport --dports 137,138,389 -j ACCEPT                              # AD
$IPT -A FORWARD -i $VPN -o $LAN -p TCP -m multiport --dports 88 -j ACCEPT                               # Kerberos auth
$IPT -A FORWARD -i $VPN -o $LAN -p TCP -m multiport --dports 389,445 -j ACCEPT                          # AD
$IPT -A FORWARD -i $VPN -o $LAN -p TCP -m multiport --dports 1433 -j ACCEPT                             # SQL Server
$IPT -A FORWARD -i $VPN -o $LAN -p TCP --dport 3389 -j ACCEPT                           # RDP
$IPT -A FORWARD -i $VPN -o $LAN -p ICMP --icmp-type 8 -j ACCEPT                         # Ping
$IPT -A FORWARD -i $VPN -o $LAN -p TCP -m multiport --dports 22,7322 -j ACCEPT          # SSH


# Dynamic ports
$IPT -A OUTPUT -o $LAN -p TCP -m multiport --dports 1024:65535 -j ACCEPT

# Allow HTTP, HTTPS from local network
$IPT -A INPUT -i $LAN -p TCP -m multiport --dports 80,443 -j ACCEPT
$IPT -A INPUT -i $VPN -p TCP -m multiport --dports 80,443 -j ACCEPT


# Allow HTTP, HTTPS access
$IPT -A OUTPUT -p TCP -m multiport --dports 80,443 -j ACCEPT


# Allow FTP connections
$IPT -A INPUT -p TCP -m multiport --dports ftp -j ACCEPT

# Allow SSH connections
$IPT -A OUTPUT -p TCP -m multiport --dports 22,7322 -j ACCEPT

# Allow DNS requests
$IPT -A OUTPUT -p UDP --dport 53 -j ACCEPT
$IPT -A OUTPUT -p TCP --dport 53 -j ACCEPT


# Allow ICMP ping
$IPT -A INPUT -p ICMP --icmp-type 8 -j ACCEPT
$IPT -A OUTPUT -p ICMP --icmp-type 8 -j ACCEPT


# Allow SSH access to server on port 7322 and port 22 in local network
$IPT -t nat -A PREROUTING -s $LOCAL -p TCP --dport 22 -j REDIRECT --to-port 7322
$IPT -A INPUT -p TCP --dport 7322 -j LOG --log-prefix "IPTables-SSH_login: " --log-level 4
$IPT -A INPUT -p TCP --dport 7322 -j ACCEPT

## PPTP server
##$IPT -A INPUT -p TCP --dport 1723 -j ACCEPT                           # PPTP
##$IPT -A INPUT -p GRE -j ACCEPT                                                # GRE Protocol (PPTP)
##$IPT -A OUTPUT -p GRE -j ACCEPT                                               # GRE Protocol (PPTP)

# IPSec & L2TP server
$IPT -A INPUT -p ESP -j ACCEPT
$IPT -A INPUT -p TCP --dport 500 -j ACCEPT      # ipsec
$IPT -A INPUT -p UDP --dport 500 -j ACCEPT      # ipsec
$IPT -A INPUT -p UDP --dport 4500 -j ACCEPT     # ipsec NAT-T
#$IPT -A INPUT -p TCP --dport 1701 -j ACCEPT    # open this ports for testing purposes only
$IPT -A INPUT -p UDP --dport 1701 -j ACCEPT
#$IPT -A INPUT -p UDP --sport 1701 -j ACCEPT
#$IPT -A FORWARD -p TCP --dport 1701 -j ACCEPT
#$IPT -A FORWARD -p UDP --dport 1701 -j ACCEPT
#$IPT -A OUTPUT -p TCP --sport 1701 -j ACCEPT
$IPT -A OUTPUT -p UDP --sport 1701 -j ACCEPT


# Allow SNMP
for i in $LAN $VPN
do
        $IPT -A INPUT -i $LAN -p UDP --dport 161 -j ACCEPT
        $IPT -A OUTPUT -o $LAN  -p UDP --dport 161 -j ACCEPT
done


# Allow NTP service
$IPT -A INPUT -p UDP --dport 123 -j ACCEPT
$IPT -A OUTPUT -p UDP --dport 123 -j ACCEPT


# Allow AD, Kerberos and NETBIOS discovery in local network
$IPT -A INPUT  -p TCP -m multiport --dports 139,445 -j ACCEPT
$IPT -A INPUT  -p UDP -m multiport --dports 137,138 -j ACCEPT
$IPT -A INPUT  -p UDP -m multiport --sports 137 -j ACCEPT
$IPT -A OUTPUT -p TCP -o $LAN -m multiport --dports 88,139,389,445,464,750,3268 -j ACCEPT
$IPT -A OUTPUT -p UDP -o $LAN -m multiport --dports 88,389,464 -j ACCEPT
$IPT -A OUTPUT -p UDP -m multiport --dports 137,138 -j ACCEPT


# DHCP
$IPT -A INPUT -p TCP -m multiport --dports 67,68,135 -j ACCEPT
$IPT -A INPUT -p UDP -m multiport --dports 67,68 -j ACCEPT
$IPT -A OUTPUT -p UDP -m multiport --dports 67,68 -j ACCEPT
$IPT -A OUTPUT -p TCP  -m multiport --dports 135 -j ACCEPT

# SMTP
$IPT -A OUTPUT -p TCP -m multiport --dports 587 -j ACCEPT

# Enable 1C (192.168.120.151) RDP publication on port 2466
#$IPT -A FORWARD -p TCP --dport 3389 -j ACCEPT
#$IPT -A FORWARD -p TCP --sport 3389 -j ACCEPT
$IPT -t nat -A PREROUTING -d 92.255.125.150 -p TCP --dport 3389 -j DNAT --to-destination 192.168.120.147:3389


# Validate packets
$IPT -A INPUT   -m state --state INVALID -j DROP                        # Drop invalid packets
$IPT -A FORWARD -m state --state INVALID -j DROP                        # Drop invalid packets
$IPT -A OUTPUT  -m state --state INVALID -j DROP                        # Drop invalid packets
$IPT -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP         # Drop TCP - SYN,FIN packets
$IPT -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP         # Drop TCP - SYN,RST packets
$IPT -A INPUT -d 255.255.255.255 -j DROP                                # Network flood
$IPT -A INPUT -i $WAN -d 224.0.0.1/24 -j DROP                           # Internet IGMP flood
$IPT -A INPUT -i $LAN -p udp --dport 17500 -j DROP                      # Dropbox flood
#$IPT -A FORWARD -i $LAN -o $WAN -p UDP --sport 16664 -j DROP           # Skype flood
$IPT -A INPUT -p UDP --dport 5351 -j DROP                               # Skype flood
$IPT -A INPUT -p UDP --dport 8905 -j DROP                               # Apple flood
$IPT -A INPUT -i $WAN -p TCP -m multiport --dports 80,443 -j DROP       # Not a web server


# SYNFLOOD CHAIN
#$IPT -A INPUT -m state --state NEW -p tcp -m tcp --syn -m recent --name SYNFLOOD --set
#$IPT -A INPUT -m state --state NEW -p tcp -m tcp --syn -m recent --name SYNFLOOD --update --seconds 1 --hitcount 60 -j DROP


# Logging to /var/log/syslog
$IPT -N INLOG
$IPT -N OUTLOG
$IPT -N FORWLOG
$IPT -A INPUT -j INLOG
$IPT -A OUTPUT -j OUTLOG
$IPT -A FORWARD -j FORWLOG
$IPT -A INLOG -m limit --limit 60/min -j LOG --log-prefix "IPTables-IN_Dropped: " --log-level 4
$IPT -A OUTLOG -m limit --limit 60/min -j LOG --log-prefix "IPTables-OUT_Dropped: " --log-level 4
$IPT -A FORWLOG -m limit --limit 60/min -j LOG --log-prefix "IPTables-FORW_Dropped: " --log-level 4
$IPT -A INLOG -j DROP
$IPT -A OUTLOG -j DROP
$IPT -A FORWLOG -j DROP
