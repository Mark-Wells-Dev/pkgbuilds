#!/bin/bash
set -e

# build.sh: Builds a single package and runs its smoke test.
# Usage: ./build.sh <package_directory>

PKG="$1"

if [ -z "$PKG" ]; then
    echo "Error: Package directory argument required."
    exit 1
fi

if [ ! -d "$PKG" ]; then
    echo "Error: Directory '$PKG' not found."
    exit 1
fi

echo "==> Building package: $PKG"

# 1. Build
# Run makepkg as the builder user
# -s: Install deps, --noconfirm: No prompts

# Step 1: Install dependencies (Repo + AUR) using yay
echo "==> Resolving dependencies with yay..."
# Extract dependencies from PKGBUILD using makepkg --printsrcinfo
DEPS=$(su builder -c "cd $PKG && makepkg --printsrcinfo" | awk '/^\s+(make)?depends\s+=\s+/{ print $3 }' | tr '\n' ' ')

if [ -z "$DEPS" ]; then
    echo "::warning::No dependencies found or failed to parse."
else
    echo "==> Installing: $DEPS"
    if ! su builder -c "yay -S --noconfirm --asdeps --needed $DEPS"; then
        echo "::error::Failed to install dependencies for $PKG"
        exit 1
    fi
fi

# Step 2: Build the package (deps are now installed)
echo "==> compiling with makepkg..."
if ! su builder -c "cd $PKG && makepkg --noconfirm"; then
    echo "::error::Failed to build $PKG"
    exit 1
fi

# Rename artifact if it contains colons (GitHub Actions compatibility)
for f in "$PKG"/*.pkg.tar.zst; do
    [ -e "$f" ] || continue
    if [[ "$f" == *:* ]]; then
        new_name=$(echo "$f" | tr ':' '.')
        echo "Renaming artifact: $f -> $new_name"
        mv "$f" "$new_name"
    fi
done

# 2. Smoke Test
# Look for check.sh in the package directory
if [ -f "$PKG/check.sh" ]; then
    echo "==> Running smoke test ($PKG/check.sh)..."
    chmod +x "$PKG/check.sh"
    # We run the check script.
    # It is up to the check script to decide if it needs sudo or specific user.
    # We pass the package file path as an argument to the check script if needed.
    # Find the built package
    PKG_FILE=$(find "$PKG" -name "*.pkg.tar.zst" | head -n 1)

    # Run the check script
    if ! "$PKG/check.sh" "$PKG_FILE"; then
        echo "::error::Smoke test failed for $PKG"
        exit 1
    fi
    echo "==> Smoke test passed."
else
    echo "==> No check.sh found, skipping specific smoke test."
    # Basic verification: Check if package file exists
    if ! ls "$PKG"/*.pkg.tar.zst 1> /dev/null 2>&1; then
        echo "::error::Build seemed to succeed but no .pkg.tar.zst found."
        exit 1
    fi
fi

echo "==> Build and test complete for $PKG"
