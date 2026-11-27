import AppKit

/// "Midnight Instrument": one dark palette for every BiTTU surface. The values
/// are the design tokens, mirrored in windows/BiTTU/Theme.cs so both builds
/// read the same, and in the HTTPS-only warning pages.
enum Theme {
    static let background = NSColor(srgbRed: 0.039, green: 0.055, blue: 0.078, alpha: 1)  // #0A0E14
    static let surface = NSColor(srgbRed: 0.067, green: 0.086, blue: 0.122, alpha: 1)      // #11161F
    static let raised = NSColor(srgbRed: 0.086, green: 0.114, blue: 0.157, alpha: 1)       // #161D28
    static let border = NSColor(srgbRed: 0.145, green: 0.188, blue: 0.239, alpha: 1)       // #25303D
    static let foreground = NSColor(srgbRed: 0.863, green: 0.902, blue: 0.949, alpha: 1)   // #DCE6F2  
    static let heading = NSColor(srgbRed: 0.953, green: 0.973, blue: 1.000, alpha: 1)      // #F3F8FF
    static let muted = NSColor(srgbRed: 0.557, green: 0.616, blue: 0.694, alpha: 1)        // #8E9DB1
    static let accent = NSColor(srgbRed: 0.357, green: 0.894, blue: 0.608, alpha: 1)       // #5BE49B
    static let accentInk = NSColor(srgbRed: 0.024, green: 0.157, blue: 0.102, alpha: 1)    // #06281A
    static let danger = NSColor(srgbRed: 1.000, green: 0.478, blue: 0.522, alpha: 1)       // #FF7A85

    static let radius: CGFloat = 6

    static func mono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// Small, uppercase, letter-spaced mono readout (the "eyebrow" role).
    static func eyebrow(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: mono(10, .semibold),
            .foregroundColor: muted,
            .kern: 1.1,
        ])
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Dark appearance and the theme background for a window we build ourselves.
    static func apply(to window: NSWindow) {
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = background
        window.animationBehavior = reduceMotion ? .none : .utilityWindow
    }

    /// Native rounded text button in the dark chrome (downloads, library, reader).
    static func styleTextButton(_ button: NSButton, primary: Bool = false) {
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = mono(11.5, .medium)
        button.focusRingType = .default
        button.bezelColor = primary ? accent : nil
        button.contentTintColor = primary ? accentInk : foreground
    }

    /// Dark, bordered text/address field with the 6pt radius and a visible
    /// keyboard focus ring.
    static func styleField(_ field: NSTextField, size: CGFloat = 12) {
        field.font = mono(size)
        field.textColor = foreground
        field.isBezeled = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.focusRingType = .exterior
        field.wantsLayer = true
        field.layer?.backgroundColor = raised.cgColor
        field.layer?.cornerRadius = radius
        field.layer?.borderWidth = 1
        field.layer?.borderColor = border.cgColor
    }

    /// Flat, evenly padded control used across toolbars, panels and lists.
    static func styleButton(_ button: NSButton, primary: Bool = false) {
        button.isBordered = false
        button.focusRingType = .exterior
        button.wantsLayer = true
        button.layer?.cornerRadius = radius
        button.layer?.backgroundColor = (primary ? accent : raised).cgColor
        button.contentTintColor = primary ? accentInk : foreground
        button.font = mono(11.5, .medium)
    }

    /// Fills a plain view (chrome bar, panel body) with a theme color.
    static func fill(_ view: NSView, _ color: NSColor) {
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
    }
}