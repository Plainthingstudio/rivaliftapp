import Foundation
import ImageIO
import UniformTypeIdentifiers

// usage: toheic <in.png> <out.heic> [quality] — keeps the alpha channel.
let args = CommandLine.arguments
let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.heic.identifier as CFString, 1, nil)!
let quality = args.count > 3 ? Double(args[3])! : 0.8
CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
exit(CGImageDestinationFinalize(destination) ? 0 : 1)
