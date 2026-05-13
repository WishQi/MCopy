import SwiftUI
import AppKit

struct CardView: View {
    let item: ClipboardItem
    let isSelected: Bool

    private let cardWidth: CGFloat    = 190
    private let titleHeight: CGFloat  = 40
    private let contentHeight: CGFloat = 115

    var body: some View {
        VStack(spacing: 0) {
            titleSection
            contentSection
            footerSection
        }
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected
                        ? Color(red: 0.25, green: 0.52, blue: 1.0)
                        : Color.white.opacity(0.1),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: isSelected ? 10 : 5, y: 3)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    // MARK: - Title section (colored top bar)

    private var titleSection: some View {
        HStack(spacing: 6) {
            Text(item.cardTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 11)
        .frame(height: titleHeight)
        .background(item.titleBarColor)
    }

    // MARK: - Content section (dark preview area)

    private var contentSection: some View {
        Group {
            switch item.type {
            case .image:
                imagePreview
            default:
                Text(item.textContent ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.78, green: 0.78, blue: 0.80))
                    .lineLimit(7)
                    .truncationMode(.tail)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: contentHeight)
        .background(Color(red: 0.14, green: 0.14, blue: 0.155))
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let data = item.imageData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: contentHeight)
                .clipped()
        } else {
            Image(systemName: "photo")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.2))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.14, green: 0.14, blue: 0.155))
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 4) {
            Image(systemName: item.typeIcon)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))

            if let count = item.charCount {
                Text(count)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            Text(item.timeAgo)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.12, green: 0.12, blue: 0.135))
    }
}

// MARK: - ClipboardItem display extensions

extension ClipboardItem {
    /// Short title shown in the colored top bar.
    var cardTitle: String {
        switch type {
        case .text:
            let first = (textContent ?? "")
                .components(separatedBy: "\n")
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
            return first.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : first
        case .url:
            if let url = URL(string: textContent ?? ""), let host = url.host {
                return host.replacingOccurrences(of: "www.", with: "")
            }
            return "Link"
        case .image:
            return "Image"
        case .file:
            let path = textContent?.components(separatedBy: "\n").first ?? ""
            let name = URL(fileURLWithPath: path).lastPathComponent
            return name.isEmpty ? "File" : name
        }
    }

    /// Title bar background color keyed to content type.
    var titleBarColor: Color {
        switch type {
        case .text:  return Color(red: 0.36, green: 0.38, blue: 0.44)   // brighter slate
        case .url:   return Color(red: 0.24, green: 0.50, blue: 0.85)   // bright blue
        case .image: return Color(red: 0.52, green: 0.30, blue: 0.72)   // bright purple
        case .file:  return Color(red: 0.22, green: 0.62, blue: 0.50)   // bright teal
        }
    }

    var typeIcon: String {
        switch type {
        case .text:  return "doc.text"
        case .image: return "photo"
        case .url:   return "link"
        case .file:  return "folder"
        }
    }

    var charCount: String? {
        guard type == .text || type == .url,
              let text = textContent, !text.isEmpty else { return nil }
        return "\(text.count) characters"
    }

    var timeAgo: String {
        let diff = Date().timeIntervalSince(timestamp)
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
