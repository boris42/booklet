# booklet
PDF booklet tool for macOS
==========================

Simple command line tool written in Swift that takes a multi-page PDF file as its only argument then creates a PDF booklet, ready to print to a double-sided printer.

Display the installed program version with `booklet --version` (or `booklet -v`).

Creep compensation is disabled by default. Enable it with `--sheet-thickness <mm>`; optionally add `--cover-thickness <mm>` for a separate heavier cover. Accepted thicknesses range from 0.02 to 1.00 mm.

The `Release/CreateBooklet.zip` archive contains a signed and notarized installer package. The installer adds two macOS services named **Create Booklet** and a shared command-line helper:

1. **Finder Quick Action** — installed at `/Library/Services/Create Booklet.workflow` and available from Finder Services / Quick Actions for PDF files.
2. **Print Dialog PDF Service** — installed at `/Library/PDF Services/Create Booklet.workflow` and available from the PDF menu in the macOS Print dialog.
3. **Shared command-line helper** — installed at `/Library/Application Support/Create Booklet/booklet` and used by both workflows to create an imposed booklet PDF from the selected or printed PDF file.

The `Release` folder also contains a sample multipage PDF document and the expected output produced by the tool.

In order to use the Swift command line utilities on older macOS operating systems you need to download from Apple and install the Swift 5 Runtime Support for Command Line Tools from Apple at https://support.apple.com/kb/DL1998
