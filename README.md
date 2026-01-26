# pkgbuilds

[![Build packages](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/build.yml/badge.svg)](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/build.yml)
[![Check for Updates](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/watch.yml/badge.svg)](https://github.com/mark-wells-dev/pkgbuilds/actions/workflows/watch.yml)

Personal Arch Linux package repository with automated builds and version tracking.

## Usage

```bash
# Import the maintainer's signing key (@m-wells)
curl -sL https://github.com/m-wells.gpg | sudo pacman-key --add -
sudo pacman-key --lsign-key CCDA692647943A2B

# Add to /etc/pacman.conf (before [core] for priority over official packages)
[mark-wells-dev]
SigLevel = Required DatabaseOptional
Server = https://github.com/mark-wells-dev/pkgbuilds/releases/latest/download

# Sync and install
sudo pacman -Sy
sudo pacman -S <package-name>
```

## Packages

| Package    | Source   | Description                   |
| ---------- | -------- | ----------------------------- |
| gemini-cli | npm      | Google's Gemini AI CLI agent  |
| rpi-imager | AppImage | Raspberry Pi Imaging Utility  |
| virtctl    | Binary   | Kubernetes Virtualization CLI |

## How It Works

- **PKGBUILDs** are stored in this repo
- **CI/CD** via GitHub Actions (builds in clean Arch Linux container)
- **Automatic Releases** created when changes are pushed to `main`
- **GitHub Actions** builds packages on merge to main (only changed packages are rebuilt)
- **Packages are signed** with GPG and published to GitHub Releases
- **pacman** syncs directly from the release assets

### CI Details

- Only changed packages are rebuilt (detected via GitHub API)
- Deleted packages are automatically removed from the repo database
- Old package versions are cleaned up when new versions are uploaded
- If a build fails, remaining packages continue building; successful packages are still released
- **Force rebuild all**: Use Actions → "Run workflow" → check "Rebuild all packages"

## Adding a New Package

1. Create a directory with a `PKGBUILD` (directory name must match `pkgname`):

   ```
   my-package/
   └── PKGBUILD    # pkgname=my-package
   ```

2. Add an update script in `scripts/packages/<pkgname>.sh`:

```bash
check_pkgname() {

  # check logic here, call perform_update

}

check_pkgname
```

Common datasources:

- `npm` - for npm packages
- `github-releases` - for GitHub releases

3. Commit and push - the package will be automatically detected and built

## Contributing

1. Fork this repository
2. Add a new package directory with a PKGBUILD
3. Submit a pull request
4. CI will build and verify the package
5. Once merged, the package is automatically published
