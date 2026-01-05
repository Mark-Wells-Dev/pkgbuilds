# pkgbuilds

Personal Arch Linux package repository with automated builds and version tracking.

## Usage

```bash
# Import and trust the signing key
curl -sL https://github.com/m-wells.gpg | sudo pacman-key --add -
sudo pacman-key --lsign-key CCDA692647943A2B

# Add to /etc/pacman.conf (before [core] for priority over official packages)
[m-wells]
SigLevel = Required DatabaseOptional
Server = https://github.com/m-wells/pkgbuilds/releases/latest/download

# Sync and install
sudo pacman -Sy
sudo pacman -S gemini-cli rpi-imager
```

## Packages

| Package | Source | Description |
|---------|--------|-------------|
| gemini-cli | npm | Google's Gemini AI CLI agent |
| rpi-imager | AppImage | Raspberry Pi Imaging Utility |

## How It Works

- **PKGBUILDs** are stored in this repo
- **Renovate Bot** monitors upstream releases and creates PRs with version bumps
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

2. Add a Renovate comment for version tracking:
   ```bash
   pkgver=1.0.0
   # renovate: datasource=npm depName=package-name
   pkgrel=1
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
