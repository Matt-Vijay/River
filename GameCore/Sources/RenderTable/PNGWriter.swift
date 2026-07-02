import AppKit
import SwiftUI

struct PNGWriter {
    let outputDir: String

    init(outputDir: String = ("~/Developer/River/render" as NSString).expandingTildeInPath) {
        self.outputDir = outputDir
    }

    @MainActor
    func writeSized<V: View>(_ view: V, width: CGFloat, height: CGFloat, to name: String) {
        writePNG(view, width: width, height: height, scale: 1, to: name)
    }

    @MainActor
    func writePNG<V: View>(_ view: V, to name: String) {
        writePNG(view, width: 393, height: 852, scale: 2, to: name)
    }

    @MainActor
    func writePNG<V: View>(_ view: V, width: CGFloat, height: CGFloat,
                           scale: CGFloat, to name: String) {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = scale

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("Failed to render \(name)")
            return
        }

        let path = (outputDir as NSString).appendingPathComponent(name)
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        } catch {
            print("Write error \(name): \(error)")
        }
    }
}
