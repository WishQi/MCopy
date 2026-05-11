import SwiftUI
import SwiftData

struct ClipboardHistoryView: View {
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @AppStorage(PanelPosition.defaultsKey) private var panelPositionRaw: String = PanelPosition.bottom.rawValue
    @State private var selectedIndex: Int = 0
    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool

    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void

    private var panelPosition: PanelPosition {
        PanelPosition(rawValue: panelPositionRaw) ?? .bottom
    }

    private var displayItems: [ClipboardItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Array(items.prefix(50)) }
        return items
            .filter { ($0.textContent ?? "").localizedCaseInsensitiveContains(q) }
            .prefix(50)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            if displayItems.isEmpty {
                emptyState
            } else if panelPosition.isVertical {
                verticalCardScroll
            } else {
                cardScroll
            }
        }
        // NSVisualEffectView with corner radius on its own layer —
        // avoids SwiftUI Material's intrinsic 1px vibrancy edge highlight.
        .background(
            VisualEffectView(material: .menu, blendingMode: .behindWindow, cornerRadius: 16)
        )
        .preferredColorScheme(.dark)
        .onAppear { isSearchFocused = true }
        .onChange(of: searchQuery) { _, _ in selectedIndex = 0 }
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            TextField("Search clipboard", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .focused($isSearchFocused)
                .onKeyPress(.escape) {
                    if !searchQuery.isEmpty { searchQuery = ""; return .handled }
                    onDismiss()
                    return .handled
                }
                .onKeyPress(.return) { pasteSelected(); return .handled }
                .onKeyPress(.leftArrow) {
                    guard !panelPosition.isVertical else { return .ignored }
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    guard !panelPosition.isVertical else { return .ignored }
                    moveSelection(by: +1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard panelPosition.isVertical else { return .ignored }
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard panelPosition.isVertical else { return .ignored }
                    moveSelection(by: +1)
                    return .handled
                }
                .onKeyPress(keys: ["c"]) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    pasteSelected()
                    return .handled
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            Text("⌘⇧V")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var cardScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        CardView(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .onTapGesture { onPaste(item) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private var verticalCardScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        CardView(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .onTapGesture { onPaste(item) }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        let isSearching = !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(spacing: 8) {
            Spacer()
            Image(systemName: isSearching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.15))
            Text(isSearching ? "No matches" : "No clipboard history yet")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.25))
            Spacer()
        }
    }

    // MARK: - Actions

    private func pasteSelected() {
        guard let item = displayItems[safe: selectedIndex] else { return }
        onPaste(item)
    }

    private func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        guard newIndex >= 0, newIndex < displayItems.count else { return }
        selectedIndex = newIndex
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        if cornerRadius > 0 {
            v.wantsLayer = true
            v.layer?.cornerRadius = cornerRadius
            v.layer?.cornerCurve = .continuous
            v.layer?.masksToBounds = true
        }
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Helpers

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
