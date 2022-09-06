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

let pathURLs = CommandLine.arguments.count == 1
    ? [homeUrl]
    : CommandLine.arguments.dropFirst().compactMap {
        URL(string: $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
    }

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

            if !rv.isDirectory! && [
                //"air",  // ???
                //"azx",  // ???
                //"blk",  // tape
                //"col",    // cartridge?
                //"csw",  // tape
                "dck",  // cartridge (Timex)
                //"dsk",  // disk
                //"fdi",  // disk
                //"hobeta",   // disk
                //"hdf",  // disk
                //"img",  // disk
                //"itm",  // tape
                //"ltp",  // tape
                //"mdr",  // microdrive
                //"mgt",  // disk
                //"net",  // ???
                //"nex",  // snapshot?
                //"o",    // snapshot?
                //"p",    // snapshot?
                //"pal",  // ???
                "pok",    // poke
                //"pzx",  // tape
                "rom",    // cartridge (Interface 2)
                //"rzx",
                //"scl",  // disk
                "scr",  // screen
                //"sg",    // cartridge?
                //"slt",  // snapshot
                "sna",  // snapshot
                //"snp",  // snapshot
                //"sp",   // snapshot?
                //"spc",  // tape
                //"spg",  // snapshot?
                //"sta",  // tape
                //"szx",  // snapshot
                "tap",  // tape (used for 2 formats, one common and one rare [aka "blk"])
                //"trd",  // disk
                "tzx",  // tape
                //"udi",  // ???
                //"zx",     // snapshot?
                //"zx82",   // snapshot?
                //"zxs",  // snapshot
                "z80",  // snapshot
                //"zip",  // archive
                //"zsf",    // snapshot?
                //"zxs",  // snapshot
                ].contains(ext)
            {
                let size = rv.fileSize ?? -1
                print(fileURL.relativePath)

                if ext == "dck" {
                    print("  DCK Timex/Sinclair cartridge image. length \(size) \(String(format: "x%x", size)))")
                    if (size - 9) % 1024 == 0 {
                        let bankCount1 = (size - 9)/(8 * 1024)
                        print("    size seems valid for a \((size - 9)/1024) kb dock cartridge = \(bankCount1) banks")
                        let data = try Data(contentsOf: fileURL)
                        let dockID = data.first
                        print("    dock ID \(dockID!)")
                        let bankValues = ["absent", "blank RAM", "ROM", "set RAM"]
                        var romBankCount = 0
                        for i in 1...8 {
                            let val = Int(data[i])
                            if val >= 0 && val <= 3 {
                                print("      \(i) \(bankValues[val])")
                                if val == 2 { romBankCount += 1 }
                            } else {
                                print("      \(i) \(val)")
                            }
                        }
                        if bankCount1 == romBankCount {
                            print("      number of ROM banks matches")
                        } else {
                            print("      number of ROM doesn't match")
                        }
                    } else {
                        print("    * doesn't seem to ve a valid size")
                    }
                }
                else if ext == "pok" {
                    print("  TODO \(size) bytes")
                }
                else if ext == "rom" {
                    if size == 16 * 1024 {
                        print("  ROM Interface 2 cartridge image")
                    } else {
                        print("  * not a valid ROM Interface 2 cartridge")
                    }
                }
                else if ext == "scr" {
                    if size == 192 * 32 + 24 * 32 {
                        print("  SCR screen")
                    } else {
                        print("  * not a valid SCR screen")
                    }
                }
                else if ext == "sna" {
                    if size == 27 + 48 * 1024 {             // 49179
                        print("  SNA 48k")
                    } else if size == 27 + 8 * 16384 {      // 131103
                        print("  SNA 128k (short)")
                    } else if size == 27 + 9 * 16384 {      // 147487
                        print("  SNA 128k (long)")
                    } else if size == 27 + 16384 {
                        print("  SNA 16k (hypothetical)")   // 16411. only one page mentions that these exist but are rare
                    } else {
                        print("  * not a valid SNA snapshot")
                    }
                }
                else if ext == "tap" {
                    print("  TAP tape image? (\(size) bytes \(String(format: "%x", size)))")
                    if size > 0 && size < 256 * 1024 {
                        let data = try Data(contentsOf: fileURL)
                        
                        var o = 0
                        while true {
                            //print("o is now \(o) \(String(format:"%x", o))")
                            if o == data.count { break }
                            if o > data.count { print("* overrun"); break }
                            
                            let blockLen = Int(data[o]) + 256 * Int(data[o+1]) ; o += 2
                            //print("    block len", blockLen, String(format: "0x%x", blockLen))
                            if blockLen == 0 { print("* zero block len"); break }

                            let block = data [ o ..< o + blockLen ]
                            let flag = block.first, checksum = block.last
                            
                            if let flag = flag, let checksum = checksum {
                                
                                if flag == 0x00 {
                                    let header = block[o + 1 ..< o + blockLen - 1]
                                    
                                    print("    header block. \(header.count) bytes. checksum \(checksum)")
                                    
                                    if let type = header.first {
                                        let name = header[o + 2 ..< o + 2 + 10]
                                        let dataBlockLen = UInt16(header[o + 2 + 10]) + 256 * UInt16(header[o + 2 + 11])
                                        let param1 = UInt16(header[o + 2 + 12]) + 256 * UInt16(header[o + 2 + 13])
                                        let param2 = UInt16(header[o + 2 + 14]) + 256 * UInt16(header[o + 2 + 15])

                                        print("      name \"\(String(decoding: name, as: UTF8.self))\"")
                                        print("      data block len: \(dataBlockLen) \(String(format: "x%04x", dataBlockLen))")
                                        if type <= 3 {
                                            print("      type: \(["program", "number array", "char array", "code"][Int(type)])")
                                            if type == 0 {
                                                print("      autostart line number: \(param1) \(String(format: "x%04x", param1))")
                                                print("      BASIC variable area offset: \(param2) \(String(format: "x%04x", param2))")
                                            } else if type == 3 {
                                                print("      code address: \(param1) \(String(format: "x%04x", param1))")
                                                print("      param2: \(param2) \(String(format: "x%04x", param2))")
                                            } else {
                                                print("      param1: \(param1) \(String(format: "x%04x", param1))")
                                                print("      param2: \(param2) \(String(format: "x%04x", param2))")
                                            }
                                        } else {
                                            print("      unknown type \(type)")
                                            print("      param1: \(param1) \(String(format: "x%04x", param1))")
                                            print("      param2: \(param2) \(String(format: "x%04x", param2))")
                                        }
                                    } else {
                                        print("* couldn't unwrap type")
                                        break
                                    }
                                } else if flag == 0xff {
                                    print("    data block. \(blockLen) bytes. checksum \(checksum)")
                                } else {
                                    print("    unknown block. \(blockLen) bytes. checksum \(checksum)")
                                }
                                
                            } else {
                                print("* couldn't unwrap flag or checksum")
                                break
                            }
                            o += blockLen
                        }

                    } else {
                        print("    * size bigger than 256k, not analysing")
                    }
                }
                else if ext == "tzx" {
                    if size > 0 && size < 256 * 1024 {
                        let data = try Data(contentsOf: fileURL)
                        let signature = String(decoding: data[0 ..< 8], as: UTF8.self)
                        
                        if signature == "ZXTape!\u{1A}" {
                            let verMaj = data[8], verMin = data[9]
                            print("  TZX tape image. version \(verMaj).\(verMin). (\(size) bytes \(String(format: "x%x", size)))")
                            
                            var o = 10
                            var gotToEnd = false
                            
                            loop: while o < size {
                                //print(String(format: "x%02x", o))
                                let blockID = data[o], hex = String(format: "x%02x", blockID)
                                
                                switch blockID {
                                case 0x10:
                                    print("    \(hex): standard speed block")
                                    //let pause = UInt16(data[o+1]) + 256 * UInt16(data[o+2])
                                    let len = UInt16(data[o+3]) + 256 * UInt16(data[o+4])
                                    //print("      pause \(pause), length \(len)")
                                    o += 1 + 4 + Int(len)
                                case 0x11:
                                    print("    \(hex): turbo speed data block")
                                    let len = Int(data[o+16]) + 256 * Int(data[o+17]) + 65536 * Int(data[o+18])
                                    //print("      len \(len) \(String(format: "x%06x", len))")
                                    o += 1 + len + 18
                                case 0x12:
                                    print("    \(hex): pure tone")
                                    o += 1 + 4
                                case 0x13:
                                    print("    \(hex): pulse sequence")
                                    let len = Int(data[o + 1])
                                    //print("      \(len) \(String(format: "x%02x", len)) pulses")
                                    o += 1 + 1 + len * 2
                                case 0x14:
                                    print("    \(hex): pure data block")
                                    let len = Int(data[o+8]) + 256 * Int(data[o+9]) + 65536 * Int(data[o+10])
                                    //print("      len \(len) \(String(format: "x%06x", len))")
                                    o += 1 + len + 10
                                //   0x15              direct recording block
                                //
                                //   0x18              CSW recording block
                                //   0x19              generalized data block
                                //   0x20              pause (silence) or "stop the tape" command
                                case 0x21:
                                    print("    \(hex): group start")
                                    let len = Int(data[o + 1])
                                    print("      \(String(decoding: data[o + 2 ..< o + 2 + len], as: UTF8.self))")
                                    o += 1 + 1 + len
                                case 0x22:
                                    print("    \(hex): group end")
                                    o += 1
                                case 0x23:
                                    print("    \(hex): jump to block")
                                    o += 1 + 2
                                //   0x24              loop start
                                //   0x25              loop end
                                //   0x26              call sequence
                                //   0x27              return from sequence
                                //   0x28              select block
                                //
                                //   0x2a              stop the tape if in 48k mode
                                //   0x2b              set signal level
                                //
                                case 0x30:
                                    print("    \(hex): text description")
                                    let len = Int(data[o + 1])
                                    print("      \(String(decoding: data[o + 2 ..< o + 2 + len], as: UTF8.self))")
                                    o += 1 + 1 + len
                                //   0x31              message block
                                case 0x32:
                                    print("    \(hex): archive info")
                                    let len = UInt16(data[o+1]) + 256 * UInt16(data[o+2])
                                    //print("      length \(len) \(String(format: "x%02x", len))")
                                    let num = data[o+3]
                                    print("      \(num) strings")
                                    
                                    let descs = ["Full title", "Software house/publisher", "Author(s)", "Year of publication", "Language", "Game/utility type", "Price", "Protection scheme/loader", "Origin"]
                                    
                                    var to = o+4
                                    for i in 0..<num {
                                        let tid = data[to]
                                        let tlen = data[to+1]
                                        
                                        let desc = tid < descs.count ? descs[Int(tid)] : tid == 0xff ? "Comment(s)" : ""

                                        let tstr = String(decoding: data[to + 2 ..< to + 2 + Int(tlen)], as: UTF8.self)

                                        if (desc.isEmpty) {
                                            print("       \(i): id \(tid) \"\(tstr)\"")
                                        } else {
                                            print("       \(i): \"\(desc)\" \"\(tstr)\"")
                                        }
                                        
                                        to += 2 + Int(tlen)
                                    }
                                    
                                    o += 1 + 2 + Int(len)
                                case 0x33:
                                    print("    \(hex): hardware type")
                                    let len = Int(data[o + 1])
                                    
                                    //print("      \(len) entries")
                                    
                                    let typestrings = ["Computers"]
                                    let idstrings = ["ZX Spectrum 16k", "ZX Spectrum 48k, Plus", "ZX Spectrum 48k ISSUE 1", "ZX Spectrum 128k +(Sinclair)", "ZX Spectrum 128k +2 (grey case)", "ZX Spectrum 128k +2A, +3", "Timex Sinclair TC-2048", "Timex Sinclair TS-2068"]
                                    let infostrings = ["runs but may or may not use speial hardware", "uses the special hardware", "runs but doesn't use the special hardware", "doesn't run"]
                                                                        
                                    var hwo = o + 1 + 1
                                    for i in 0 ..< len {
                                        let type = data[hwo + i*3]
                                        let id = data[hwo + i*3 + 1]
                                        let info = data[hwo + i*3 + 2]
                                        
                                        let typestr = type < typestrings.count ? typestrings[Int(type)] : "\(type) \(String(format: "x%x", type))"
                                        let idstr = id < idstrings.count ? idstrings[Int(id)] : "\(id) \(String(format: "x%x", id))"
                                        let infostr = info < infostrings.count ? infostrings[Int(info)] : "\(info) \(String(format: "x%x", info))"
                                        
                                        print("      \(i) type: \(typestr), id: \(idstr), info: \(infostr)")
                                    }
                                    
                                    
                                    
                                    
                                    o += 1 + len * 3 + 1

                                //
                                //   0x35              custom info block
                                //   0x5a              "glue" block (90 dec, ascii "z")
                                default:
                                    print("    \(hex): ** unknown block")
                                    break loop
                                }
                                if o >= size {
                                    //print("    end of file")
                                    gotToEnd = true
                                }
                            }
                            if !gotToEnd {
                                print("    ** didn't make it to the end")
                            }
                            
                        } else {
                            print("  * not a TZX tape image")
                        }
                    } else {
                        print("  * file too long, not analyzing")
                    }
                }
                else if ext == "z80" {
                    if size > 0 && size < 256 * 1024 {
                        let data = try Data(contentsOf: fileURL)

                        if data[6] | data[7] == 0 {
                            let v23len = UInt16(data[30]) + 256 * UInt16(data[31])

                            var v: UInt8? = nil
                            if v23len == 23 {
                                v = 2
                                print("  Z80 snapshot, version 2")
                            } else if v23len == 54 {
                                v = 3
                                print("  Z80 snapshot, version 3 short")
                            } else if v23len == 55 {
                                v = 3
                                print("  Z80 snapshot, version 3 long")
                            } else {
                                print("  Z80 snapshot, version 3+ \(v23len) ??")
                            }

                            let hw = data[34], mod = data[37] & 1 << 7
                            print("    hardware mode \(hw), modified? \(mod)")
                            var hws: String? = nil
                            if hw == 0 && mod == 0 {
                                hws = "48k"
                            } else if hw == 1 && mod == 0 {
                                hws = "48k + Interface 1"
                            } else if (hw == 3 && v == 2) || (hw == 4 && v == 3) {
                                hws = "128k"
                            } else if hw == 3 && v == 3 {
                                hws = "48k + MGT"
                            } else if (hw == 4 && v == 2) || (hw == 5 && v == 3) {
                                hws = "128k + Interface 1"
                            }
                            print("      \(hws ?? "???")")
                        } else {
                            if data[12] & (1 << 5) > 0 {
                                print("  Z80 snapshot, version 1 compressed")
                            } else {
                                print("  Z80 snapshot, version 1 not compressed")
                                if size == 30 + 48 * 1024 {
                                    print("    valid length")
                                } else {
                                    print("    * invalid length")
                                }
                            }
                        }
                    } else {
                        print("  * size bigger than 256k, not analysing")
                    }
                }
                else {
                    print("  \(size) bytes")
                }

            }
        } catch {
            print("** error 2:", error)
        }
    }
}

exit(0)

// below here is nonworking code attempting to create png thumbnail files

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
