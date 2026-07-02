import SwiftUI
import Combine

@MainActor
class TickerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var quotes: [String: StockQuote] = [:]
    @Published var newsItems: [NewsItem] = []
    @Published var isMarketOpen: Bool = false
    @Published var isHolidayOrWeekend: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var statusMessage: String = "Loading…"
    @Published var isLoading: Bool = true

    // MARK: - Config

    @Published var symbols: [String] {
        didSet { UserDefaults.standard.set(symbols, forKey: "portfolio_symbols") }
    }

    let refreshInterval: TimeInterval = 60
    private var refreshTask: Task<Void, Never>?
    private var lastNewsFetch: Date? = nil   // separate tracker so edits always re-fetch

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "portfolio_symbols")
        self.symbols = saved ?? ["LLY", "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "TSLA", "SPY"]
        Task { await start() }
    }

    // MARK: - Symbol Management

    func addSymbol(_ symbol: String) {
        let upper = symbol.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty, !symbols.contains(upper) else { return }
        symbols.append(upper)
    }

    func removeSymbol(_ symbol: String) {
        symbols.removeAll { $0 == symbol }
        quotes.removeValue(forKey: symbol)
    }

    func moveSymbols(from offsets: IndexSet, to destination: Int) {
        symbols.move(fromOffsets: offsets, toOffset: destination)
    }

    func reloadAfterEdit() {
        isLoading = true  // prevent brief closedView flash that resets @State stripWidth
        quotes = [:]
        lastNewsFetch = nil  // force news re-fetch on next open market refresh
        Task { await refresh() }
    }

    // MARK: - Lifecycle

    func start() async {
        await refresh()
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    // MARK: - Refresh

    func refresh() async {
        if quotes.isEmpty { isLoading = true }  // only show loading spinner on first fetch

        let shouldFetch = await checkMarketAvailability()
        guard shouldFetch else {
            updateStatusForClosedMarket()
            isLoading = false
            return
        }

        // Fetch quotes
        let newQuotes = await FinnhubService.shared.fetchAllQuotes(symbols: symbols)
        if !newQuotes.isEmpty { quotes = newQuotes }

        // Fetch news — every 5 min OR if never fetched / forced
        let needsNews = lastNewsFetch == nil ||
            Date().timeIntervalSince(lastNewsFetch!) > 300
        if needsNews {
            if let news = try? await FinnhubService.shared.fetchNews(symbols: symbols) {
                newsItems = news
                lastNewsFetch = Date()
                #if DEBUG
                print("News loaded: \(news.count) items")
                #endif
            } else {
                #if DEBUG
                print("News fetch returned nil")
                #endif
            }
        }

        lastUpdated = Date()
        isLoading = false
        isMarketOpen = true
        statusMessage = "Live · \(timeString(Date()))"
    }

    // MARK: - Market Hours

    private func checkMarketAvailability() async -> Bool {
        if isWeekend() {
            isHolidayOrWeekend = true
            return false
        }
        do {
            let status = try await FinnhubService.shared.fetchMarketStatus()
            if let holiday = status.holiday, !holiday.isEmpty {
                isHolidayOrWeekend = true
                return false
            }
            isHolidayOrWeekend = false
            isMarketOpen = status.isOpen
            return true
        } catch {
            isHolidayOrWeekend = false
            return !isWeekend()
        }
    }

    private func isWeekend() -> Bool {
        let w = Calendar.current.component(.weekday, from: Date())
        return w == 1 || w == 7
    }

    private func updateStatusForClosedMarket() {
        isMarketOpen = false
        let w = Calendar.current.component(.weekday, from: Date())
        statusMessage = (w == 1 || w == 7) ? "Market closed · Weekend" : "Market closed · Holiday"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    func formattedQuotes() -> [StockQuote] {
        symbols.compactMap { quotes[$0] }
    }

    var sessionLabel: String {
        guard isMarketOpen else { return "CLOSED" }
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let c = cal.dateComponents([.hour, .minute], from: Date())
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if m >= 240 && m < 570  { return "PRE" }
        if m >= 570 && m < 960  { return "OPEN" }
        if m >= 960 && m < 1200 { return "AFTER" }
        return "CLOSED"
    }
}
