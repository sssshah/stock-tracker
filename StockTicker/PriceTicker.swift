import SwiftUI

// MARK: - Quote Chip

struct QuoteChip: View {
    let quote: StockQuote
    var onSymbolHover: ((String?) -> Void)? = nil

    private var changeColor: Color {
        quote.isPositive
            ? Color(red: 0.2, green: 0.85, blue: 0.45)
            : Color(red: 1.0, green: 0.35, blue: 0.35)
    }

    // Don't render placeholder chips (price == 0)
    private var isPlaceholder: Bool { quote.currentPrice == 0 }

    var body: some View {
        HStack(spacing: 5) {
            Text(quote.symbol)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            if isPlaceholder {
                // Loading shimmer — just dashes
                Text("———")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.2))
            } else {
                Text(String(format: "$%.2f", quote.currentPrice))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 2) {
                    Image(systemName: quote.isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.2f%%", abs(quote.changePercent)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(changeColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onHover { hovering in
            onSymbolHover?(hovering ? quote.symbol : nil)
        }
    }
}

// MARK: - Separator

struct SeparatorDot: View {
    var body: some View {
        Text("·")
            .font(.system(size: 16, weight: .light))
            .foregroundColor(Color.white.opacity(0.25))
            .padding(.horizontal, 2)
    }
}

// MARK: - Price Ticker Row

struct PriceTickerRow: View {
    let quotes: [StockQuote]
    let isMarketOpen: Bool
    let sessionLabel: String
    let statusMessage: String
    var onSymbolHover: ((String?) -> Void)? = nil
    var isPaused: Bool = false

    @State private var isAnimating = false

    // Measure the badge so we know exactly how much to offset the scroll
    @State private var badgeWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .leading) {
            // Scrolling strip — inset by badge width + a small gap
            ScrollingContent(quotes: quotes, onSymbolHover: onSymbolHover, isPaused: isPaused)
                .padding(.leading, badgeWidth + 4)
                .clipped()

            // Session badge — pinned left, measured so scroll knows where to start
            sessionBadge
                .padding(.leading, 12)
                .background(
                    GeometryReader { g in
                        Color.clear.onAppear { badgeWidth = g.size.width + 12 }
                    }
                )
                // Blur-matched background so scrolling text never bleeds under the badge
                .background(.ultraThinMaterial)
                .zIndex(1)
        }
        .onAppear { isAnimating = true }
    }

    private var sessionBadge: some View {
        HStack(spacing: 6) {
            // Pulsing dot
            ZStack {
                Circle()
                    .fill(isMarketOpen ? Color(red: 0.2, green: 0.85, blue: 0.45) : Color.gray)
                    .frame(width: 6, height: 6)
                if isMarketOpen {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.45))
                        .frame(width: 6, height: 6)
                        .scaleEffect(isAnimating ? 2.4 : 1.0)
                        .opacity(isAnimating ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            }

            Text(sessionLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isMarketOpen
                    ? Color(red: 0.2, green: 0.85, blue: 0.45)
                    : .gray)
        }
    }
}

// MARK: - Scrolling Content

private struct PriceStripWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ScrollingContent: View {
    let quotes: [StockQuote]
    var onSymbolHover: ((String?) -> Void)? = nil
    var isPaused: Bool = false

    @State private var offset: CGFloat = 0
    @State private var stripWidth: CGFloat = 0
    @State private var timer: Timer? = nil
    @State private var paused: Bool = false

    private let scrollSpeed: CGFloat = 60

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                stripContent
                stripContent
            }
            .offset(x: offset)
            .onAppear { startScrolling() }
            .onChange(of: quotes.count) { _, _ in
                stopScrolling()
                offset = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    startScrolling()
                }
            }
            .onChange(of: isPaused) { _, p in paused = p }
            .onPreferenceChange(PriceStripWidthKey.self) { w in
                if w > 0 { stripWidth = w }
            }
        }
        .clipped()
    }

    private var stripContent: some View {
        HStack(spacing: 0) {
            ForEach(quotes) { quote in
                QuoteChip(quote: quote, onSymbolHover: onSymbolHover)
                SeparatorDot()
            }
        }
        .fixedSize()
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { stripWidth = g.size.width }
                    .preference(key: PriceStripWidthKey.self, value: g.size.width)
            }
        )
    }

    private func startScrolling() {
        guard quotes.count > 0 else { return }
        stopScrolling()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            stopScrolling()  // cancel any timer a prior asyncAfter already created
            guard quotes.count > 0 else { return }
            let interval = 1.0 / 60.0
            let step = scrollSpeed * interval
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                guard !paused else { return }
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
