import SwiftUI

enum Theme {
    enum Palette {
        static let white = Color("white")
        static let black = Color("black")
        static let secondaryText = Color("secondaryText")
        static let divider = Color("divider")
        static let background = Color("background")
        static let cardBackground = Color("cardBackground")
        static let cardBackgroundPressed = Color("cardBackgroundPressed")
        static let cardBackgroundSelected = Color("cardBackgroundSelected")
        static let accent = Color("accent")
        static let accentPressed = Color("accentPressed")
        static let red = Color("red")
        static let green = Color("green")
        static let blue = Color("blue")
        static let yellow = Color("yellow")
        static let orange = Color("orange")
        static let purple = Color("purple")
        static let pink = Color("pink")
        static let teal = Color("teal")
        static let cyan = Color("cyan")
        static let indigo = Color("indigo")
        static let lime = Color("lime")
        static let brown = Color("brown")
        static let gray = Color("gray")
    }

    enum FontSizes {
        static let titleLarge: Font = .largeTitle
        static let titleMedium: Font = .title2
        static let titleSmall: Font = .title3
        static let headline: Font = .headline
        static let bodyLarge: Font = .body
        static let bodyMedium: Font = .callout
        static let bodySmall: Font = .footnote
        static let captionLarge: Font = .caption
        static let captionMedium: Font = .caption2
        static let captionSmall: Font = .system(size: 8)
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radii {
        static let xs: CGFloat = 2
        static let s: CGFloat = 4
        static let m: CGFloat = 8
        static let l: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
    }

    enum Animations {
        static let standard: Animation = .spring()
    }
}
