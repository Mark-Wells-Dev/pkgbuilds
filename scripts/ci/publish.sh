#!/bin/bash
set -e

# publish.sh: Signs packages and updates the repository database.
# Usage: ./publish.sh

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
# We expect built packages to be in subdirectories named 'pkg-<name>' or similar,
# OR flattened if 'merge-multiple: true' is used.
# Let's assume they are flattened into 'repo-artifacts/' by the YAML download step.

# Move new packages to repo/
# Artifacts may be in subdirectories (e.g., repo-artifacts/keeper-commander/)
if [ -d "repo-artifacts" ]; then
    find repo-artifacts -name "*.pkg.tar.zst" -exec mv {} repo/ \; 2> /dev/null || true
fi

# 2. Handle Removals
# We need to parse the 'removed' JSON passed as an env var or argument.
# Let's rely on an environment variable REMOVED_JSON
if [ -n "$REMOVED_JSON" ] && [ "$REMOVED_JSON" != "[]" ]; then
    echo "Processing removals: $REMOVED_JSON"
    # Parse JSON array to space-separated string
    REMOVED_LIST=$(echo "$REMOVED_JSON" | jq -r '.[]')

    # Run repo-remove
    # We need the db file. prepare.sh downloaded it to repo/
    if [ -f repo/mark-wells-dev.db.tar.gz ]; then
        repo-remove --sign --key "$GPG_KEY_ID" repo/mark-wells-dev.db.tar.gz $REMOVED_LIST
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
# We use *.pkg.tar.zst glob. repo-add is smart enough to update existing entries or add new ones.
if ls *.pkg.tar.zst 1> /dev/null 2>&1; then
    echo "Updating database..."
    # We use the renamed files (with dots), repo-add handles them fine.
    repo-add --sign --key "$GPG_KEY_ID" mark-wells-dev.db.tar.gz *.pkg.tar.zst

    # Sync legacy/symlink signatures
    if [ -f mark-wells-dev.db.tar.gz.sig ]; then
        cp -f mark-wells-dev.db.tar.gz.sig mark-wells-dev.db.sig 2> /dev/null || true
    fi
    if [ -f mark-wells-dev.files.tar.gz.sig ]; then
        cp -f mark-wells-dev.files.tar.gz.sig mark-wells-dev.files.sig 2> /dev/null || true
    fi
fi

echo "==> Repository updated successfully."
