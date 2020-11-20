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
    echo ${user} > /etc/openvpn/auth.txt
    echo ${password} >> /etc/openvpn/auth.txt
    
    # We start the VPN service. By default, openvpn takes the client.conf file from the path /etc/openvpn
    #service openvpn start
    openvpn --config /etc/openvpn/client.conf &
    
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
    
    mkdir ./openvpn
    
    # We create the .conf file with the parameters of the VPN, including the authorization through the txt file
    cat <<EOF > ./openvpn/client.conf
${ovpn_file}
EOF
    # Write the certificate, key and credentials to respective files
    #touch ./openvpn/auth.txt
    echo ${user} > ./openvpn/auth.txt
    echo ${password} >> ./openvpn/auth.txt
    
    #For debug add '--log ./openvpn/ovpn-pls.log --verb 5' and call 'sudo cat ./openvpn/ovpn-pls.log'
    sudo openvpn --config ./openvpn/client.conf > /dev/null 2>&1 &
    
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
