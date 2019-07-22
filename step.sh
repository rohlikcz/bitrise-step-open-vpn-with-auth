#!/bin/bash
set -eu

case "$OSTYPE" in
  linux*)
    echo "Configuring for Ubuntu"
    
    # We create the .conf file with the parameters of the VPN, including the authorization through the txt file
    cat <<EOF > /etc/openvpn/client.conf
client
remote ${host} ${port}
proto ${proto}
ca 'ca.crt'
tls-auth 'ta.key' 1
auth-user-pass auth.txt
cipher AES-256-CBC
comp-lzo yes
dev tun
nobind
persist-key
persist-tun
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf
down-pre
verb 3
EOF
    # Write the key, certificate and credentials to respective files
    echo ${ca_crt} | base64 -d > /etc/openvpn/ca.crt
    echo ${ta_key} | base64 -d > /etc/openvpn/ta.key
    echo ${user} > /etc/openvpn/auth.txt
    echo ${password} >> /etc/openvpn/auth.txt
    
    # We add the DNS address to resolve the domains correctly
    echo "nameserver ${vpn_dns}
    search ${search_domain}
    $(cat /etc/resolv.conf)" > /etc/resolv.conf

    # We start the VPN service. By default, openvpn takes the client.conf file from the path /etc/openvpn
    service openvpn start

    sleep 5
    
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
    
    echo ${ca_crt} | base64 -D -o ca.crt > /dev/null 2>&1
    echo ${ta_key} | base64 -D -o ta.key > /dev/null 2>&1
    echo ${user} > auth.txt
    echo ${password} >> auth.txt
    
    # Traverse the macOS network adapters and set the DNS in each one
    IFS=$'\n'
     
    # VPN DNS Server
    vpndns=${vpn_dns}
     
    # We store all the adapters to travel them
    adapters=`networksetup -listallnetworkservices |grep -v denotes`
     
    for adapter in $adapters
    do
            echo updating dns for $adapter
            dnssvr=(`networksetup -getdnsservers $adapter`)
     
            if [ $dnssvr != $vpndns ]; then
                    # We set the DNS of the VPN
                    networksetup -setdnsservers $adapter $vpndns
                    else
                    # We reverse the DNS to the originals
                    networksetup -setdnsservers $adapter empty
            fi
    done 
    
    # We call openvpn as a command, indicating all the necessary parameters by command line
    sudo openvpn --client --dev tun --proto ${proto} --remote ${host} ${port} --auth-user-pass auth.txt --nobind --persist-key  --persist-tun --comp-lzo --verb 3 --cipher AES-256-CBC --ca ca.crt --tls-auth ta.key 1 > /dev/null 2>&1 &

    sleep 5

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
