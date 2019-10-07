#!/bin/bash
set -eu

case "$OSTYPE" in
  linux*)
    echo "Configuring for Ubuntu"
    
    # We create the .conf file with the parameters of the VPN, including the authorization through the txt file
    cat <<EOF > /etc/openvpn/client.conf
dev tun
persist-tun
persist-key
cipher AES-256-CBC
auth SHA256
tls-client
client
resolv-retry infinite
remote ${host} ${port} ${proto}
auth-user-pass
remote-cert-tls server
compress lz4-v2

<ca>
${ca_crt}
</ca>
setenv CLIENT_CERT 0
<tls-auth>
${ta_key}
</tls-auth>
key-direction 1
EOF
    # Write the certificate, key and credentials to respective files
    #echo "${ca_crt}" > /etc/openvpn/ca.crt
    #echo "${ta_key}" > /etc/openvpn/ta.key
    echo ${user} > /etc/openvpn/auth.txt
    echo ${password} >> /etc/openvpn/auth.txt

    # We start the VPN service. By default, openvpn takes the client.conf file from the path /etc/openvpn
    sudo systemctl enable openvpn@client.service
    sudo service openvpn start

    sleep 5
    
    sudo cat /var/log/dmesg

    # We add the DNS IP addresses and search domain to resolve the domains correctly
    echo -e "nameserver ${vpn_dns} ${vpn_dns2}\nsearch ${search_domain}\n$(cat /etc/resolv.conf)" > /etc/resolv.conf
    
    ifconfig
    
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
