import CoreImage
import Foundation
import Vision

// usage: maskonly <in> <out_mask.png> — soft foreground mask (all instances) as grayscale PNG.
let args = CommandLine.arguments
guard let image = CIImage(contentsOf: URL(fileURLWithPath: args[1])) else { print("cannot read \(args[1])"); exit(1) }
let handler = VNImageRequestHandler(ciImage: image)
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])
if let result = request.results?.first {
    let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
    try CIContext().writePNGRepresentation(of: CIImage(cvPixelBuffer: mask), to: URL(fileURLWithPath: args[2]), format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
} else {
    print("no subject in \(args[1])")
}
