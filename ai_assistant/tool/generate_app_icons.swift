import AppKit

struct IconTarget {
    let path: String
    let size: Int
}

let root = FileManager.default.currentDirectoryPath
let sourcePath = CommandLine.arguments.dropFirst().first ?? "tool/app_icon_source.svg"
let sourceURL = URL(fileURLWithPath: sourcePath.hasPrefix("/") ? sourcePath : "\(root)/\(sourcePath)")

let targets: [IconTarget] = [
    IconTarget(path: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png", size: 48),
    IconTarget(path: "android/app/src/main/res/mipmap-hdpi/ic_launcher.png", size: 72),
    IconTarget(path: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", size: 96),
    IconTarget(path: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", size: 144),
    IconTarget(path: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", size: 192),
    IconTarget(path: "android/app/src/main/res/drawable-nodpi/splash_icon_large.png", size: 1024),
    IconTarget(path: "ohos/AppScope/resources/base/media/app_icon.png", size: 114),
    IconTarget(path: "ohos/entry/src/main/resources/base/media/icon.png", size: 114),
    IconTarget(path: "ohos/entry/src/main/resources/base/media/splash_icon.png", size: 1024),
    IconTarget(path: "ohos/entry/src/ohosTest/resources/base/media/icon.png", size: 114),
    IconTarget(path: "web/favicon.png", size: 16),
    IconTarget(path: "web/icons/Icon-192.png", size: 192),
    IconTarget(path: "web/icons/Icon-512.png", size: 512),
    IconTarget(path: "web/icons/Icon-maskable-192.png", size: 192),
    IconTarget(path: "web/icons/Icon-maskable-512.png", size: 512),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png", size: 16),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png", size: 32),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png", size: 64),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png", size: 128),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png", size: 256),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png", size: 512),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", size: 1024),
]

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(
        domain: "IconGenerator",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Cannot load icon source: \(sourceURL.path)"]
    )
}

func renderIcon(size: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }
    bitmap.size = NSSize(width: size, height: size)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGenerator", code: 3)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    let context = graphicsContext.cgContext
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(x: 0, y: 0, width: sourceImage.size.width, height: sourceImage.size.height),
        operation: .sourceOver,
        fraction: 1
    )
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to path: String) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 4)
    }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

for target in targets {
    let fullPath = "\(root)/\(target.path)"
    try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: fullPath).deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try writePNG(try renderIcon(size: target.size), to: fullPath)
}
