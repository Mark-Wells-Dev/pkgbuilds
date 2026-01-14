#!/bin/bash

check_rpi_imager() {
    local pkg_name="rpi-imager"
    echo "Checking $pkg_name..."
    
    # Get latest release tag, strip 'v' prefix
    local latest_ver=$(curl -s https://api.github.com/repos/raspberrypi/rpi-imager/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -n "$latest_ver" ]; then
        perform_update "$pkg_name" "$latest_ver"
    else
        echo "Failed to check version for $pkg_name"
    fi
}

check_rpi_imager
