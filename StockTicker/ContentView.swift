import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var isHovered = false
    @State private var showPortfolioEditor = false
    @State private var isMaximized = false

    var body: some View {
        ZStack {

            // ── Layer 1: Blur — blends whatever is behind the window ────
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // ── Layer 2: Very light tint — barely there ─────────────────
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.18))

            // ── Layer 3: Glossy sheen — bright gradient top-to-bottom ───
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),  // bright top edge
                            Color.white.opacity(0.04),  // fades to near-clear
                            Color.black.opacity(0.08),  // subtle darkening at bottom
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // ── Layer 4: Top highlight line — sharp glass edge ──────────
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                Spacer()
            }

            // ── Layer 5: Bottom edge shadow line ────────────────────────
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.25))
                    .frame(height: 1)
            }

            // ── Ticker strip ─────────────────────────────────────────────
            VStack(spacing: 0) {

                // Row 1: Prices
                Group {
                    if viewModel.isHolidayOrWeekend || (viewModel.formattedQuotes().isEmpty && !viewModel.isLoading) {
                        closedView
                    } else {
                        PriceTickerRow(
                            quotes: viewModel.isLoading ? placeholderQuotes : viewModel.formattedQuotes(),
                            isMarketOpen: viewModel.isMarketOpen,
                            sessionLabel: viewModel.sessionLabel,
                            statusMessage: viewModel.statusMessage
                        )
                    }
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)

                // Divider — slightly glowing
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear,
                                     Color.white.opacity(0.18),
                                     Color.white.opacity(0.18),
                                     Color.clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)

                // Row 2: News
                Group {
                    if viewModel.newsItems.isEmpty {
                        loadingNewsView
                    } else {
                        NewsTickerRow(items: viewModel.newsItems)
                    }
                }
                .frame(height: 28)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: 80)

            // Hover controls
            if isHovered {
                hoverControls
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(minWidth: 1200, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isHovered = hovering }
        }
        .popover(isPresented: $showPortfolioEditor, arrowEdge: .top) {
            PortfolioEditorView(vm: viewModel, isPresented: $showPortfolioEditor)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPortfolioEditor)) { _ in
            showPortfolioEditor = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshTicker)) { _ in
            Task { await viewModel.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidMaximize)) { _ in
            isMaximized = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidRestore)) { _ in
            isMaximized = false
        }
    }

    // MARK: - Hover Controls — single frosted pill, high contrast

    private var hoverControls: some View {
        HStack(spacing: 0) {
            // Maximize / restore button
            pillButton(
                icon: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                color: Color(red: 0.4, green: 0.75, blue: 1.0),
                help: isMaximized ? "Restore" : "Full width"
            ) {
                NotificationCenter.default.post(name: .toggleMaximize, object: nil)
            }

            pillDivider

            // Refresh button
            pillButton(
                icon: "arrow.clockwise",
                color: Color(red: 0.2, green: 0.85, blue: 0.55),
                help: "Refresh now"
            ) {
                Task { await viewModel.refresh() }
            }

            pillDivider

            // Quit button
            pillButton(
                icon: "xmark",
                color: Color(red: 1.0, green: 0.45, blue: 0.45),
                help: "Quit"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .background(
            ZStack {
                // Pill background — dark frosted
                Capsule()
                    .fill(Color.black.opacity(0.65))
                // Gloss top edge
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .padding(.trailing, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func pillButton(icon: String, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 26)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 0.5, height: 16)
    }

    // MARK: - Sub-views

    private var closedView: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.gray).frame(width: 6, height: 6)
            Text("MARKET CLOSED")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            if let last = viewModel.lastUpdated {
                Text("· Last updated \(relativeDateString(last))")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            if !viewModel.formattedQuotes().isEmpty {
                ForEach(viewModel.formattedQuotes().prefix(4)) { quote in
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
            Text(viewModel.isLoading ? "Fetching market data…" : "No news available")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(height: 28).frame(maxWidth: .infinity)
    }

    private var placeholderQuotes: [StockQuote] {
        viewModel.symbols.map { StockQuote(symbol: $0, currentPrice: 0, previousClose: 0,
                                           open: 0, high: 0, low: 0, timestamp: Date()) }
    }

    private func relativeDateString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - NSVisualEffectView wrapper

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
