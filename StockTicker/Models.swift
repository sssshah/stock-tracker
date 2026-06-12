import Foundation

// MARK: - Stock Quote

struct StockQuote: Identifiable {
    let id = UUID()
    let symbol: String
    var currentPrice: Double
    var previousClose: Double
    var open: Double
    var high: Double
    var low: Double
    var timestamp: Date

    var change: Double { currentPrice - previousClose }
    var changePercent: Double {
        guard previousClose != 0 else { return 0 }
        return (change / previousClose) * 100
    }
    var isPositive: Bool { change >= 0 }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }

    static let placeholder = StockQuote(
        symbol: "---", currentPrice: 0, previousClose: 0,
        open: 0, high: 0, low: 0, timestamp: Date()
    )
}

// MARK: - Finnhub Quote Response

struct FinnhubQuoteResponse: Decodable {
    let c: Double
    let d: Double?
    let dp: Double?
    let h: Double
    let l: Double
    let o: Double
    let pc: Double
    let t: TimeInterval
}

// MARK: - News Item

struct NewsItem: Identifiable {
    let id: Int
    let headline: String
    let source: String
    let url: String
    let datetime: Date
    let summary: String
    let related: String

    var displayText: String { "[\(related)] \(headline)  —  \(source)" }
}

// MARK: - Finnhub News Response
// `category` is included — Finnhub returns values like:
//   "company news"  → specific to the queried company
//   "top news"      → broad market/general news
//   "forex"         → FX/macro news
//   "crypto"        → crypto news
//   "merger"        → M&A news (high value)

struct FinnhubNewsItem: Decodable {
    let id: Int
    let headline: String
    let source: String
    let url: String
    let datetime: TimeInterval
    let summary: String
    let related: String
    let category: String   // "company news", "top news", etc.
}

// MARK: - Market Status Response

struct FinnhubMarketStatusResponse: Decodable {
    let isOpen: Bool
    let holiday: String?
    let session: String?
}
