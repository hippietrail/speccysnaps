//
//  main.swift
//  speccysnaps
//
//  Created by Andrew Dunbar on 21/8/2022.
//

import Foundation
import AppKit

let fileManager = FileManager.default

let resKeys : [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]

let homeUrl: URL = fileManager.homeDirectoryForCurrentUser
//let cwdURL: URL = URL(string: fileManager.currentDirectoryPath)!

let downloadsURL = try fileManager.url(for: .downloadsDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false)

let pathURLs = CommandLine.arguments.count == 1 ? [homeUrl]
                    : CommandLine.arguments.dropFirst().compactMap {
                        URL(string:$0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") }

for url in pathURLs {
    print("********", url.path, "********")

    let en = fileManager.enumerator(at: url,
                                    includingPropertiesForKeys: resKeys,
                                    options: [.skipsHiddenFiles,
                                              .producesRelativePathURLs],
                                    errorHandler: { (url, error) -> Bool in

        print("** error 1: \(url): ", error)

        return true
    })!

    for case let fileURL as URL in en {
        do {
            let rv = try fileURL.resourceValues(forKeys: Set(resKeys))

            let ext = fileURL.pathExtension.lowercased()

            if !rv.isDirectory! && ["sna", "z80", "zip"].contains(ext) {
                let size = rv.fileSize ?? -1
                print(fileURL.relativePath, size)

                if ext == "z80" {
                    if size > 0 && size < 256 * 1024 {
                        //let foo:Int=fileURL
                        let data = try Data(contentsOf: fileURL)

                        if data[6] | data[7] == 0 {
                            let v23len = UInt16(data[30]) + UInt16(data[31])

                            var v = -1
                            if v23len == 23 {
                                v = 2
                                print("  version 2")
                            } else if v23len == 54 {
                                v = 3
                                print("  version 3 short")
                            } else if v23len == 55 {
                                v = 3
                                print("  version 3 long")
                            } else {
                                print("  version 3+ \(v23len) ??")
                            }

                            let hw = data[34], mod = data[37] & 1 << 7
                            print("    hardware mode \(hw), modified? \(mod)")
                            var hws = "???"
                            if hw == 0 && mod == 0 {
                                hws = "48k"
                            } else if hw == 1 && mod == 0 {
                                hws = "48k + Interface 1"
                            } else if (hw == 3 && v == 2) || (hw == 4 && v == 3) {
                                hws = "128k"
                            } else if hw == 3 && v == 3 {
                                hws = "48k + MGT"
                            }
                            print("      \(hws)")
                        } else {
                            //print("  version 1")
                            if data[12] & (1 << 5) > 0 {
                                print("  version 1 compressed")
                            } else {
                                print("  version 1 not compressed")
                            }
                        }
                    }
                }

            }
        } catch {
            print("** error 2:", error)
        }
    }
}

// from emulator
//var provider: CGDataProvider!
var bmpData = [UInt32](repeating: 0, count: 32 * 8 * 192)
    print("bmp data", bmpData)
let provider = CGDataProvider(dataInfo: nil,
                              data: bmpData,
                              size: 192 * 1024,
                              releaseData: { _, _, _ in
})!
    print("provider", provider)
let colourSpace = CGColorSpaceCreateDeviceRGB()
    print("colour space", colourSpace)
let bitmapInfo  = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue).union(CGBitmapInfo())
    print("bitmap info", bitmapInfo)
if let cgimg = CGImage(width: 256,
                       height: 192,
                       bitsPerComponent: 8,
                       bitsPerPixel: 32,
                       bytesPerRow: 1024,
                       space: colourSpace,
                       bitmapInfo: bitmapInfo,
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent) {
    print(cgimg)
    let image = NSImage(cgImage: cgimg, size: .zero)
    // end from emulator

    //let image = NSImage(size: NSSize(width: 256, height: 192))
    image.backgroundColor = NSColor.systemRed
        print("image", image)
        print("isValid", image.isValid)
    let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)
        print("rep", imageRep)
        print("hasAlpha", imageRep?.hasAlpha)
        print("bitmap data", imageRep?.bitmapData)

    print("setting colour...")
    imageRep?.setColor(NSColor.blue, atX: 128, y: 96)
    print("setting another colour...")
    imageRep?.setColor(NSColor.green, atX: 0, y: 0)
    print("done setting colours")

    let pngData = imageRep?.representation(using: .png, properties: [:])
    print("png", pngData)
    do {
        print("about to write...")
        try pngData!.write(to: URL(fileURLWithPath: "hippietrail-image.png"))
        print("I guess I wrote it?")

    } catch {
        print("caught", error)
    }
}
