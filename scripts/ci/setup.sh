#!/bin/bash
set -e

# setup.sh: Prepares the Arch Linux environment for CI jobs.

# Source common variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

echo "==> Setting up build environment..."

# 1. Update system and install base dependencies
# We check if we are in an Arch environment first
if [ ! -f /etc/arch-release ]; then
    echo "Error: This script must be run on Arch Linux."
    exit 1
fi

# Ensure base-devel is present (though the container should have it)
pacman -Syu --noconfirm
pacman -S --noconfirm --needed npm fuse2 zlib github-cli sudo git base-devel jq openssh

# 2. Setup non-root builder user
if ! id -u builder > /dev/null 2>&1; then
    echo "==> Creating builder user..."
    useradd -m builder
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# 2.5 Install AUR helper (yay-bin)
echo "==> Installing yay-bin..."
su builder -c "
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
"

# 3. Fix permissions for the workspace
# GitHub Actions checkouts are owned by root in containers
chown -R builder:builder .
# Allow builder to access the GITHUB_OUTPUT file (owned by root usually)
if [ -n "$GITHUB_OUTPUT" ]; then
    chmod 666 "$GITHUB_OUTPUT"
fi

# Mark workspace as safe for git (needed for prepare.sh to read commit messages)
git config --global --add safe.directory "$(pwd)"

# 4. Create local repository for inter-package dependencies
echo "==> Setting up local package repository..."
mkdir -p /var/local-repo
chown builder:builder /var/local-repo

# Add local-repo to pacman.conf
cat >> /etc/pacman.conf << 'EOF'

[local-repo]
SigLevel = Optional TrustAll
Server = file:///var/local-repo
EOF

# Determine which remote repo to use (fallback to old name for migration)
ACTIVE_REPO_NAME="${REPO_NAME}"
REPO_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/latest/${REPO_NAME}.db.tar.gz"

if ! curl -sL --output /dev/null --silent --fail "$REPO_URL"; then
    OLD_REPO_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/latest/${OLD_REPO_NAME}.db.tar.gz"
    if curl -sL --output /dev/null --silent --fail "$OLD_REPO_URL"; then
        echo "==> ${REPO_NAME} not found, falling back to ${OLD_REPO_NAME} for migration"
        ACTIVE_REPO_NAME="${OLD_REPO_NAME}"
    else
        ACTIVE_REPO_NAME=""
    fi
fi

if [ -n "$ACTIVE_REPO_NAME" ]; then
    echo "==> Adding ${ACTIVE_REPO_NAME} repository to pacman.conf"
    cat >> /etc/pacman.conf << EOF

[${ACTIVE_REPO_NAME}]
SigLevel = Never
Server = https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/latest
EOF
fi

# Initialize empty repo database with proper symlinks
touch /var/local-repo/.empty
tar -czf /var/local-repo/local-repo.db.tar.gz -T /dev/null
tar -czf /var/local-repo/local-repo.files.tar.gz -T /dev/null
ln -sf local-repo.db.tar.gz /var/local-repo/local-repo.db
ln -sf local-repo.files.tar.gz /var/local-repo/local-repo.files
chown -R builder:builder /var/local-repo

# Sync package databases
pacman -Sy || echo "Warning: Failed to synchronize some databases. Proceeding anyway."

echo "==> Setup complete."
