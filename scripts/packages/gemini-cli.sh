#!/bin/bash

check_gemini_cli() {
    local pkg_name="gemini-cli"
    echo "Checking $pkg_name..."
    
    local latest_ver=$(npm view @google/gemini-cli version 2>/dev/null)
    
    if [ -n "$latest_ver" ]; then
        perform_update "$pkg_name" "$latest_ver"
    else
        echo "Failed to check version for $pkg_name"
    fi
}

check_gemini_cli
