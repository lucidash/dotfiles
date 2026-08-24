//
//  make-icons — SF Symbol 기반 앱 아이콘(.icns) 생성기
//
//  사용법: make-icons <출력디렉터리> <이름>:<SF Symbol>:<HEX> ...
//

import AppKit

let canvas: CGFloat = 1024
let squircleInset: CGFloat = 92          // Big Sur 이후 아이콘 여백
let cornerRadius: CGFloat = 190
let glyphRatio: CGFloat = 0.46           // 캔버스 대비 글리프 크기

/// #RRGGBB 를 NSColor 로.
func color(hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                   green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255,
                   alpha: 1)
}

/// SF Symbol 을 흰색으로 칠한 정사각 비트맵으로 렌더링한다.
///
/// SymbolConfiguration 의 paletteColors 는 macOS 12+ 라서 쓰지 않는다. 대신 심볼을
/// 독립 비트맵에 그린 뒤 sourceAtop 으로 흰색을 덮어 같은 결과를 얻는다. 배경 위에서
/// 직접 sourceAtop 을 쓰면 squircle 까지 흰색이 되므로 반드시 분리해서 그려야 한다.
func glyph(named symbol: String, boxSize: CGFloat) -> NSImage? {
    guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil),
          let symbolImage = base.withSymbolConfiguration(
              NSImage.SymbolConfiguration(pointSize: boxSize, weight: .medium)) else {
        return nil
    }

    let side = Int(boxSize.rounded())
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: side, pixelsHigh: side,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // NSBitmapImageRep 버퍼는 zero-init 이 보장되지 않는다. 클리어하지 않으면 알파가
    // 불투명한 상태로 남아 아래 sourceAtop 이 글리프가 아니라 박스 전체를 칠한다.
    let box = NSRect(x: 0, y: 0, width: boxSize, height: boxSize)
    NSColor.clear.setFill()
    box.fill(using: .copy)

    let natural = symbolImage.size
    let scale = boxSize / max(natural.width, natural.height)
    let drawn = NSSize(width: natural.width * scale, height: natural.height * scale)
    symbolImage.draw(in: NSRect(x: (boxSize - drawn.width) / 2,
                                y: (boxSize - drawn.height) / 2,
                                width: drawn.width, height: drawn.height))

    NSColor.white.setFill()
    box.fill(using: .sourceAtop)

    // rep 을 그대로 draw(in:) 하면 알파가 무시되어 sourceAtop 이 흰색을 남긴 영역까지
    // 불투명하게 찍힌다. NSImage 로 감싸 sourceOver 로 합성해야 한다.
    let image = NSImage(size: box.size)
    image.addRepresentation(rep)
    return image
}

/// 1024×1024 마스터 아이콘 PNG 데이터를 만든다.
func masterIcon(symbol: String, accent: NSColor) -> Data? {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: canvas, height: canvas).fill(using: .copy)

    // 배경 squircle + 세로 그라디언트
    let body = NSRect(x: squircleInset, y: squircleInset,
                      width: canvas - squircleInset * 2, height: canvas - squircleInset * 2)
    let shape = NSBezierPath(roundedRect: body, xRadius: cornerRadius, yRadius: cornerRadius)

    let top = accent.blended(withFraction: 0.28, of: .white) ?? accent
    let bottom = accent.blended(withFraction: 0.22, of: .black) ?? accent
    NSGradient(starting: bottom, ending: top)?.draw(in: shape, angle: 90)

    // 테두리를 아주 옅게 넣어 밝은 배경에서도 형태가 잡히게 한다.
    NSColor(white: 0, alpha: 0.10).setStroke()
    shape.lineWidth = 3
    shape.stroke()

    // 글리프
    if let image = glyph(named: symbol, boxSize: canvas * glyphRatio) {
        let box = image.size.width
        image.draw(in: NSRect(x: (canvas - box) / 2, y: (canvas - box) / 2,
                              width: box, height: box),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
    } else {
        FileHandle.standardError.write(Data("경고: SF Symbol '\(symbol)' 를 찾을 수 없습니다\n".utf8))
    }

    return rep.representation(using: .png, properties: [:])
}

// MARK: - main

let arguments = CommandLine.arguments.dropFirst()
guard let outputDirectory = arguments.first, arguments.count > 1 else {
    FileHandle.standardError.write(Data("사용법: make-icons <출력디렉터리> <이름>:<symbol>:<HEX> ...\n".utf8))
    exit(EXIT_FAILURE)
}

for spec in arguments.dropFirst() {
    let parts = spec.split(separator: ":").map(String.init)
    guard parts.count == 3 else {
        FileHandle.standardError.write(Data("잘못된 스펙: \(spec)\n".utf8))
        exit(EXIT_FAILURE)
    }
    let (name, symbol, hex) = (parts[0], parts[1], parts[2])

    guard let png = masterIcon(symbol: symbol, accent: color(hex: hex)) else {
        FileHandle.standardError.write(Data("\(name): 렌더링 실패\n".utf8))
        exit(EXIT_FAILURE)
    }
    let path = "\(outputDirectory)/\(name).png"
    try png.write(to: URL(fileURLWithPath: path))
    print("  \(name).png  (\(symbol), \(hex))")
}
