import AppKit
import CoreGraphics
import Foundation

let sourcePath = "scripts/icon_source.png"
let outputPath = "scripts/rime_icon_1024.png"
let outSize = 1024

// Load source image
guard let nsImg = NSImage(contentsOfFile: sourcePath),
      let tiff = nsImg.tiffRepresentation,
      let bmp = NSBitmapImageRep(data: tiff),
      let srcCG = bmp.cgImage else {
    print("Cannot load image")
    exit(1)
}

let srcW = srcCG.width
let srcH = srcCG.height
print("Source: \(srcW)x\(srcH)")

// Read source pixels (RGBA premultiplied)
let srcBPR = srcW * 4
var srcPixels = [UInt8](repeating: 0, count: srcW * srcH * 4)
let srcCtx = CGContext(data: &srcPixels, width: srcW, height: srcH,
                       bitsPerComponent: 8, bytesPerRow: srcBPR,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
srcCtx.draw(srcCG, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))

// Crop region for R logo (exclude text at bottom)
let cropTop = Int(Double(srcH) * 0.02)
let cropBottom = Int(Double(srcH) * 0.65)
let cropLeft = Int(Double(srcW) * 0.18)
let cropRight = Int(Double(srcW) * 0.82)
let cropW = cropRight - cropLeft
let cropH = cropBottom - cropTop

// Output buffer (fully transparent)
var outPixels = [UInt8](repeating: 0, count: outSize * outSize * 4)

// Scale to fit with padding
let padding = 60
let avail = outSize - padding * 2
let scale = min(Double(avail) / Double(cropW), Double(avail) / Double(cropH))
let drawW = Int(Double(cropW) * scale)
let drawH = Int(Double(cropH) * scale)
let offX = (outSize - drawW) / 2
let offY = (outSize - drawH) / 2

for dy in 0..<drawH {
    for dx in 0..<drawW {
        let sx = cropLeft + Int(Double(dx) / scale)
        let sy = cropTop + Int(Double(dy) / scale)
        guard sx < srcW, sy < srcH else { continue }

        let si = (sy * srcW + sx) * 4
        let r = srcPixels[si]
        let g = srcPixels[si + 1]
        let b = srcPixels[si + 2]
        let a = srcPixels[si + 3]

        let rf = Double(r), gf = Double(g), bf = Double(b)
        let brightness = (rf + gf + bf) / 3.0
        let maxC = max(rf, max(gf, bf))
        let minC = min(rf, min(gf, bf))
        let sat = maxC > 0 ? (maxC - minC) / maxC : 0

        // Skip white/near-white background and gray watermark
        if brightness > 200 && sat < 0.10 { continue }

        // Un-premultiply
        let alpha = Double(a) / 255.0
        let fr = alpha > 0.01 ? UInt8(min(255, rf / alpha)) : r
        let fg = alpha > 0.01 ? UInt8(min(255, gf / alpha)) : g
        let fb = alpha > 0.01 ? UInt8(min(255, bf / alpha)) : b

        let ox = offX + dx
        let oy = offY + dy
        let oi = (oy * outSize + ox) * 4
        outPixels[oi] = fr
        outPixels[oi + 1] = fg
        outPixels[oi + 2] = fb
        outPixels[oi + 3] = 255
    }
}

// Create CGImage from pixel buffer
let outBPR = outSize * 4
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
guard let provider = CGDataProvider(data: Data(outPixels) as CFData),
      let finalCG = CGImage(width: outSize, height: outSize,
                            bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: outBPR,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: bitmapInfo,
                            provider: provider,
                            decode: nil, shouldInterpolate: true,
                            intent: .defaultIntent) else {
    print("Failed to create output image")
    exit(1)
}

// Save as PNG
let nsRep = NSBitmapImageRep(cgImage: finalCG)
let pngData = nsRep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("✅ Transparent icon saved: \(outputPath)")
