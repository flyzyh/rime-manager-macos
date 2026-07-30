import SwiftUI
import AppKit

/// A syntax-highlighted code editor wrapping NSTextView.
struct HighlightedEditorView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var showLineNumbers: Bool
    var onTextChange: ((String) -> Void)?

    private let highlighter = YAMLSyntaxHighlighter()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // TextView setup
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.isHorizontallyResizable = false

        // Tab settings
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.tabStops = []
            style.defaultTabInterval = 28
            return style
        }()

        scrollView.documentView = textView

        // Line number ruler (must be after documentView is set)
        if showLineNumbers {
            let rulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
            scrollView.verticalRulerView = rulerView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        }
        context.coordinator.textView = textView

        // Initial text
        textView.string = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update text if different (and not during user typing)
        if textView.string != text && !context.coordinator.isEditing {
            textView.string = text
            context.coordinator.highlightAll()
        }

        // Update font size
        if let currentSize = textView.font?.pointSize, currentSize != fontSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }

        // Update line numbers
        if showLineNumbers {
            if scrollView.verticalRulerView == nil {
                let rulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
                scrollView.verticalRulerView = rulerView
                scrollView.hasVerticalRuler = true
                scrollView.rulersVisible = true
            }
        } else {
            scrollView.verticalRulerView = nil
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        let parent: HighlightedEditorView
        weak var textView: NSTextView?
        var isEditing = false
        private var highlightWorkItem: DispatchWorkItem?

        init(_ parent: HighlightedEditorView) {
            self.parent = parent
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            isEditing = true
            parent.text = textView.string
            parent.onTextChange?(textView.string)

            // Throttled highlighting via DispatchQueue (avoids Sendable closure issues)
            highlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.highlightAll()
                self?.isEditing = false
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }

        // MARK: - Highlighting

        func highlightAll() {
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }

            let fullText = textStorage.string
            let fullRange = NSRange(location: 0, length: (fullText as NSString).length)
            let colors = parent.highlighter.colors(for: textView.effectiveAppearance)

            textStorage.beginEditing()

            // Reset all to plain
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.removeAttribute(.font, range: fullRange)

            // Set base font
            let baseFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
            textStorage.addAttribute(.font, value: baseFont, range: fullRange)

            // Highlight line by line
            let lines = fullText.components(separatedBy: "\n")
            var currentOffset = 0

            for line in lines {
                let tokens = parent.highlighter.tokenizeLine(line)

                for (tokenRange, tokenType) in tokens {
                    let absoluteRange = NSRange(
                        location: currentOffset + tokenRange.location,
                        length: tokenRange.length
                    )
                    if absoluteRange.upperBound <= (fullText as NSString).length {
                        if let color = colors[tokenType] {
                            textStorage.addAttribute(.foregroundColor, value: color, range: absoluteRange)
                        }

                        if tokenType == .key {
                            let boldFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .semibold)
                            textStorage.addAttribute(.font, value: boldFont, range: absoluteRange)
                        }
                    }
                }

                currentOffset += (line as NSString).length + 1
            }

            textStorage.endEditing()
        }
    }
}

// MARK: - Line Number Ruler

final class LineNumberRulerView: NSRulerView {
    private var textView: NSTextView
    private var font: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    }
    private var attributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
    }

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let nsString = textView.string as NSString

        // Map glyph range to character range
        let charRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        var lineNumber = 1

        // Count lines up to the start
        if charRange.location > 0 {
            lineNumber = nsString.substring(to: charRange.location).components(separatedBy: "\n").count
        }

        var index = charRange.location
        while index < NSMaxRange(charRange) {
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            let x = ruleThickness - labelSize.width - 4
            let y = rect.origin.y + (rect.height - labelSize.height) / 2

            label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)

            index = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }
}
