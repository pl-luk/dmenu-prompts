# dmenu-prompts
A collection of prompts to make your life easier

## wlan.sh
This script is a little frontend to wpa_supplicant.

### Features
* List all available networks
* Prompt for a password if the device cannot remember the network
* Remember networks even if the device was shutdown 

### Dependencies
* wpa_supplicant
* dhcpcd
* dmenu
* dmenu - center patch
* dmenu - lineheight patch
* ratpoison

### Usage
* `wlan.sh interface` to run wlan.sh on *interface*.
* `wlan.sh --help` or `wlan.sh -h`to display a help message.
