# Building and installing Create Booklet

This repository contains every project-owned input used to compile and package Create Booklet. The final public release is signed and notarized with the maintainer's Apple Developer credentials, but anyone can inspect the inputs, compile the helper, and install a locally built copy without those credentials.

## Requirements

- macOS 11 or newer
- Xcode with the macOS SDK
- Xcode command-line tools selected with `xcode-select`

Check the active tools before building:

```sh
xcodebuild -version
xcode-select -p
```

## Build from source

From the repository root, run:

```sh
./scripts/build-local.sh
```

This performs an unsigned Release build from `booklet/main.swift`. By default it creates a universal `arm64` and `x86_64` executable at:

```text
build/local/booklet
```

To build only for the current Apple Silicon architecture:

```sh
BOOKLET_ARCHS=arm64 ./scripts/build-local.sh
```

Verify and test the result:

```sh
build/local/booklet --version
build/local/booklet Release/8pages.pdf
```

The imposed PDF is written to the current user's temporary directory and opened in the default PDF application.

## Build the complete installer locally

To audit the entire packaging chain without Apple Developer credentials, run:

```sh
./scripts/build-installer-local.sh
```

This compiles the helper from source, assembles both workflows, creates an unsigned product archive package, decodes and checks its payload for unwanted `.DS_Store` or literal `._*` files, wraps it in a DMG, creates the ZIP, re-extracts the ZIP, compares the extracted DMG with the original, verifies the disk image checksum, and writes SHA-256 checksums. Its output is under:

```text
build/unsigned-installer/
```

Successful builds remove their intermediate working directory automatically. To retain the compiled helper, package root, synthesized distribution, DMG root, and extracted verification copy for inspection, run:

```sh
KEEP_WORKDIR=1 ./scripts/build-installer-local.sh
```

The local installer has the same project-owned contents and structure as the release, but it deliberately lacks Developer ID signatures and Apple notarization. Do not redistribute it as an official release.

## Inspect the macOS services

The two Automator workflows are committed as ordinary workflow bundles:

- `workflows/quick-action/Create Booklet.workflow` is the Finder Quick Action.
- `workflows/pdf-service/Create Booklet.workflow` is the Print dialog PDF Service.

Both workflow documents contain readable AppleScript and invoke:

```text
/Library/Application Support/Create Booklet/booklet
```

The release package installs that helper once and both services share it.

## Install a locally built copy

Review `scripts/install-local.sh`, then run:

```sh
./scripts/install-local.sh
```

The script rebuilds the helper and requests administrator access to install exactly these paths:

```text
/Library/Application Support/Create Booklet/booklet
/Library/Services/Create Booklet.workflow
/Library/PDF Services/Create Booklet.workflow
```

These locally compiled files are unsigned. They are intended for source auditing and local use, not redistribution. If the services do not appear immediately, log out and back in.

Remove them with:

```sh
./scripts/uninstall.sh
```

## Create the signed release

The maintainer release script uses the same compilation and packaging path as the unsigned local installer. It additionally signs the helper and workflows, signs the installer package, notarizes the package and DMG, staples their tickets, creates the ZIP, then extracts and revalidates the ZIP payload.

### One-time signing and notarization setup

A signed public release requires membership in the Apple Developer Program and two certificates installed, with their private keys, in the login Keychain:

- **Developer ID Application** signs the helper, workflows, and DMG.
- **Developer ID Installer** signs the installer package.

Apple documents how to create and install both certificates in [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates). Confirm that the identities are available with:

```sh
security find-identity -v | grep 'Developer ID'
```

Notarization also requires credentials for Apple's notary service. For the Apple ID authentication method:

1. Ensure the Apple Account associated with the developer team has two-factor authentication enabled.
2. Sign in at [account.apple.com](https://account.apple.com/).
3. Open **Sign-In and Security**, select **App-Specific Passwords**, and generate a password for `notarytool`. See Apple's [app-specific password instructions](https://support.apple.com/en-us/102654).
4. Find the developer **Team ID** in the membership details of the Apple Developer account.
5. Store the credentials in the macOS Keychain:

```sh
xcrun notarytool store-credentials 'AC_NOTARY' \
    --apple-id 'developer@example.com' \
    --team-id 'TEAMID'
```

Because `--password` is omitted, `notarytool` asks for the app-specific password using a secure prompt. Do not enter the normal Apple Account password, put the app-specific password in this repository, or place it directly in a reusable shell command. By default, `notarytool` validates the credentials before saving them.

`AC_NOTARY` is only an arbitrary local profile name. It is not a credential itself. Use the same name for `NOTARY_PROFILE` when building. If the Apple Account password is changed or reset, Apple revokes its app-specific passwords; generate a new one and run `store-credentials` again.

Apple also supports App Store Connect API-key authentication; see [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) for that alternative.

### Run the release build

Its signing configuration is supplied through the environment; no credentials are stored in the repository:

```sh
APP_CERT='Developer ID Application: Your Name (TEAMID)' \
INSTALLER_CERT='Developer ID Installer: Your Name (TEAMID)' \
NOTARY_PROFILE='AC_NOTARY' \
./scripts/build-release.sh
```

By default, release products are written to `dist/`:

```text
dist/CreateBooklet.pkg
dist/CreateBooklet.dmg
dist/CreateBooklet.zip
dist/SHA256SUMS
```

You can override `OUTDIR`, `WORKDIR`, or `BOOKLET_ARCHS` when invoking the script. Set `KEEP_WORKDIR=1` to retain intermediate files after a successful signed build.

## Verify a downloaded release

After extracting `CreateBooklet.zip`, verify the disk image with:

```sh
hdiutil verify CreateBooklet.dmg
codesign --verify --strict --verbose=4 CreateBooklet.dmg
xcrun stapler validate CreateBooklet.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 CreateBooklet.dmg
```

Signing and notarization include certificates, secure timestamps, and an Apple-issued ticket, so independently produced signed files are not expected to be byte-for-byte identical. The source, workflows, packaging inputs, and the commands that produce them are all available for audit.
