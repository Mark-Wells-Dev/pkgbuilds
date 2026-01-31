#!/bin/bash
set -e

# setup.sh: Prepares the Arch Linux environment for CI jobs.

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

# 4. Create local repository for inter-package dependencies
echo "==> Setting up local package repository..."
mkdir -p /var/local-repo
chown builder:builder /var/local-repo

# Add local repo and mark-wells-dev repo to pacman.conf (before other repos)
# local-repo: for packages built in current CI run
# mark-wells-dev: for packages from previous CI runs (published to GitHub releases)
cat >> /etc/pacman.conf << 'EOF'

[local-repo]
SigLevel = Optional TrustAll
Server = file:///var/local-repo

[mark-wells-dev]
SigLevel = Optional TrustAll
Server = https://github.com/Mark-Wells-Dev/pkgbuilds/releases/download/latest
EOF

# Initialize empty repo database with proper symlinks
# repo-add needs at least one package, so we create empty db manually
touch /var/local-repo/.empty
tar -czf /var/local-repo/local-repo.db.tar.gz -T /dev/null
tar -czf /var/local-repo/local-repo.files.tar.gz -T /dev/null
ln -sf local-repo.db.tar.gz /var/local-repo/local-repo.db
ln -sf local-repo.files.tar.gz /var/local-repo/local-repo.files
chown -R builder:builder /var/local-repo

# Sync package databases (including our empty local-repo)
pacman -Sy

echo "==> Setup complete."
