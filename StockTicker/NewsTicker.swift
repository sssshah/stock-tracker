import SwiftUI
import AppKit

// MARK: - News Chip (clickable)

struct NewsChip: View {
    let item: NewsItem
    @State private var isHovered = false

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(item.datetime)
        if interval < 3600      { return "\(Int(interval / 60))m ago" }
        else if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        else                     { return "\(Int(interval / 86400))d ago" }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Ticker tag
            Text(item.related)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.4, green: 0.75, blue: 1.0))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(red: 0.4, green: 0.75, blue: 1.0).opacity(0.15))
                .cornerRadius(3)

            Text(item.headline)
                .font(.system(size: 11.5, weight: isHovered ? .medium : .regular))
                .foregroundColor(isHovered ? .white : Color.white.opacity(0.82))
                .lineLimit(1)
                // Underline on hover to signal it's clickable
                .underline(isHovered, color: Color.white.opacity(0.5))

            Text("—")
                .foregroundColor(Color.white.opacity(0.2))
                .font(.system(size: 11))

            Text(item.source)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))

            Text(timeAgo)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))

            // External link icon — appears on hover
            if isHovered {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.4, green: 0.75, blue: 1.0).opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        // Subtle highlight pill on hover
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(isHovered ? 0.07 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .onTapGesture {
            openURL(item.url)
        }
        .cursor(.pointingHand)
    }

    private func openURL(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        NotificationCenter.default.post(
            name: .newsArticleTapped,
            object: ["url": urlString, "headline": item.headline]
        )
    }
}

// MARK: - Pointing hand cursor modifier

struct PointingHandCursor: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.modifier(PointingHandCursor())
    }
}

// MARK: - Scrolling News Row

private struct NewsStripWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct NewsTickerRow: View {
    let items: [NewsItem]
    var filterLabel: String? = nil

    @State private var offset: CGFloat = 0
    @State private var stripWidth: CGFloat = 0
    @State private var timer: Timer? = nil
    @State private var isPaused = false

    private let scrollSpeed: CGFloat = 45

    var body: some View {
        HStack(spacing: 0) {
            // Pinned badge — "NEWS" normally, symbol name when filtered
            let badgeLabel = filterLabel ?? "NEWS"
            let badgeColor = filterLabel != nil
                ? Color(red: 1.0, green: 0.75, blue: 0.3)
                : Color(red: 0.4, green: 0.75, blue: 1.0)
            Text(badgeLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15))
                .cornerRadius(3)
                .padding(.leading, 12)
                .animation(.easeInOut(duration: 0.15), value: filterLabel)

            GeometryReader { _ in
                HStack(spacing: 0) {
                    newsStrip
                    newsStrip
                }
                .offset(x: offset)
                .onAppear { startScrolling() }
                .onDisappear { stopScrolling() }
                .onChange(of: items.count) { _, _ in
                    stopScrolling(); offset = 0; startScrolling()
                }
                .onChange(of: filterLabel) { _, _ in
                    stopScrolling(); offset = 0; startScrolling()
                }
                .onPreferenceChange(NewsStripWidthKey.self) { w in
                    if w > 0 { stripWidth = w }
                }
            }
            .clipped()
        }
        .onHover { hovering in isPaused = hovering }
    }

    private var newsStrip: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                NewsChip(item: item)
                Text("  ◆  ")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.12))
            }
        }
        .fixedSize()
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { stripWidth = g.size.width }
                    .preference(key: NewsStripWidthKey.self, value: g.size.width)
            }
        )
    }

    private func startScrolling() {
        guard !items.isEmpty else { return }
        stopScrolling()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            stopScrolling()  // cancel any timer a prior asyncAfter already created
            guard !items.isEmpty else { return }
            let interval = 1.0 / 60.0
            let step = scrollSpeed * interval
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                guard !isPaused else { return }
                offset -= step
                if stripWidth > 0 && abs(offset) >= stripWidth {
                    offset = 0
                }
            }
        }
    }

    private func stopScrolling() {
        timer?.invalidate()
        timer = nil
    }
}
