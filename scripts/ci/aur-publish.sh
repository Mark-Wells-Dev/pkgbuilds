#!/bin/bash
set -e

# aur-publish.sh: Pushes packages with .aur marker to AUR
# Requires: AUR_SSH_PRIVATE_KEY environment variable

echo "==> Publishing to AUR..."

# Setup SSH for AUR
mkdir -p ~/.ssh
echo "$AUR_SSH_PRIVATE_KEY" > ~/.ssh/aur
chmod 600 ~/.ssh/aur

cat >> ~/.ssh/config << EOF
Host aur.archlinux.org
    IdentityFile ~/.ssh/aur
    User aur
    StrictHostKeyChecking accept-new
EOF

# Configure git
git config --global user.name "Mark Wells"
git config --global user.email "contact@markwells.dev"
git config --global init.defaultBranch master

# Find packages with .aur marker
AUR_PACKAGES=$(find pkgs -maxdepth 2 -name '.aur' -printf '%h\n' | sort)

if [ -z "$AUR_PACKAGES" ]; then
    echo "No packages with .aur marker found."
    exit 0
fi

FAILED=()
PUBLISHED=()

for pkg_dir in $AUR_PACKAGES; do
    pkgname=$(basename "$pkg_dir")
    echo "==> Processing $pkgname..."

    # Generate .SRCINFO
    echo "Generating .SRCINFO..."
    if ! su builder -c "cd $pkg_dir && makepkg --printsrcinfo > .SRCINFO"; then
        echo "::error::Failed to generate .SRCINFO for $pkgname"
        FAILED+=("$pkgname")
        continue
    fi

    # Clone or init AUR repo
    aur_repo="/tmp/aur-$pkgname"
    rm -rf "$aur_repo"

    if git clone "ssh://aur@aur.archlinux.org/${pkgname}.git" "$aur_repo" 2> /dev/null; then
        echo "Cloned existing AUR repo"
    else
        echo "Creating new AUR repo..."
        mkdir -p "$aur_repo"
        cd "$aur_repo"
        git init
        git remote add origin "ssh://aur@aur.archlinux.org/${pkgname}.git"
        cd - > /dev/null
    fi

    # Copy PKGBUILD and .SRCINFO
    cp "$pkg_dir/PKGBUILD" "$aur_repo/"
    cp "$pkg_dir/.SRCINFO" "$aur_repo/"

    # Copy any additional sources (patches, install files, etc.)
    for f in "$pkg_dir"/*.install "$pkg_dir"/*.patch "$pkg_dir"/*.sh; do
        [ -f "$f" ] && cp "$f" "$aur_repo/"
    done

    # Commit and push
    cd "$aur_repo"
    git add -A

    if git diff --cached --quiet; then
        echo "No changes for $pkgname"
    else
        # Get version for commit message
        version=$(grep -m1 "pkgver = " .SRCINFO | cut -d= -f2 | xargs)
        git commit -m "Update to $version"

        if git push origin master 2> /dev/null || git push origin main 2> /dev/null; then
            echo "::notice::Published $pkgname to AUR"
            PUBLISHED+=("$pkgname")
        else
            # New package - need to push to master
            if git push -u origin master; then
                echo "::notice::Published new package $pkgname to AUR"
                PUBLISHED+=("$pkgname")
            else
                echo "::error::Failed to push $pkgname to AUR"
                FAILED+=("$pkgname")
            fi
        fi
    fi
    cd - > /dev/null
done

# Summary
echo ""
echo "==> AUR Publish Summary"
echo "Published: ${PUBLISHED[*]:-none}"
echo "Failed: ${FAILED[*]:-none}"

if [ ${#FAILED[@]} -gt 0 ]; then
    exit 1
fi
