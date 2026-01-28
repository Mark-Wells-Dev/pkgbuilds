#!/bin/bash
set -e

# lint.sh: Runs syntax checks on all PKGBUILDs

echo "==> Linting PKGBUILDs..."

# Find all directories containing PKGBUILD
ALL_PACKAGES=$(find . -maxdepth 2 -name PKGBUILD -printf '%h\n' | sed 's|\./||' | sort)

FAILURE=0

for pkg in $ALL_PACKAGES; do
    echo "Checking $pkg/PKGBUILD..."

    # 1. Shell syntax check
    if ! bash -n "$pkg/PKGBUILD"; then
        echo "::error file=$pkg/PKGBUILD::Bash syntax error"
        FAILURE=1
    fi

    # 2. Source verification (checksum check)
    echo "Verifying sources for $pkg..."
    # makepkg cannot run as root. In CI, we use the builder user.
    if [ "$(id -u)" -eq 0 ]; then
        if id -u builder > /dev/null 2>&1; then
            if ! su builder -c "cd $pkg && makepkg --verifysource"; then
                echo "::error file=$pkg/PKGBUILD::Source verification failed"
                FAILURE=1
            fi
        else
            echo "::warning::Running as root and 'builder' user not found. Skipping source verification."
        fi
    else
        if ! (cd "$pkg" && makepkg --verifysource); then
            echo "::error file=$pkg/PKGBUILD::Source verification failed"
            FAILURE=1
        fi
    fi

    # 3. namcap check (if available)
    if command -v namcap > /dev/null; then
        if ! namcap -r PKGBUILD "$pkg/PKGBUILD" > /dev/null; then
            # We don't fail on namcap warnings, but it's good to see them in output if we wanted
            # For now just use it for basic validation
            :
        fi
    fi
done

if [ $FAILURE -eq 1 ]; then
    echo "Linting failed."
    exit 1
fi

echo "Linting passed."
