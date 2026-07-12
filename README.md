# Create Booklet

Create Booklet is a macOS PDF imposition tool. It rearranges a multipage PDF into printer spreads that can be printed double-sided, folded, and assembled as a booklet.

The project includes a Swift command-line helper and two macOS Automator services that provide the same functionality from Finder and the Print dialog.

## Install

Download [`Release/CreateBooklet.zip`](Release/CreateBooklet.zip), extract `CreateBooklet.dmg`, and run `CreateBooklet.pkg`. The installer is signed and notarized for distribution outside the Mac App Store.

It installs:

- A Finder Quick Action at `/Library/Services/Create Booklet.workflow`
- A Print dialog PDF Service at `/Library/PDF Services/Create Booklet.workflow`
- A shared helper at `/Library/Application Support/Create Booklet/booklet`

If the services do not appear immediately after installation, log out and back in.

## Use

### Finder

Select one or more PDF files, then choose **Create Booklet** from Finder's Quick Actions or Services menu.

### Print dialog

Open the PDF menu in a macOS Print dialog and choose **Create Booklet**.

### Command line

Run the installed helper directly:

```sh
'/Library/Application Support/Create Booklet/booklet' input.pdf
```

Display its version with:

```sh
'/Library/Application Support/Create Booklet/booklet' --version
```

The generated booklet PDF is written to the current user's temporary directory and opened in the default PDF application.

## Creep compensation

Creep compensation is disabled by default. Enable it by providing the thickness of a normal sheet in millimetres:

```sh
'/Library/Application Support/Create Booklet/booklet' input.pdf --sheet-thickness 0.10
```

For a separate heavier cover, provide both thicknesses:

```sh
'/Library/Application Support/Create Booklet/booklet' input.pdf \
    --sheet-thickness 0.10 \
    --cover-thickness 0.22
```

Accepted thicknesses range from 0.02 to 1.00 mm.

## Build and audit

The Swift source, Automator workflows, installer resources, and repository-relative build scripts are all included. A local unsigned build does not require Apple Developer credentials:

```sh
./scripts/build-local.sh
./scripts/build-installer-local.sh
```

See [BUILDING.md](BUILDING.md) for complete compilation, local installation, packaging, signing, notarization, and verification instructions.

Create Booklet targets macOS 11 or newer. Building requires Xcode and its macOS SDK.

## Samples

The `Release` directory contains an eight-page sample PDF and the expected imposed output:

- [`Release/8pages.pdf`](Release/8pages.pdf)
- [`Release/Booklet-8pages.pdf`](Release/Booklet-8pages.pdf)

## License

Create Booklet is free software licensed under the [GNU General Public License, version 3](LICENSE).
