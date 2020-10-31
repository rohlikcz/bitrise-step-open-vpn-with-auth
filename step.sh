#!/bin/bash
set -eu

case "$OSTYPE" in
  linux*)
    echo "Configuring for Ubuntu"
    echo "Log 1"

    echo "Preparing CA"
    echo "${ca_crt}" > /etc/openvpn/ca.crt
    echo "Preparing TA"
    echo "${ta_key}" > /etc/openvpn/ta.key
    echo ${user} > /etc/openvpn/auth.txt
    echo ${password} >> /etc/openvpn/auth.txt

    cat <<EOF > /etc/openvpn/client.conf
client
dev tun
remote ${host} ${port} ${proto}
resolv-retry infinite
nobind
persist-key
persist-tun
comp-lzo
verb 3
ca /etc/openvpn/ca.crt
tls-auth /etc/openvpn/ta.key
auth-user-pass /etc/openvpn/auth.txt
cipher AES-256-CBC
auth SHA256
tls-client
remote-cert-tls server
setenv CLIENT_CERT 0
key-direction 1
EOF
    # We start the VPN service. By default, openvpn takes the client.conf file from the path /etc/openvpn
    service openvpn start
    
    echo "Log 2"

    # bitrise machines exit on error. We don't want this for this script so we can install resolvconf
    set +e
    
    # Make docker follow another resolv conf so we can remove the current one
    ln -s /etc/resolve.conf /etc/resolve.conf-docker
    rm /etc/resolv.conf
    
    # resolvconf fails in bitrise machines because it can't delete a file shared with the host machine. Let's ignore it    
    apt install resolvconf -y || true
    
    # We add the DNS IP addresses and search domain to resolve the domains correctly and restart resolvconf
    echo -e "nameserver ${vpn_dns}\nnameserver ${vpn_dns2}\nsearch ${search_domain}\n$(cat /etc/resolv.conf)" > /etc/resolvconf/resolv.conf.d/base
    service resolvconf restart
    
    if ifconfig | grep tun0 > /dev/null
    then
      echo "VPN connection succeeded"
    else
      echo "VPN connection failed!"
      exit 1
    fi
    ;;
  darwin*)
    echo "Configuring for Mac OS"
    
    echo "${ca_crt}" > ca.crt
    echo "${ta_key}" > ta.key
    echo ${user} > auth.txt
    echo ${password} >> auth.txt

    # We call openvpn as a command, indicating all the necessary parameters by command line
    sudo openvpn --client --tls-client --remote-cert-tls server --resolv-retry infinite --dev tun --proto ${proto} --remote ${host} ${port} --auth-user-pass auth.txt --auth SHA256 --persist-key --persist-tun --compress lz4-v2 --cipher AES-256-CBC --ca ca.crt --tls-auth ta.key --key-direction 1 > /dev/null 2>&1 &
    
    sleep 5

    # Traverse the macOS network adapters and set the DNS IP addresses and search domain for each one
    IFS=$'\n'
     
    # VPN DNS Server IP addresses and search domain
    vpndns=${vpn_dns}
    vpndns2=${vpn_dns2}
    searchdomain=${search_domain}
    
    adapters=`networksetup -listallnetworkservices |grep -v denotes`
     
    for adapter in $adapters
    do
            echo updating dns for $adapter
            dnssvr=(`networksetup -getdnsservers $adapter`)
     
            if [ $dnssvr != $vpndns ]; then
                    # We set the DNS IP addresses of the VPN
                    networksetup -setdnsservers $adapter $vpndns $vpndns2
                    networksetup -setsearchdomains $adapter $searchdomain
                    else
                    # We reverse the DNS IP address to the originals
                    networksetup -setdnsservers $adapter empty
            fi
    done

    if ifconfig -l | grep utun0 > /dev/null
    then
      echo "VPN connection succeeded"
    else
      echo "VPN connection failed!"
      exit 1
    fi
    ;;
  *)
    echo "Unknown operative system: $OSTYPE, exiting"
    exit 1
    ;;
esac
