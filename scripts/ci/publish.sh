#!/bin/bash
set -e

# publish.sh: Signs packages and updates the repository database.
# Usage: ./publish.sh

# Source common variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

echo "==> Finalizing repository..."

# Configure GPG for non-interactive use
export GPG_TTY=$(tty 2> /dev/null || echo /dev/tty)
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg
echo "allow-loopback-pinentry" >> ~/.gnupg/gpg-agent.conf
echo "pinentry-mode loopback" >> ~/.gnupg/gpg.conf
gpgconf --kill gpg-agent 2> /dev/null || true

# Ensure GPG key is imported (handled by YAML step usually, but check)
if ! gpg --list-secret-keys > /dev/null 2>&1; then
    echo "Error: GPG key not found. Ensure it was imported."
    exit 1
fi

mkdir -p repo

# 1. Gather Artifacts
# The YAML downloads artifacts to the current directory (or specific paths).
# Let's rely on an environment variable REMOVED_JSON
if [ -d "repo-artifacts" ]; then
    find repo-artifacts -name "*.pkg.tar.zst" -exec mv {} repo/ \; 2> /dev/null || true
fi

# 2. Handle Removals
if [ -n "$REMOVED_JSON" ] && [ "$REMOVED_JSON" != "[]" ]; then
    echo "Processing removals: $REMOVED_JSON"
    # Parse JSON array to space-separated string
    REMOVED_LIST=$(echo "$REMOVED_JSON" | jq -r '.[]')

    # Run repo-remove
    if [ -f "repo/${REPO_NAME}.db.tar.gz" ]; then
        # Use su builder if needed, but here we are usually root in container
        # repo-remove handles signing if --sign is passed
        repo-remove --sign --key "$GPG_KEY_ID" "repo/${REPO_NAME}.db.tar.gz" $REMOVED_LIST
    else
        echo "Warning: Database not found, cannot remove packages."
    fi
fi

# 3. Sign and Add New Packages
cd repo

# Sign packages
for pkg in *.pkg.tar.zst; do
    [ -f "$pkg" ] || continue
    # Detach sign if sig doesn't exist
    if [ ! -f "${pkg}.sig" ]; then
        echo "Signing $pkg..."
        if [ -n "$GPG_PASSPHRASE" ]; then
            echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --detach-sign --no-armor "$pkg"
        else
            gpg --batch --yes --pinentry-mode loopback --detach-sign --no-armor "$pkg"
        fi
    fi
done

# Update Database
# We only want to run repo-add if there's a DB to update or new packages to add.
if [ -f "${REPO_NAME}.db.tar.gz" ] || ls *.pkg.tar.zst 1> /dev/null 2>&1; then
    echo "Updating database..."

    # Collect existing packages if any
    PKGS_TO_ADD=""
    if ls *.pkg.tar.zst 1> /dev/null 2>&1; then
        PKGS_TO_ADD="*.pkg.tar.zst"
    fi

    # repo-add will create it if it doesn't exist.
    # If PKGS_TO_ADD is empty, it just re-signs/refreshes the DB
    repo-add --sign --key "$GPG_KEY_ID" "${REPO_NAME}.db.tar.gz" $PKGS_TO_ADD

    # Ensure symlinks exist for pacman's default expectations
    ln -sf "${REPO_NAME}.db.tar.gz" "${REPO_NAME}.db"
    ln -sf "${REPO_NAME}.files.tar.gz" "${REPO_NAME}.files"

    # Sync legacy/symlink signatures
    if [ -f "${REPO_NAME}.db.tar.gz.sig" ]; then
        cp -f "${REPO_NAME}.db.tar.gz.sig" "${REPO_NAME}.db.sig" 2> /dev/null || true
    fi
    if [ -f "${REPO_NAME}.files.tar.gz.sig" ]; then
        cp -f "${REPO_NAME}.files.tar.gz.sig" "${REPO_NAME}.files.sig" 2> /dev/null || true
    fi
fi

echo "==> Repository updated successfully."
