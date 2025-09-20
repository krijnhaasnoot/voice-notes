import SwiftUI

// MARK: - Font Configuration
struct FontConfiguration {
    
    // MARK: - Font Names
    private static let poppinsRegular = "Poppins-Regular"
    private static let poppinsMedium = "Poppins-Medium"
    private static let poppinsSemiBold = "Poppins-SemiBold"
    private static let poppinsBold = "Poppins-Bold"
    private static let poppinsLight = "Poppins-Light"
    
    // MARK: - Text Styles
    static let largeTitle = Font.custom(poppinsBold, size: 34)
    static let title1 = Font.custom(poppinsBold, size: 28)
    static let title2 = Font.custom(poppinsBold, size: 22)
    static let title3 = Font.custom(poppinsSemiBold, size: 20)
    static let headline = Font.custom(poppinsSemiBold, size: 17)
    static let body = Font.custom(poppinsRegular, size: 17)
    static let callout = Font.custom(poppinsRegular, size: 16)
    static let subheadline = Font.custom(poppinsRegular, size: 15)
    static let footnote = Font.custom(poppinsRegular, size: 13)
    static let caption = Font.custom(poppinsRegular, size: 12)
    static let caption2 = Font.custom(poppinsRegular, size: 11)
    
    // MARK: - Custom Sizes
    static func regular(size: CGFloat) -> Font {
        Font.custom(poppinsRegular, size: size)
    }
    
    static func medium(size: CGFloat) -> Font {
        Font.custom(poppinsMedium, size: size)
    }
    
    static func semiBold(size: CGFloat) -> Font {
        Font.custom(poppinsSemiBold, size: size)
    }
    
    static func bold(size: CGFloat) -> Font {
        Font.custom(poppinsBold, size: size)
    }
    
    static func light(size: CGFloat) -> Font {
        Font.custom(poppinsLight, size: size)
    }
}

// MARK: - Font Extension for Easy Access
extension Font {
    static let poppins = FontConfiguration.self
}

// MARK: - View Extension for Global Font Application
extension View {
    func applyPoppinsFont() -> some View {
        self.font(.poppins.body)
    }
    
    func poppinsFont(_ font: Font) -> some View {
        self.font(font)
    }
}

// MARK: - Text Style Modifiers
extension Text {
    func poppinsTitle() -> some View {
        self.font(.poppins.title1)
    }
    
    func poppinsTitle2() -> some View {
        self.font(.poppins.title2)
    }
    
    func poppinsTitle3() -> some View {
        self.font(.poppins.title3)
    }
    
    func poppinsHeadline() -> some View {
        self.font(.poppins.headline)
    }
    
    func poppinsBody() -> some View {
        self.font(.poppins.body)
    }
    
    func poppinsCallout() -> some View {
        self.font(.poppins.callout)
    }
    
    func poppinsSubheadline() -> some View {
        self.font(.poppins.subheadline)
    }
    
    func poppinsFootnote() -> some View {
        self.font(.poppins.footnote)
    }
    
    func poppinsCaption() -> some View {
        self.font(.poppins.caption)
    }
    
    func poppinsCaption2() -> some View {
        self.font(.poppins.caption2)
    }
}