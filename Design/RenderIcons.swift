import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let info: [String: Any] = ["author": "xcode", "version": 1]

func writeJSON(_ value: [String: Any], to directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("Contents.json"))
}

func icon(width: Int, height: Int, to url: URL) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let diameter = CGFloat(min(width, height)) * 0.72
    let rect = CGRect(x: (CGFloat(width) - diameter) / 2, y: (CGFloat(height) - diameter) / 2,
                      width: diameter, height: diameter)
    context.setFillColor(NSColor.white.cgColor)
    context.fillEllipse(in: rect)
    context.setStrokeColor(NSColor.black.cgColor)
    context.setLineWidth(diameter * 0.07)
    context.strokeEllipse(in: rect.insetBy(dx: diameter * 0.035, dy: diameter * 0.035))
    context.setLineWidth(diameter * 0.035)
    context.strokeEllipse(in: rect.insetBy(dx: diameter * 0.22, dy: diameter * 0.22))
    context.setFillColor(NSColor.black.cgColor)
    for index in 0..<8 {
        context.saveGState()
        context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        context.rotate(by: CGFloat(index) * .pi / 4)
        context.fill(CGRect(x: -diameter * 0.05, y: -diameter * 0.45,
                            width: diameter * 0.1, height: diameter * 0.18))
        context.restoreGState()
    }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

let appAssets = root.appendingPathComponent("App/Assets.xcassets")
let appIcon = appAssets.appendingPathComponent("AppIcon.appiconset")
try writeJSON(["info": info], to: appAssets)
try writeJSON(["info": info, "images": [["filename": "River.png", "idiom": "universal",
                                        "platform": "ios", "size": "1024x1024"]]], to: appIcon)
try icon(width: 1024, height: 1024, to: appIcon.appendingPathComponent("River.png"))

let messageAssets = root.appendingPathComponent("Messages/Assets.xcassets")
let messageIcon = messageAssets.appendingPathComponent("iMessage App Icon.stickersiconset")
let sizes: [(Int, Int, Int, String)] = [
    (32, 24, 2, "universal"), (32, 24, 3, "universal"), (1024, 768, 1, "ios-marketing"),
    (29, 29, 2, "iphone"), (29, 29, 3, "iphone"), (60, 45, 2, "iphone"), (60, 45, 3, "iphone"),
    (29, 29, 2, "ipad"), (67, 50, 2, "ipad"), (74, 55, 2, "ipad"),
]
let images = sizes.map { width, height, scale, idiom in
    ["filename": "\(idiom)-\(width)x\(height)@\(scale)x.png", "idiom": idiom,
     "size": "\(width)x\(height)", "scale": "\(scale)x"]
}
try writeJSON(["info": info], to: messageAssets)
try writeJSON(["info": info, "images": images], to: messageIcon)
for (index, size) in sizes.enumerated() {
    try icon(width: size.0 * size.2, height: size.1 * size.2,
             to: messageIcon.appendingPathComponent(images[index]["filename"]!))
}
print("Generated the River app and Messages icons.")
