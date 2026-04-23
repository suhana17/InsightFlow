//
//  SummaryView.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 3/31/26.
//

import SwiftUI

struct SummaryView: View {
    @ObservedObject var speech: SpeechManager

    var body: some View {
        VStack {
            Text("Summary")
                .font(.largeTitle)
                .fontWeight(.bold)

            if !speech.summary.isEmpty {
                ScrollView {
                    FormattedTextView(text: speech.summary)
                        .lineSpacing(10)
                        .padding()
                }
            }
        }
    }
}

// MARK: - FormattedTextView

struct FormattedTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(for: line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Line splitting

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    // MARK: - Per-line rendering

    @ViewBuilder
    private func lineView(for line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            Spacer().frame(height: 2)

        } else if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
            // # Heading → very large
            let content = String(trimmed.dropFirst(2))
            Text(inlineFormatted(content))
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 6)

        } else if trimmed.hasPrefix("## ") {
            // ## Heading → medium large
            let content = String(trimmed.dropFirst(3))
            Text(inlineFormatted(content))
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 4)

        } else if trimmed.hasPrefix("### ") {
            // ### Heading → slightly larger than body
            let content = String(trimmed.dropFirst(4))
            Text(inlineFormatted(content))
                .font(.headline)
                .padding(.top, 2)

        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            // Bullet list item
            let content = String(trimmed.dropFirst(2))
            HStack(alignment: .top, spacing: 6) {
                Text("•").font(.body)
                Text(inlineFormatted(content)).font(.body)
            }

        } else if let number = leadingNumber(in: trimmed) {
            // Numbered list item (e.g. "1. Item")
            let afterNumber = trimmed.drop(while: { $0.isNumber || $0 == "." || $0 == " " })
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).").font(.body).foregroundColor(.secondary)
                Text(inlineFormatted(String(afterNumber))).font(.body)
            }

        } else {
            // Regular body text
            Text(inlineFormatted(trimmed))
                .font(.body)
        }
    }

    // MARK: - Inline formatting (**bold**, *italic*, ~~strikethrough~~, `code`, _italic_)

    private func inlineFormatted(_ input: String) -> AttributedString {
        var result = AttributedString()
        var remaining = input[input.startIndex...]

        while !remaining.isEmpty {

            // **bold**
            if let range = remaining.range(of: "**"),
               let closeRange = remaining[range.upperBound...].range(of: "**") {
                result += AttributedString(remaining[remaining.startIndex..<range.lowerBound])
                var bold = AttributedString(remaining[range.upperBound..<closeRange.lowerBound])
                bold.font = .body.bold()
                result += bold
                remaining = remaining[closeRange.upperBound...]
                continue
            }

            // ~~strikethrough~~
            if let range = remaining.range(of: "~~"),
               let closeRange = remaining[range.upperBound...].range(of: "~~") {
                result += AttributedString(remaining[remaining.startIndex..<range.lowerBound])
                var struck = AttributedString(remaining[range.upperBound..<closeRange.lowerBound])
                struck.strikethroughStyle = .single
                result += struck
                remaining = remaining[closeRange.upperBound...]
                continue
            }

            // `inline code`
            if let range = remaining.range(of: "`"),
               let closeRange = remaining[range.upperBound...].range(of: "`") {
                result += AttributedString(remaining[remaining.startIndex..<range.lowerBound])
                var code = AttributedString(remaining[range.upperBound..<closeRange.lowerBound])
                code.font = .system(.body, design: .monospaced)
                result += code
                remaining = remaining[closeRange.upperBound...]
                continue
            }

            // *italic* or _italic_
            for marker in ["*", "_"] {
                if remaining.hasPrefix(marker),
                   let closeRange = remaining[remaining.index(after: remaining.startIndex)...].range(of: marker) {
                    let nextChar = remaining.index(after: remaining.startIndex)
                    if remaining[nextChar...].hasPrefix(marker) { break }
                    result += AttributedString(remaining[remaining.startIndex..<remaining.startIndex])
                    var italic = AttributedString(remaining[remaining.index(after: remaining.startIndex)..<closeRange.lowerBound])
                    italic.font = .body.italic()
                    result += italic
                    remaining = remaining[closeRange.upperBound...]
                    break
                }
            }

            // No more matches — append the rest as plain text
            if result.characters.count == 0 || remaining == input[input.startIndex...] {
                result += AttributedString(String(remaining))
                break
            }
        }

        return result
    }

    // MARK: - Helpers

    private func leadingNumber(in string: String) -> Int? {
        let digits = string.prefix(while: { $0.isNumber })
        guard !digits.isEmpty,
              let n = Int(digits),
              string.dropFirst(digits.count).hasPrefix(". ") else { return nil }
        return n
    }
}
