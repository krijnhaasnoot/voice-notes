import SwiftUI
import AVFoundation

// MARK: - Keyboard Dismissal Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            hideKeyboard()
        }
    }
}

// MARK: - Liquid Glass Compatibility
extension View {
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            return AnyView(transform(self))
        } else {
            return AnyView(self)
        }
    }
    
    @available(iOS 18.0, *)
    func glassEffect(_ effect: LiquidGlassEffect = .regular) -> some View {
        if #available(iOS 26.0, *) {
            return self.modifier(LiquidGlassModifier(effect: effect))
        } else {
            return self.background(.ultraThinMaterial, in: .capsule)
        }
    }
    
    @available(iOS 18.0, *)
    func glassEffectContainer<Content: View>(_ spacing: CGFloat = 0, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            return GlassEffectContainer(spacing: spacing, content: content)
        } else {
            return VStack(spacing: spacing, content: content)
        }
    }
}

// MARK: - Glass Effect Types
enum LiquidGlassEffect {
    case regular
    case clear
    case tinted(Color)
    
    func interactive() -> LiquidGlassEffect {
        return self // For compatibility
    }
}

// MARK: - Liquid Glass Modifiers
@available(iOS 18.0, *)
struct LiquidGlassModifier: ViewModifier {
    let effect: LiquidGlassEffect
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Use actual iOS 26 liquid glass when available
            content
                .background(.regularMaterial, in: .capsule)
                .overlay {
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(.quaternary.opacity(0.3), lineWidth: 1)
                }
        } else {
            // Fallback implementation with materials
            content
                .background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.quaternary.opacity(0.5), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Glass Container
@available(iOS 18.0, *)
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .background(.regularMaterial.opacity(0.8), in: .rect(cornerRadius: 16))
    }
}

// MARK: - Liquid Glass Button Container
struct LiquidGlassButtonContainer<Content: View>: View {
    let content: Content
    @Namespace private var namespace
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .if(isLiquidGlassAvailable) { view in
                // Use glass effect union when available
                view.background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.quaternary.opacity(0.4), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Liquid Glass Search Bar
struct LiquidGlassSearchBar: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.poppins.medium(size: 16))
                .foregroundStyle(.tertiary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
            
            if isSearchFocused && !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.poppins.regular(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.quaternary.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .if(isLiquidGlassAvailable) { view in
            view.glassEffect(.clear)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
        }
    }
}

// MARK: - iOS Version Detection
var isLiquidGlassAvailable: Bool {
    if #available(iOS 26.0, *) {
        return true
    } else {
        return false
    }
}

// MARK: - Tab View Style for Liquid Glass (Placeholder for iOS 26+)
// Note: Actual TabViewStyle implementation will be available when iOS 26+ APIs are released

// MARK: - Tab Bar Appearance Helper
extension View {
    @available(iOS 18.0, *)
    func applyLiquidGlassTabBar() -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ Liquid Glass TabBar
            return self
                .toolbarBackground(.clear, for: .tabBar)
                .toolbar(.visible, for: .tabBar)
                .onAppear {
                    configureLiquidGlassTabBar()
                }
        } else {
            // iOS 18-25 Enhanced Material TabBar
            return self
                .toolbarBackground(.thinMaterial, for: .tabBar)
                .toolbar(.visible, for: .tabBar)
                .onAppear {
                    configureEnhancedTabBar()
                }
        }
    }
}

@available(iOS 26.0, *)
private func configureLiquidGlassTabBar() {
    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = UIColor.clear
    
    // Enhanced liquid glass effect for iOS 26+
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    appearance.backgroundEffect = blurEffect
    
    // Configure tab bar item appearance with glass effects
    let normalItemAppearance = UITabBarItemAppearance()
    normalItemAppearance.normal.titleTextAttributes = [
        .foregroundColor: UIColor.label.withAlphaComponent(0.8)
    ]
    normalItemAppearance.selected.titleTextAttributes = [
        .foregroundColor: UIColor.systemBlue
    ]
    
    appearance.stackedLayoutAppearance = normalItemAppearance
    appearance.inlineLayoutAppearance = normalItemAppearance
    appearance.compactInlineLayoutAppearance = normalItemAppearance
    
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}

@available(iOS 18.0, *)
private func configureEnhancedTabBar() {
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    
    // Enhanced material effect for pre-iOS 26
    let blurEffect = UIBlurEffect(style: .systemMaterial)
    appearance.backgroundEffect = blurEffect
    
    // Subtle styling improvements
    let normalItemAppearance = UITabBarItemAppearance()
    normalItemAppearance.normal.titleTextAttributes = [
        .foregroundColor: UIColor.secondaryLabel
    ]
    normalItemAppearance.selected.titleTextAttributes = [
        .foregroundColor: UIColor.systemBlue
    ]
    
    appearance.stackedLayoutAppearance = normalItemAppearance
    appearance.inlineLayoutAppearance = normalItemAppearance
    appearance.compactInlineLayoutAppearance = normalItemAppearance
    
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}
