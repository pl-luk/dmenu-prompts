#!/bin/bash

# Enable wpa_supplicant if not running already
wpa_pid=$(pidof wpa_supplicant)

if [ -z $wpa_pid ]
then
	sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

	# Try to run dhcpcd (if a network was already configured it will get an ip)
	sudo dhcpcd wlan0
fi

# Scan for wifi connections
ratpoison -c "echo Scanning..."
ret=$(sudo wpa_cli -i wlan0 scan)

# If scan failed for whatever reason: quit
if [ $ret = "FAIL" ]
then
	ratpoison -c "echo Failed to scan wlan0"
	exit 1
fi
sleep 4

# Display every available connection in dmenu
wlan=$(sudo wpa_cli -i wlan0 scan_results | tail -n +2 | tr '\t' ' ' | dmenu -c -h 33 -l 20)

# Handle escape press
if [ -z $wlan ]
then
	exit 2
fi

# Get ascii-ssid by converting $wlan to array (by spaces)  and read the last element
IFS=' ' read -r -a array <<< "$wlan"
wifi_selected="${array[-1]}"

# Check if network is already added
existing_networks=$(sudo wpa_cli -i wlan0 list_networks | tail -n +2 | sed 's/\t\t/»/g' | grep -v » | grep -o -P '[0-9]\t.+?(?=\t)')
id_ssid_tuple=$(echo $existing_networks | grep -o -P "[0-9] ($wifi_selected?(?= )|$wifi_selected$)")

# If available then set $network to existing id
if [ -z $id_ssid_tuple ]
then
	# Convert aasci-ssid to hex
	ssid="$(echo $wifi_selected | xxd -ps | sed 's/0a//g')"
	
	# Add new connection and get id
	network=$(sudo wpa_cli -i wlan0 add_network)
	
	# Read password from dmenu
	password=$(echo "" | dmenu -c -h 33 -p Password:)
	
	# Handle escape press
	if [ -z $password ]
	then
		exit 3
	fi
	
	# Calculate pre shared key
	psk="$(wpa_passphrase $wifi_selected $password | grep psk | tail -n 1 | sed 's/psk=//g')"
	
	# Set ssid
	ret=$(sudo wpa_cli -i wlan0 set_network $network ssid $ssid)
	
	# If ssid set failed: quit
	if [ $ret = "FAIL" ]
	then
		ratpoison -c "echo Unable to set SSID to $wifi_selected"
		exit 4
	fi
	
	# Set psk
	ret=$(sudo wpa_cli -i wlan0 set_network $network psk $psk)
	
	# If psk set failed: quit
	if [ $ret = "FAIL" ]
	then
		ratpoison -c "echo Unable to set PSK"
		exit 5
	fi
else
	network=$(echo $id_ssid_tuple | grep -o -P "[0-9]?(?= )")
	echo $existing_networks
	echo $id_ssid_tuple
	echo $network
fi

# Select network
ret=$(sudo wpa_cli -i wlan0 select_network $network)

# IF select network failed: quit
if [ $ret = "FAIL" ]
then
	ratpoison -c "echo Unable to connect to $wifi_selected"
	exit 6
fi

# Enable network
ret=$(sudo wpa_cli -i wlan0 enable_network $network)

# IF enable network failed: quit
if [ $ret = "FAIL" ]
then
	ratpoison -c "echo Unable to connect to $wifi_selected"
	exit 7
fi

ratpoison -c "echo Connecting to $wifi_selected"
sleep 3

# Save current config
ret=$(sudo wpa_cli -i wlan0 save_config)

if [ $ret = "FAIL" ]
then
	ratpoison -c "echo Unable to save config"
fi

# Get ip
sudo dhcpcd wlan0
exit $?
