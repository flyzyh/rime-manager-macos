import SwiftUI

// MARK: - Liquid Glass Compatibility Layer

/// Applies Liquid Glass effect on macOS 26+, falls back to regular material on older systems.
struct AdaptiveGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
}

/// Applies a clear Liquid Glass effect (more subtle) on macOS 26+.
struct AdaptiveGlassClearModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26, *) {
            content
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        content
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
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

    /// Applies a full-window clear Liquid Glass surface on macOS 26+.
    /// The fallback intentionally uses a lighter material than card glass.
    func adaptiveWindowGlass(cornerRadius: CGFloat = 0) -> some View {
        modifier(AdaptiveWindowGlassModifier(cornerRadius: cornerRadius))
    }
}

/// Full-window glass is handled by the root AppKit glass view on macOS 26+.
/// SwiftUI only provides a fallback here, which avoids stacking two glass layers.
struct AdaptiveWindowGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
                    .ignoresSafeArea()
            }
    }
}

// MARK: - Root Window Glass

@MainActor
enum RootWindowGlass {
    private static weak var installedContentView: NSView?

    /// Replaces the window's root content view with an AppKit Liquid Glass container.
    /// AppKit's `NSGlassEffectView` samples the desktop behind the window and is visibly
    /// stronger than the SwiftUI glass modifier, especially for NavigationSplitView.
    static func install(in window: NSWindow) {
        guard let content = window.contentView else { return }
        guard installedContentView !== content else { return }

        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: content.frame)
            glass.style = .clear
            glass.tintColor = nil
            glass.cornerRadius = 0
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = true
            }

            content.removeFromSuperview()
            glass.contentView = content
            window.contentView = glass

            glass.autoresizingMask = [.width, .height]
            content.autoresizingMask = [.width, .height]
            installedContentView = glass
            return
        }
        #endif

        installedContentView = content
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
        #if compiler(>=6.3)
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
