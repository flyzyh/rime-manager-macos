import SwiftUI

// MARK: - Liquid Glass Compatibility Layer

/// Applies Liquid Glass effect on macOS 26+, falls back to regular material on older systems.
struct AdaptiveGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// Applies a clear Liquid Glass effect (more subtle) on macOS 26+.
struct AdaptiveGlassClearModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies adaptive glass effect: Liquid Glass on macOS 26+, material fallback on older.
    func adaptiveGlass(cornerRadius: CGFloat = 12) -> some View {
        modifier(AdaptiveGlassModifier(cornerRadius: cornerRadius))
    }

    /// Applies clear adaptive glass effect (more subtle).
    func adaptiveGlassClear(cornerRadius: CGFloat = 12) -> some View {
        modifier(AdaptiveGlassClearModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Container

/// A container that groups glass effects for consistent visual sampling on macOS 26+.
struct AdaptiveGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
