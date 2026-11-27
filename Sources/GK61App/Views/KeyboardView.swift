import GK61Core
import SwiftUI

/// How one keycap looks; each page decides this from its own state.
struct KeyCapAppearance {
    var caption: String
    var detail: String?
    var fill: Color?
    var foreground: Color?
    var isEmphasized = false
    var isEnabled = true
    var help: String?
}

/// The 61 keys drawn from the layout's frames, scaled to fit the available space.
struct KeyboardView: View {
    let keys: [KeyLayout.Key]
    let selectedKeyID: KeyLayout.Key.ID?
    let appearance: (KeyLayout.Key) -> KeyCapAppearance
    let onSelect: (KeyLayout.Key) -> Void

    var body: some View {
        let bounds = KeyboardGeometry.bounds(of: keys)
        GeometryReader { proxy in
            let scale = min(proxy.size.width / bounds.width, proxy.size.height / bounds.height)
            ZStack(alignment: .topLeading) {
                ForEach(keys) { key in
                    keyButton(for: key, scale: scale, origin: bounds.origin)
                }
            }
        }
        .aspectRatio(bounds.width / bounds.height, contentMode: .fit)
    }

    private func keyButton(for key: KeyLayout.Key, scale: CGFloat, origin: CGPoint) -> some View {
        let rect = KeyboardGeometry.capRect(of: key)
        let look = appearance(key)
        return Button { onSelect(key) } label: {
            KeyCap(appearance: look, isSelected: key.id == selectedKeyID, scale: scale)
        }
        .buttonStyle(.plain)
        .disabled(!look.isEnabled)
        .help(look.help ?? key.label)
        .accessibilityLabel(key.label)
        .accessibilityValue(look.detail ?? "")
        .accessibilityAddTraits(key.id == selectedKeyID ? .isSelected : [])
        .frame(width: rect.width * scale, height: rect.height * scale)
        .position(x: (rect.midX - origin.x) * scale, y: (rect.midY - origin.y) * scale)
    }
}

private struct KeyCap: View {
    let appearance: KeyCapAppearance
    let isSelected: Bool
    let scale: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
        VStack(spacing: 1 * scale) {
            Text(appearance.caption)
                .font(.system(size: 10 * scale, weight: .medium))
            if let detail = appearance.detail {
                Text(detail)
                    .font(.system(size: 9 * scale, weight: .semibold))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(2 * scale)
        .foregroundStyle(foregroundStyle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(fillStyle))
        .overlay(shape.strokeBorder(borderStyle, lineWidth: (isSelected ? 2.5 : 1) * scale))
        .contentShape(shape)
    }

    private var foregroundStyle: AnyShapeStyle {
        if let foreground = appearance.foreground { return AnyShapeStyle(foreground) }
        return appearance.isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    private var fillStyle: AnyShapeStyle {
        if let fill = appearance.fill { return AnyShapeStyle(fill) }
        if appearance.isEmphasized { return AnyShapeStyle(Color.accentColor.opacity(0.25)) }
        return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
    }

    private var borderStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor) }
        if appearance.isEmphasized { return AnyShapeStyle(Color.accentColor.opacity(0.7)) }
        return AnyShapeStyle(.separator)
    }
}

/// Converts the Windows app's pixel frames into keycap rectangles.
enum KeyboardGeometry {
    /// The Windows frames cover only the printed keycap top, leaving wide gaps; widening them reads as real keys.
    private static let capOutset = CGSize(width: 5, height: 4)

    static func capRect(of key: KeyLayout.Key) -> CGRect {
        CGRect(x: key.frame.x, y: key.frame.y, width: key.frame.width, height: key.frame.height)
            .insetBy(dx: -capOutset.width, dy: -capOutset.height)
    }

    static func bounds(of keys: [KeyLayout.Key]) -> CGRect {
        let union = keys.map(capRect(of:)).reduce(CGRect.null) { $0.union($1) }
        return union.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : union
    }
}
