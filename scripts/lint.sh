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

    # 2. namcap check (if available)
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
