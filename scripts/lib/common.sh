#!/bin/bash

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

get_local_version() {
    local pkgbuild="$1"
    grep "^pkgver=" "$pkgbuild" | cut -d'=' -f2
}

perform_update() {
    local pkg_name="$1"
    local new_ver="$2"
    local pkg_dir="$3" # Optional, defaults to pkg_name
    
    [ -z "$pkg_dir" ] && pkg_dir="$pkg_name"
    local pkgbuild="$REPO_ROOT/$pkg_dir/PKGBUILD"
    
    if [ ! -f "$pkgbuild" ]; then
        echo "Error: PKGBUILD not found at $pkgbuild"
        return 1
    fi

    local old_ver=$(get_local_version "$pkgbuild")
    
    if [ "$old_ver" == "$new_ver" ]; then
        # echo "$pkg_name is up to date ($old_ver)"
        return 0
    fi
    
    echo "Updating $pkg_name from $old_ver to $new_ver..."
    
    # Update version
    sed -i "s/^pkgver=.*/pkgver=$new_ver/" "$pkgbuild"
    
    # Reset pkgrel to 1
    sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
    
    # Update checksums
    "$REPO_ROOT/scripts/update-checksums.sh" "$pkgbuild"
    
    # Commit changes
    if [ -n "$CI" ]; then
        git config --global user.name "Updater Bot"
        git config --global user.email "bot@noreply.github.com"
    fi
    
    git add "$pkgbuild"
    git commit -m "chore($pkg_name): update to $new_ver"
}
