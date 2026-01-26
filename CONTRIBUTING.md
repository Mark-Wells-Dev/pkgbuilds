# Contributing to pkgbuilds

This guide provides instructions for building, testing, and adding packages to this repository.

## Development Environment

These instructions assume you are using Arch Linux.

### Building Packages Locally

To build a package exactly as it will be built in CI:

```bash
cd <package-name>
makepkg -s
```

Common flags:

- `-s`: Install missing dependencies automatically.
- `--noconfirm`: Build without prompting for dependency installation.
- `-f`: Force rebuild (overwrite existing package).

### Updating Checksums

If you change source URLs or manually bump versions:

```bash
updpkgsums
```

## Repository Structure

Each package is a directory containing a `PKGBUILD`. The directory name **must** match the `pkgname` in the PKGBUILD.

```text
gemini-cli/PKGBUILD     # npm package wrapper (arch='any')
rpi-imager/PKGBUILD     # AppImage wrapper (arch='x86_64')
virtctl/PKGBUILD        # Binary download
```

## Package Patterns

### npm Packages

- Use `arch=('any')`.

- Download the tarball from the npm registry.

- Install using `npm install -g --prefix`.

#### Handling Deprecation Warnings

Since Arch Linux runs the latest Node.js versions, many packages may emit noisy deprecation warnings (e.g., `punycode`). In these cases, replace the default symlink with a wrapper script:

1. Create `wrapper.sh`:

   ```bash
   #!/bin/bash
   
   export NODE_OPTIONS="--no-deprecation"
   
   exec /usr/lib/node_modules/ < package-name > /bin/ < entry-point > "$@"
   ```

2. Update `PKGBUILD`:

   ```bash
   source=(... "wrapper.sh")
   
   package() {
   
     # ... npm install ...
   
     # Replace symlink
   
     rm "${pkgdir}/usr/bin/<binary-name>"
   
     install -Dm755 "${srcdir}/wrapper.sh" "${pkgdir}/usr/bin/<binary-name>"
   
   }
   ```

### AppImage Packages

- Use `arch=('x86_64')`.
- Install the binary to `/opt/`.
- Create a wrapper script in `/usr/bin/`.
- Extract the desktop file and icon using `--appimage-extract`.

### Privilege Elevation

For applications requiring root access, use `pkexec` in the wrapper script (without the `exec` prefix to maintain compatibility with launchers like `rofi`).

## Local Testing

You can test wrapper script changes directly on your system without rebuilding the entire package:

```bash
sudo nano /usr/bin/<binary-name>
# edit, test, then sync changes back to the PKGBUILD or wrapper file
```

## Automated Updates

Updates are managed by a custom script triggered via GitHub Actions (`.github/workflows/watch.yml`).

To add a package to the automated update tracker:

1. Create a script in `scripts/packages/<pkgname>.sh`.
2. Use the `perform_update` function defined in `scripts/lib/common.sh`.

Example `scripts/packages/gemini-cli.sh`:

```bash
check_gemini_cli() {
  local latest_ver=$(npm view @google/gemini-cli version)
  perform_update "gemini-cli" "$latest_ver"
}
check_gemini_cli
```
