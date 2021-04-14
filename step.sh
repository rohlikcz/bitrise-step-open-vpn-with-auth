#!/bin/bash
set -eu
    
if [ -z "${user}" ]
then
  echo "username is empty"
  exit 1
fi
if [ -z "${password}" ]
then
  echo "password is empty"
  exit 1
fi
if [ -z "${ovpn_file}" ]
then
  echo "ovpn file is empty"
  exit 1
fi

case "$OSTYPE" in
  linux*)
    echo "Configuring for Ubuntu"
    
    # We create the .conf file with the parameters of the VPN, including the authorization through the txt file
    cat <<EOF > /etc/openvpn/client.conf
${ovpn_file}
EOF
    # Write the certificate, key and credentials to respective files
    echo ${user} > /etc/openvpn/auth.conf
    echo ${password} >> /etc/openvpn/auth.conf
    
    # We start the VPN service. By default, openvpn takes the client.conf file from the path /etc/openvpn
    #service openvpn start
    openvpn --config /etc/openvpn/client.conf --auth-user-pass /etc/openvpn/auth.conf &
    
    echo "$(date) Sleeping"
    sleep 60
    echo "$(date) Fully awake"
    
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
    
    mkdir ./openvpn
    
    # We create the .conf file with the parameters of the VPN, including the authorization through the txt file
    cat <<EOF > ./openvpn/client.conf
${ovpn_file}
EOF
    # Write the certificate, key and credentials to respective files
    #touch ./openvpn/auth.txt
    echo ${user} > ./openvpn/auth.conf
    echo ${password} >> ./openvpn/auth.conf
    
    #For debug add '--log ./openvpn/ovpn-pls.log --verb 5' and call 'sudo cat ./openvpn/ovpn-pls.log'
    sudo openvpn --config ./openvpn/client.conf --auth-user-pass ./openvpn/auth.conf > /dev/null 2>&1 &
    
    echo "$(date) Sleeping"
    sleep 15
    echo "$(date) Fully awake"

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
