//
//  main.swift
//  speccysnaps
//
//  Created by Andrew Dunbar on 21/8/2022.
//

import Foundation
import AppKit

// from https://forums.swift.org/t/how-to-read-uint32-from-a-data/59431/11
// which had big-endian default which wasn't mentioned for some reason
extension Data {
    
    subscript<T: BinaryInteger>(at offset: Int, bigEndian bigEndian: Bool = false) -> T? {
        value(ofType: T.self, at: offset, bigEndian: bigEndian)
    }
    
    func value<T: BinaryInteger>(ofType: T.Type, at offset: Int, bigEndian: Bool = false) -> T? {
        let right = offset &+ MemoryLayout<T>.size
        guard offset >= 0 && right > offset && right <= count else {
            return nil
        }
        let bytes = self[offset ..< right]
        if bigEndian {
            return bytes.reduce(0) { T($0) << 8 + T($1) }
        } else {
            return bytes.reversed().reduce(0) { T($0) << 8 + T($1) }
        }
    }
    
    // Examples:
    // let value: UInt32 = data[at: 123]!
    // let value: Int16 = data[at: 123, convertEndian: true]!
}

let fileManager = FileManager.default

let resKeys : [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey]

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
                                    errorHandler: { (url, error) -> Bool in /*print("** error 1: \(url): ", error); */ return true }
                                    )!
    
    enum FiletypeCategory {
        case archive
        case audio
        case cartridge
        case diskImage
        case microdriveImage
        case poke
        case screen
        case snapshot
        case tapeImage
        case unknnown
    }
    
    struct FiletypeInfo {
        var ext: String
        var cat: FiletypeCategory
    }
        
    let fileExtensionInfo: [FiletypeInfo] = [
        //FiletypeInfo(ext:"air",   // input events?
        //FiletypeInfo(ext:"azx",   // music/sound? - https://worldofspectrum.net/assets/AZXformat.txt
        //FiletypeInfo(ext:"blk",   // tape
        //FiletypeInfo(ext:"col",   // cartridge?
        FiletypeInfo(ext:"csw",     cat: .audio),       // "Compressed Square Wave"
        //FiletypeInfo(ext:"dat",     // ???
        FiletypeInfo(ext:"dck",     cat: .cartridge),   // Timex
        FiletypeInfo(ext:"dsk",     cat: .diskImage),
        //FiletypeInfo(ext:"fdi",   //FiletypeInfo(ext: disk
        FiletypeInfo(ext:"hobeta",  cat: .diskImage),   // Eastern Bloc clones
        //FiletypeInfo(ext:"hdf",   // hard disk
        //FiletypeInfo(ext:"img",   // disk
        //FiletypeInfo(ext:"ipf",   cat: .diskImage),   // used more for Amiga emulators but also Speccy +3
        //FiletypeInfo(ext:"itm",   // tape
        //FiletypeInfo(ext:"ltp",   // tape - http://kassiopeia.juls.savba.sk/~garabik/old/readme.txt
        FiletypeInfo(ext:"mdr",     cat: .microdriveImage),
        FiletypeInfo(ext:"mgt",     cat: .diskImage),
        //FiletypeInfo(ext:"net",   // ???
        //FiletypeInfo(ext:"nex",   // snapshot?
        //FiletypeInfo(ext:"o",     // snapshot?
        //FiletypeInfo(ext:"p",     // snapshot?
        //FiletypeInfo(ext:"pal",   // palette???
        FiletypeInfo(ext:"pok",     cat: .poke),
        //FiletypeInfo(ext:"prg",     cat: .snapshot),
        //FiletypeInfo(ext:"psg",     // ???
        //FiletypeInfo(ext:"pzx",   // tape
        //FiletypeInfo(ext:"raw",     // memory dump
        FiletypeInfo(ext:"rom",     cat: .cartridge),   // Interface 2
        //FiletypeInfo(ext:"rzx",   // input events!
        //FiletypeInfo(ext:"scl",   // disk
        FiletypeInfo(ext:"scr",     cat: .screen),
        //FiletypeInfo(ext:"sem",   // snapshot
        //FiletypeInfo(ext:"sg",    // cartridge?
        //FiletypeInfo(ext:"sit",   cat: .snapshot),
        FiletypeInfo(ext:"slt",     cat: .snapshot),    // super level loader
        FiletypeInfo(ext:"sna",     cat: .snapshot),
        //FiletypeInfo(ext:"snp",   // snapshot
        //FiletypeInfo(ext:"snx",     cat: .snapshot),
        //FiletypeInfo(ext:"sp",    // snapshot
        //FiletypeInfo(ext:"spc",   // tape
        //FiletypeInfo(ext:"spg",   // snapshot?
        //FiletypeInfo(ext:"sta",   // tape
        //FiletypeInfo(ext:"szx",   // snapshot
        FiletypeInfo(ext:"tap",     cat: .tapeImage),        // (used for 2 formats, one common and one rare [aka "blk"])
        FiletypeInfo(ext:"trd",     cat: .diskImage),
        FiletypeInfo(ext:"tzx",     cat: .tapeImage),
        //FiletypeInfo(ext:"udi",   // ???
        FiletypeInfo(ext:"voc",     cat: .audio),
        //FileTypeInfo(ext:"wav",     cat: .audio),         // used by MAME
        FiletypeInfo(ext:"z80",     cat: .snapshot),
        FiletypeInfo(ext:"zip",     cat: .archive),
        //FiletypeInfo(ext:"zsf",   // snapshot?
        //FiletypeInfo(ext:"zx",      cat: .snapshot),
        //FiletypeInfo(ext:"zx82",    cat: .snapshot),
        //FiletypeInfo(ext:"zxs",     cat: .snapshot),
    ]
    
    let speccyFileExtensions = fileExtensionInfo
        .filter { $0.cat != .archive }
        // TODO is .csw intended for arbitrary audiotape platforms? would this make it non speccy?
        .map { $0.ext }
    
    let snapshotFileExtensions = fileExtensionInfo
        //.filter { $0.cat == .snapshot }
        .map { $0.ext }
    
    let examineExtensions = speccyFileExtensions//["z80","tap"]

    mainloop: for case let fileURL as URL in en {
        do {
            let rv = try fileURL.resourceValues(forKeys: Set(resKeys))

            let ext = fileURL.pathExtension.lowercased()

            if !rv.isDirectory! && !rv.isSymbolicLink! && examineExtensions.contains(ext)
            {
                let size = rv.fileSize ?? -1
                print(fileURL.relativePath)

                if ext == "csw" {
                    // https://k1.spdns.de/Develop/Projects/zxsp/Info/File%20Formats/csw%20file%20format.html
                    // https://web.archive.org/web/20171024182530/http://ramsoft.bbk.org.omegahg.com/csw.html
                    guard size > 0x20 else {
                        print("  * file too short to hold CSW 1.01 header")
                        continue
                    }
                    /*guard size <= 1024 * 1024 * 2 else {
                        print("  * file too long. not analyzing")
                        continue
                    }*/
                    
                    let fh = try FileHandle(forReadingFrom: fileURL)
                    let data: Data? = try fh.read(upToCount: 0x20)
                    try fh.close()
                    
                    guard let data = data else {
                        print("  * couldn't read file header")
                        continue
                    }

                    let signature = String(decoding: data[0 ..< 22], as: UTF8.self)
                    
                    guard signature == "Compressed Square Wave" else {
                        print("  * not a CSW format file")
                        continue
                    }
                    print("  CSW Compressed Square Wave. length \(size) \(String(format: "x%x", size)))")
                    // fields common to version 1.01 and version 2.0
                    let terminatorCode: UInt8 = data[at:0x16]!
                    let majorRevisionNumber: UInt8 = data[at:0x17]!
                    let minorRevisionNumber: UInt8 = data[at:0x18]!

                    print("    version \(majorRevisionNumber).\(String(format:"%02d", minorRevisionNumber)), terminator code: \(String(format: "%02x", terminatorCode))")
                    
                    guard (majorRevisionNumber == 1 && minorRevisionNumber == 1) || (majorRevisionNumber == 2 && minorRevisionNumber == 0) else {
                        print("    * invalid version")
                        continue
                    }
                    guard majorRevisionNumber == 1 && minorRevisionNumber == 1 else {
                        print("    * only version 1.01 supported so far")
                        continue
                    }
                    // fields as used by version 1.01 only
                    let sampleRate: UInt16 = data[at:0x19]!
                    let compressionType: UInt8 = data[at:0x1b]!
                    let flags: UInt8 = data[at:0x1c]!
                    
                    let compressionTypeS = compressionType == 1 ? "RLE" : compressionType == 2 ? "Z-RLE" : String(format: "%02x", compressionType)
                    let flagsS = flags == 0 ? "initial polarity unset, the signal starts at logical low" : flags == 1 ? "initial polarity set, the signal starts at logical high" : String(format: "%02x", flags)
                    
                    print("    sample rate: \(sampleRate), compression type: \(compressionTypeS), flags: \(flagsS))")
                    guard compressionType == 1 || compressionType == 2 else {
                        print("      * invalid compression type")
                        continue
                    }
                    guard compressionType == 1 || majorRevisionNumber == 2 else {
                        print("      * Z-RLE is not a valid compression type for version 1 CSW")
                        continue
                    }
                    guard data[0x1d] | data[0x1e] | data[0x1f] == 0 else {
                        print("    * reserved bytes should all be zero")
                        continue
                    }
                    print("      looks like a valid CSW")
                }
                else if ext == "dck" {
                    print("  DCK Timex/Sinclair cartridge image. length \(size) \(String(format: "x%x", size)))")
                    if (size - 9) % 1024 == 0 {
                        let bankCount1 = (size - 9)/(8 * 1024)
                        print("    size seems valid for a \((size - 9)/1024) kb dock cartridge = \(bankCount1) banks")
                        let data = try Data(contentsOf: fileURL)
                        
                        // 0:     DOCK bank (the most frequent variant)
                        // 1-253: Reserved for expansions which allow more than three 64 Kb banks
                        // 254:   EXROM bank (using this ID you may insert RAM or ROM chunks into EXROM bank, such
                        //        hardware units exist on real Timex Sinclair)
                        // 255:   HOME bank (mainly useless, HOME content is typically stored in a Z80 file); however,
                        //        using this bank ID you may replace content of Timex HOME ROM, or turn Timex HOME ROM
                        //        into RAM
                        
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
                    let data = try Data(contentsOf: fileURL)
                    let text = String(decoding: data, as: UTF8.self)
                    // TODO verify that data was ASCII/UTF-8 text/could be decoded/is not binary data
                    //print(); print(text); print()
                    let lines = text.split(whereSeparator: \.isNewline)

                    var i = 0
                    var setnum = 0
                    outer: while true {
                        let line = lines[i]; i += 1
                        if let setfirst = line.first {
                            if setfirst == "Y" { break }
                            else if setfirst == "N" {
                                let setname = line.dropFirst().trimmingCharacters(in: .whitespaces)
                                //print("  set \(setnum): \(setname)")
                                print("  \(setname)")

                                var pokenum = 0
                                inner: while true {
                                    let line = lines[i]; i += 1
                                    if let pokfirst = line.first {
                                        if pokfirst == "M" || pokfirst == "Z" {
                                            //print("    poke \(setnum).\(pokenum): \(line.dropFirst())")

                                            let arr = line.dropFirst().split(separator: " ")
                                            if arr.count == 4 {
                                                if arr[2] == "256" {
                                                    print("    bank \(arr[0]): poke \(arr[1]), POPUP (original value: \(arr[3]))")
                                                } else {
                                                    print("    bank \(arr[0]): poke \(arr[1]), \(arr[2]) (original value: \(arr[3]))")
                                                }
                                            } else {
                                                print("    * wrong numbber of numbers in poke line")
                                            }

                                            if pokfirst == "Z" { break }
                                        } else {
                                            break outer
                                        }
                                    } else {
                                        print("* foo")
                                        break outer
                                    }
                                    pokenum += 1
                                }
                            } else {
                                print("* bar. setfirst is \(setfirst)")
                                // only 'N' and 'Y' are possible. anything else means a bug, not a POK file, or a corrupt file
                                break
                            }
                        } else {
                            print("* baz")
                            // line with no first letter, something is very wrong
                            break
                        }
                        setnum += 1
                    }
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
                        
                        var offset = 0
                        while true {
                            //print("\(String(format:"%06x:", o))")
                            
                            if offset == data.count { break }
                            if offset > data.count { print("** overrun"); break }

                            let blockLen = Int(data[offset]) + 256 * Int(data[offset+1]) ; offset += 2
                            //print("    block len", blockLen, String(format: "0x%x", blockLen))
                            
                            if blockLen == 0 {
                                // TODO some TAP files have runs of all 0 bytes after the actual structured data
                                // TODO ie TOPMAD.TAP has 0 from 6CEF to 6DFF (110h bytes, 272)
                                // TODO  NEW_ZEAL.TAP has 0 from 2B702 to 2B7FF (FDh bytes, 253)
                                print("    * zero block len")
                                break
                            }
                            guard offset + blockLen <= data.count else {
                                print("    ** not enough data for block (\(offset + blockLen) < \(data.count))")
                                break
                            }
                            
                            let block = data [ offset ..< offset + blockLen ]
                            let flag = block.first, checksum = block.last

                            if let flag = flag, let checksum = checksum {
                                
                                if flag == 0x00 {
                                    let header = block[offset + 1 ..< offset + blockLen - 1]
                                    
                                    print("    header block. \(header.count) bytes. checksum \(String(format: "x%02x", checksum)) \(checksum)")
                                    
                                    if let type = header.first {
                                        let name = header[offset + 2 ..< offset + 2 + 10]
                                        let dataBlockLen = UInt16(header[offset + 2 + 10]) + 256 * UInt16(header[offset + 2 + 11])
                                        let param1 = UInt16(header[offset + 2 + 12]) + 256 * UInt16(header[offset + 2 + 13])
                                        let param2 = UInt16(header[offset + 2 + 14]) + 256 * UInt16(header[offset + 2 + 15])

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
                                    print("    data block. \(blockLen) bytes. checksum \(String(format: "x%02x", checksum)) \(checksum)")
                                } else {
                                    print("    unknown block. \(blockLen) bytes. checksum \(String(format: "x%02x", checksum)) \(checksum)")
                                }
                                
                            } else {
                                print("* couldn't unwrap flag or checksum")
                                break
                            }
                            offset += blockLen
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
                                    print("      \"\(String(decoding: data[o + 2 ..< o + 2 + len], as: UTF8.self))\"")
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
                                            print("        \(i): id \(tid) \"\(tstr)\"")
                                        } else {
                                            let lines = tstr.split(whereSeparator: \.isNewline)
                                            if lines.count == 1 {
                                                print("        \(i): \"\(desc)\" \"\(tstr)\"")
                                            } else {
                                                print("        \(i): \"\(desc)\"")

                                                for (i, line) in lines.enumerated() {
                                                    print("          \(i) \"\(line)\"")
                                                }
                                            }
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
                                                                        
                                    let hwo = o + 1 + 1
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
                else if ext == "voc" {
                    guard size > 0x1a else {
                        print("  * file too short to hold VOC header")
                        continue
                    }
                    
                    let fh = try FileHandle(forReadingFrom: fileURL)
                    let data: Data? = try fh.read(upToCount: 0x1a)
                    try fh.close()
                    
                    guard let data = data else {
                        print("  * couldn't read file header")
                        continue
                    }

                    let signature = String(decoding: data[0 ..< 19], as: UTF8.self)
                    
                    guard signature == "Creative Voice File" else {
                        print("  * not a VOC format file")
                        continue
                    }
                    print("  VOC file. length \(size) \(String(format: "x%x", size)))")
                    
                    guard data[0x13] == 0x1a && data[0x14] == 0x1a && data[0x15] == 00 else {
                        print("    * 3 bytes from 0x13 are not the expected 0x1a 0x1a 0x00")
                        continue
                    }
                    let versionMin = data[0x16]
                    let versionMaj = data[0x17]
                    let validation: UInt16 = data[at:0x18]!
                    print("    version \(versionMaj).\(versionMin), validation \(String(format: "%04x", validation))")
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
                else if ext == "zip" {
                    let endOfCentralDirectoryRecordLength = 22
                    let endOfCentralDirectoryRecordSignature = 0x06054b50
                    let centralDirectoryFileHeaderLength = 46
                    let centralDirectoryFileHeaderSignature           = 0x02014b50

                    guard size > endOfCentralDirectoryRecordLength else {
                        print("  * file too small to be a real ZIP")
                        continue
                    }

                    guard size < 1024 * 1024 * 2 else {
                        print("  * ZIP file too long. not analyzing. \(size) bytes")
                        continue
                    }

                    let data = try Data(contentsOf: fileURL)
                    var fileEndCommentOffset: Int? = nil

                    // look for a word matching the length to the end of the file
                    // this is usually the optional comment and its length
                    for offset in stride(from: size, to: max(endOfCentralDirectoryRecordLength, size - 65536), by: -1) {
                        let zipCommentLength: UInt16 = data[at: offset-2]!
                        if zipCommentLength == size - offset {
                            
                            // we got a matcing comment length, do we have the signature for the end of the central dir?
                            let zipesig: UInt32 = data[at: offset-endOfCentralDirectoryRecordLength]!
                            if zipesig == endOfCentralDirectoryRecordSignature {
                                fileEndCommentOffset = offset
                                break
                            }
                        }
                    }
                    
                    guard let fileEndCommentOffset = fileEndCommentOffset else {
                        print("  * not a valid ZIP file")
                        continue
                    }
                    
                    let endOfCentralDirectoryRecordOffset = fileEndCommentOffset - endOfCentralDirectoryRecordLength
                
                    let eocdNumberOfThisDisk: UInt16 = data[at: endOfCentralDirectoryRecordOffset+4]!
                    let eocdNumberOfDiskWithCentralDirStart: UInt16 = data[at: endOfCentralDirectoryRecordOffset+6]!
                    let eocdNumberOfCentralDirEntriesThisDisk: UInt16 = data[at: endOfCentralDirectoryRecordOffset+8]!
                    let eocdNumberOfCentralDirEntriesAllDisks: UInt16 = data[at: endOfCentralDirectoryRecordOffset+10]!
                    let eocdCentralDirLength: UInt32 = data[at:endOfCentralDirectoryRecordOffset+12]!
                    let eocdCentralDirOffset: UInt32 = data[at:endOfCentralDirectoryRecordOffset+16]!
                    
                    guard eocdNumberOfThisDisk != 0xffff && eocdNumberOfDiskWithCentralDirStart != 0xffff && eocdNumberOfCentralDirEntriesThisDisk != 0xffff && eocdNumberOfCentralDirEntriesAllDisks != 0xffff && eocdCentralDirLength != 0xffffffff && eocdCentralDirOffset != 0xffffffff else {
                        print("  ** ZIP is Zip64 format, not supported")
                        continue
                    }

                    guard eocdNumberOfCentralDirEntriesThisDisk == eocdNumberOfCentralDirEntriesAllDisks else {
                        print("  ** ZIP is part of a set, not supported")
                        continue
                    }

                    var goodFilenames: [String] = []

                    // analyse the central directory
                    var nextCentralDirOffset: Int = Int(eocdCentralDirOffset)
                    while true {
                        let centralDirOffset = nextCentralDirOffset
                        let sig: UInt32 = data[at:centralDirOffset]!
                        guard sig == centralDirectoryFileHeaderSignature else {
                            break
                        }

                        let cfhBitflag: UInt16 = data[at: centralDirOffset + 8]!
                        let cfhCompressionMethod: UInt16 = data[at: centralDirOffset + 10]!
                        //let cfhCompressedSize: UInt32 = data[at: centralDirOffset + 20]!
                        //let cfhUncompressedSize: UInt32 = data[at: centralDirOffset + 24]!
                        let cfhFilenameLength: UInt16 = data[at: centralDirOffset + 28]!
                        let cfhExtraFieldLength: UInt16 = data[at: centralDirOffset + 30]!
                        let cfhCommentLength: UInt16 = data[at: centralDirOffset + 32]!
                        
                        let cfhFilename = String(decoding: data[centralDirOffset+0x2e ..< centralDirOffset+0x2e+Int(cfhFilenameLength)], as: UTF8.self)
                        let fileURL = URL(fileURLWithPath: cfhFilename)

                        nextCentralDirOffset += centralDirectoryFileHeaderLength + Int(cfhFilenameLength) + Int(cfhExtraFieldLength) + Int(cfhCommentLength)
                        
                        guard !cfhFilename.hasSuffix("/") else {
                            //print("  * ignoring directory \"\(cfhFilename)\"")
                            continue
                        }
                        guard !fileURL.lastPathComponent.hasPrefix("._") else {
                            //print("  * ignoring macOS file \"\(cfhFilename)\"")
                            continue
                        }
                        guard cfhCompressionMethod == 0x0000 || cfhCompressionMethod == 0x0008 else {
                            //print("  * ignoring unsupported compression method \(cfhCompressionMethod) \"\(cfhFilename)\"")
                            continue
                        }
                        guard cfhBitflag & 0x0001 == 0 else {
                            //print("  * ignoring encrypted file \"\(cfhFilename)\"")
                            continue
                        }
                        guard speccyFileExtensions.contains(fileURL.pathExtension.lowercased()) else {
                            //print("  * ignoring non-Speccy filetype \"\(cfhFilename)\"")
                            continue
                        }
                        guard snapshotFileExtensions.contains(fileURL.pathExtension.lowercased()) else {
                            //print("  * ignoring non-snapshot filetype \"\(cfhFilename)\"")
                            continue
                        }

                        goodFilenames.append(cfhFilename)

                    }
                    
                    if goodFilenames.count != 0 {
                        print("  ZIP with \(goodFilenames.count) Speccy files out of \(eocdNumberOfCentralDirEntriesThisDisk) entries")
                        for filename in goodFilenames {
                            print("    \(filename)")
                        }
                    } else {
                        //print("  * ZIP contains no Speccy files out of \(eocdNumberOfCentralDirEntriesThisDisk) entries")
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
