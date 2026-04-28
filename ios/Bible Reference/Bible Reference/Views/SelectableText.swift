/// SelectableText.swift
/// UITextView wrapper that supports native text selection inside ScrollView.
/// SwiftUI's Text with .textSelection(.enabled) conflicts with ScrollView's
/// pan gesture recognizer, causing "System gesture gate timed out" and no selection.

import SwiftUI
import UIKit

struct SelectableText: UIViewRepresentable {
    @ObservedObject private var fontSizeStore = FontSizeStore.shared

    let text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var lineSpacing: CGFloat = 5
    var italic: Bool = false
    var color: UIColor = .label

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return tv
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView tv: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? tv.bounds.width
        guard width > 0 else { return nil }
        let size = tv.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = fontSizeStore.scaled(lineSpacing)

        let baseFont: UIFont = italic
            ? UIFont(
                descriptor: font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor,
                size: font.pointSize
            )
            : font
        let resolvedFont = baseFont.withSize(fontSizeStore.scaled(baseFont.pointSize))

        tv.adjustsFontForContentSizeCategory = true
        tv.attributedText = NSAttributedString(string: text, attributes: [
            .font: resolvedFont,
            .paragraphStyle: para,
            .foregroundColor: color
        ])
    }
}
