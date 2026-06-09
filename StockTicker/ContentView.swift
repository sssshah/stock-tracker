import SwiftUI

struct ContentView: View {
    @StateObject private var vm = TickerViewModel()
    @State private var isHovered = false
    @State private var showPortfolioEditor = false

    var body: some View {
        ZStack {
            // Frosted glass background — sits on top of whatever is behind the window
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Dark tint over the blur — lighter for more transparency
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))

            // Top highlight line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Spacer()
            }

            // ── Ticker strip ───────────────────────────────────────────
            VStack(spacing: 0) {

                // ── Row 1: Prices — warm dark ribbon ──────────────────
                Group {
                    if vm.isHolidayOrWeekend || (vm.formattedQuotes().isEmpty && !vm.isLoading) {
                        closedView
                    } else {
                        PriceTickerRow(
                            quotes: vm.isLoading ? placeholderQuotes : vm.formattedQuotes(),
                            isMarketOpen: vm.isMarketOpen,
                            sessionLabel: vm.sessionLabel,
                            statusMessage: vm.statusMessage
                        )
                    }
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)

                // ── Row 2: News — cool blue-tinted ribbon ─────────────
                Group {
                    if vm.newsItems.isEmpty {
                        loadingNewsView
                    } else {
                        NewsTickerRow(items: vm.newsItems)
                    }
                }
                .frame(height: 28)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.06),
                            Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.02)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: 80)

            if isHovered {
                hoverControls
            }
        }
        .frame(minWidth: 1200, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .popover(isPresented: $showPortfolioEditor, arrowEdge: .top) {
            PortfolioEditorView(vm: vm, isPresented: $showPortfolioEditor)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPortfolioEditor)) { _ in
            showPortfolioEditor = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshTicker)) { _ in
            Task { await vm.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidMaximize)) { _ in }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidRestore)) { _ in }
    }

    // MARK: - Hover Controls

    private var hoverControls: some View {
        HStack(spacing: 6) {
            Button(action: { Task { await vm.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Refresh now")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(.trailing, 10)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    // MARK: - Sub-views

    private var closedView: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.gray).frame(width: 6, height: 6)
            Text("MARKET CLOSED")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            if let last = vm.lastUpdated {
                Text("· Last updated \(relativeDateString(last))")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            if !vm.formattedQuotes().isEmpty {
                ForEach(vm.formattedQuotes().prefix(4)) { quote in
                    QuoteChip(quote: quote).opacity(0.6)
                }
                Text("…").foregroundColor(Color.white.opacity(0.3)).font(.system(size: 12))
            }
        }
        .frame(height: 36).frame(maxWidth: .infinity)
    }

    private var loadingNewsView: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.5).tint(.white)
            Text(vm.isLoading ? "Fetching market data…" : "No news available")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(height: 28).frame(maxWidth: .infinity)
    }

    private var placeholderQuotes: [StockQuote] {
        vm.symbols.map { StockQuote(symbol: $0, currentPrice: 0, previousClose: 0,
                                    open: 0, high: 0, low: 0, timestamp: Date()) }
    }

    private func relativeDateString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - NSVisualEffectView wrapper for SwiftUI

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
