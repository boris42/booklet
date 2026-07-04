//
//  main.swift
//  booklet
//
//  Created by Boris Herman on 15/10/2019.
//  Copyright © 2026 Sight&Sound s.p. All rights reserved.
//

import Foundation
import AppKit
import PDFKit

let programVersion = "2.0.0"

// MARK: - Creep

struct CreepSettings {
    // Thickness of each normal inner physical sheet, in millimetres.
    var sheetThicknessMM: CGFloat = 0.0

    // Thickness of the outer cover physical sheet, in millimetres.
    //
    // 0 means: no separate/heavier cover; use uniform-paper formula.
    var coverThicknessMM: CGFloat = 0.0

    var hasSeparateCover: Bool {
        coverThicknessMM > 0
    }

    var isActive: Bool {
        sheetThicknessMM > 0
    }

    // Returns creep compensation in millimetres for a physical folded sheet.
    //
    // sheetIndex 0 = outermost sheet
    // sheetIndex 1 = next sheet inward
    // sheetIndex 2 = next sheet inward
    //
    // Uniform paper:
    //
    //     sheet 0: 0
    //     sheet 1: 1 * sheetThickness
    //     sheet 2: 2 * sheetThickness
    //
    // Separate heavier cover:
    //
    //     sheet 0, cover:       0
    //     sheet 1, first inner: coverThickness
    //     sheet 2:              coverThickness + 1 * sheetThickness
    //     sheet 3:              coverThickness + 2 * sheetThickness
    //
    func creepMM(forPhysicalSheet sheetIndex: Int) -> CGFloat {
        guard isActive else { return 0 }
        guard sheetIndex > 0 else { return 0 }

        let inner = max(sheetThicknessMM, 0)
        let cover = max(coverThicknessMM, 0)

        if cover > 0 {
            return cover + CGFloat(sheetIndex - 1) * inner
        } else {
            return CGFloat(sheetIndex) * inner
        }
    }
}

let pointsPerMM: CGFloat = 72.0 / 25.4
let validThicknessRangeMM = 0.02...1.0

func mmToPoints(_ mm: CGFloat) -> CGFloat {
    mm * pointsPerMM
}

// MARK: - Command line parsing

struct Options {
    var inputPath: String?
    var creep = CreepSettings()
}

func usageAndExit() -> Never {
    print("""
    Usage:
      booklet <inputfile> [options]

    Options:
      -v, --version
          Display the program version.

      -s, --sheet-thickness <mm>
          Enable creep compensation using the thickness of a normal
          inner paper sheet in millimetres.
          Valid range: 0.02–1.00 mm.
          Example: --sheet-thickness 0.10

      -c, --cover-thickness <mm>
          Optional thickness of a separate/heavier cover sheet in millimetres.
          Requires --sheet-thickness.
          Valid range: 0.02–1.00 mm.
          Example: --cover-thickness 0.22

    Examples:
      booklet input.pdf --sheet-thickness 0.10
      booklet input.pdf --sheet-thickness 0.10 --cover-thickness 0.22
      booklet input.pdf

    Note:
      Measure paper thickness with a stack:
        100 inner sheets = 10 mm  ->  sheet thickness = 0.10 mm
        10 cover sheets  = 2.2 mm ->  cover thickness = 0.22 mm
    """)
    exit(1)
}

func parseThickness(_ string: String) -> CGFloat? {
    let normalized = string.replacingOccurrences(of: ",", with: ".")
    guard let value = Double(normalized), validThicknessRangeMM.contains(value) else {
        return nil
    }
    return CGFloat(value)
}

func parseOptions() -> Options {
    var options = Options()
    var argIndex = 1

    while argIndex < CommandLine.arguments.count {
        let arg = CommandLine.arguments[argIndex]

        switch arg {
        case "--help", "-h":
            usageAndExit()

        case "--version", "-v":
            print("booklet \(programVersion)")
            exit(0)

        case "--sheet-thickness", "-s":
            guard argIndex + 1 < CommandLine.arguments.count,
                  let value = parseThickness(CommandLine.arguments[argIndex + 1]) else {
                print("--sheet-thickness must be between 0.02 and 1.00 mm.\n")
                usageAndExit()
            }
            options.creep.sheetThicknessMM = value
            argIndex += 2

        case "--cover-thickness", "-c":
            guard argIndex + 1 < CommandLine.arguments.count,
                  let value = parseThickness(CommandLine.arguments[argIndex + 1]) else {
                print("--cover-thickness must be between 0.02 and 1.00 mm.\n")
                usageAndExit()
            }
            options.creep.coverThicknessMM = value
            argIndex += 2

        default:
            if options.inputPath == nil {
                options.inputPath = arg
                argIndex += 1
            } else {
                usageAndExit()
            }
        }
    }

    guard !options.creep.hasSeparateCover || options.creep.isActive else {
        print("--cover-thickness requires --sheet-thickness.\n")
        usageAndExit()
    }

    return options
}

// MARK: - PDF drawing

func drawPage(_ pdfPage: PDFPage, in ctx: CGContext, offsetX: CGFloat, clipRect: CGRect) {
    guard let pageRef = pdfPage.pageRef else { return }

    ctx.saveGState()
    ctx.clip(to: clipRect)
    ctx.translateBy(x: offsetX, y: 0)
    ctx.drawPDFPage(pageRef)
    ctx.restoreGState()
}

// MARK: - Main

let options = parseOptions()

guard let inputPath = options.inputPath else {
    usageAndExit()
}

let srcUrl = URL(fileURLWithPath: inputPath)

guard let srcDoc = PDFDocument(url: srcUrl) else {
    print("Source file \(inputPath) cannot be opened, exiting")
    exit(1)
}

guard let firstPage = srcDoc.page(at: 0) else {
    print("Source file \(inputPath) has no pages, exiting")
    exit(1)
}

let sourcePageCount = srcDoc.pageCount

// Pad source page count up to a multiple of 4.
// Example:
//   1 page  -> 4
//   5 pages -> 8
//   20 pages -> 20
let paddedPageCount = ((sourcePageCount + 3) / 4) * 4
let paddedLastPageIndex = paddedPageCount - 1

// Imposition order.
// Each group of four source-page indexes represents one physical folded sheet:
//
//   [front-left, front-right, back-left, back-right]
//
// Missing indexes beyond sourcePageCount become blanks later.
var pageOrder: [Int] = []

for i in 0..<(paddedPageCount / 4) {
    pageOrder.append(paddedLastPageIndex - i * 2)
    pageOrder.append(i * 2)
    pageOrder.append(i * 2 + 1)
    pageOrder.append(paddedLastPageIndex - 1 - i * 2)
}

let sheetCount = pageOrder.count / 4

let outputSuffix = options.creep.isActive ? "-creep" : ""
let outFile = FileManager.default.temporaryDirectory
    .appendingPathComponent("Booklet-\(srcUrl.deletingPathExtension().lastPathComponent)\(outputSuffix).pdf")

let firstBounds = firstPage.bounds(for: .mediaBox)

var initialBox = CGRect(
    x: 0,
    y: 0,
    width: firstBounds.width * 2,
    height: firstBounds.height
)

let infoDict = ["kCGPDFContextCreator": "booklet"] as CFDictionary

guard let ctx = CGContext(outFile as CFURL, mediaBox: &initialBox, infoDict) else {
    print("Destination file \(outFile.path) cannot be created, exiting")
    exit(1)
}

// page is 0, 2, 4, 6...
// Every two imposed PDF pages are one physical folded sheet:
//   imposed page 0 = sheet 0 front left
//   imposed page 1 = sheet 0 back right
//   imposed page 2 = sheet 1 front left
//   imposed page 3 = sheet 1 back right
//
// Since this loop steps by 2, page / 4 gives physical sheet index:
//
//   page = 0 -> sheet 0 front
//   page = 2 -> sheet 0 back
//   page = 4 -> sheet 1 front
//   page = 6 -> sheet 1 back

for page in stride(from: 0, to: pageOrder.count, by: 2) {
    var page1 = PDFPage()
    var page2 = PDFPage()
    var pg1bounds = firstBounds
    var pg2bounds = firstBounds

    let sourceIndex1 = pageOrder[page]
    let sourceIndex2 = pageOrder[page + 1]

    if sourceIndex1 < sourcePageCount, let pg1 = srcDoc.page(at: sourceIndex1) {
        page1 = pg1
        pg1bounds = pg1.bounds(for: .mediaBox)
    }

    if sourceIndex2 < sourcePageCount, let pg2 = srcDoc.page(at: sourceIndex2) {
        page2 = pg2
        pg2bounds = pg2.bounds(for: .mediaBox)
    }

    var pageBox = pg1bounds
        .union(pg2bounds)
        .applying(CGAffineTransform(scaleX: 2, y: 1))

    let pageWidth = pageBox.width / 2.0

    let physicalSheetIndex = page / 4
    let creepMM = options.creep.creepMM(forPhysicalSheet: physicalSheetIndex)
    let creepPoints = mmToPoints(creepMM)

    ctx.beginPage(mediaBox: &pageBox)

    // Left logical A4 page:
    // spine/fold is on the right side of the left page,
    // so move content right, toward the fold.
    drawPage(
        page1,
        in: ctx,
        offsetX: creepPoints,
        clipRect: CGRect(
            x: 0,
            y: 0,
            width: pageWidth,
            height: pageBox.height
        )
    )

    // Right logical A4 page:
    // spine/fold is on the left side of the right page,
    // so move content left, toward the fold.
    //
    // Normally the right page is shifted by pageWidth.
    // Creep subtracts from that shift.
    drawPage(
        page2,
        in: ctx,
        offsetX: pageWidth - creepPoints,
        clipRect: CGRect(
            x: pageWidth,
            y: 0,
            width: pageWidth,
            height: pageBox.height
        )
    )

    ctx.endPage()
}

ctx.closePDF()

let maxAppliedCreepMM = (0..<sheetCount)
    .map { options.creep.creepMM(forPhysicalSheet: $0) }
    .max() ?? 0

print("Created: \(outFile.path)")
print("Source pages: \(sourcePageCount)")
print("Padded pages: \(paddedPageCount)")
print("Sheets: \(sheetCount)")

if options.creep.isActive {
    print("Sheet thickness: \(options.creep.sheetThicknessMM) mm")

    if options.creep.hasSeparateCover {
        print("Cover thickness: \(options.creep.coverThicknessMM) mm")
    } else {
        print("Cover thickness: none / same paper")
    }

    print("Max applied creep: \(maxAppliedCreepMM) mm")
} else {
    print("Creep: disabled (no sheet thickness supplied)")
}

if !NSWorkspace.shared.open(outFile) {
    print("Destination file \(outFile.path) cannot be opened")
}
