import Foundation

class FinnhubService {

    static let shared = FinnhubService()

    // API key is loaded from Info.plist → set via Config.xcconfig
    // Never hardcode keys in source — see Config.xcconfig
    private let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "FinnhubAPIKey") as? String,
              !key.isEmpty else {
            assertionFailure("FinnhubAPIKey missing from Info.plist. Check Config.xcconfig.")
            return ""
        }
        return key
    }()
    private let baseURL = "https://finnhub.io/api/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    // MARK: - Market Status

    func fetchMarketStatus() async throws -> FinnhubMarketStatusResponse {
        let url = URL(string: "\(baseURL)/stock/market-status?exchange=US&token=\(apiKey)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(FinnhubMarketStatusResponse.self, from: data)
    }

    // MARK: - Quote

    func fetchQuote(symbol: String) async throws -> StockQuote {
        let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)&token=\(apiKey)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
        guard response.c > 0 else { throw FinnhubError.noData(symbol: symbol) }
        return StockQuote(
            symbol: symbol,
            currentPrice: response.c,
            previousClose: response.pc,
            open: response.o,
            high: response.h,
            low: response.l,
            timestamp: Date(timeIntervalSince1970: response.t)
        )
    }

    func fetchAllQuotes(symbols: [String]) async -> [String: StockQuote] {
        var results: [String: StockQuote] = [:]
        for symbol in symbols {
            do {
                let quote = try await fetchQuote(symbol: symbol)
                results[symbol] = quote
            } catch {
                print("Quote fetch failed for \(symbol): \(error)")
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return results
    }

    // MARK: - News
    //
    // Pipeline per symbol:
    //   1. Fetch /company-news
    //   2. Filter to items where Finnhub's `related` field contains this symbol
    //   3. Score ALL filtered items
    //   4. Take top 4 per symbol
    //
    // Cross-symbol dedup — headline appears for multiple symbols:
    //   - Check headline prominence: does the headline mention symbol A but not B?
    //     If so, keep A regardless of score.
    //   - Only use score as tiebreaker when neither or both symbols appear
    //     in the headline.
    //   This prevents "Apple kicks off WWDC" from being stolen by MSFT
    //   just because MSFT was briefly mentioned and scored marginally higher.

    func fetchNews(symbols: [String]) async throws -> [NewsItem] {
        let calendar = Calendar.current
        let today = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let toDate   = formatter.string(from: today)
        let fromDate = formatter.string(from: sevenDaysAgo)

        // headline key → (item, symbol, score)
        var bestByHeadline: [String: (FinnhubNewsItem, String, Double)] = [:]

        for symbol in symbols {
            let urlStr = "\(baseURL)/company-news?symbol=\(symbol)&from=\(fromDate)&to=\(toDate)&token=\(apiKey)"
            guard let url = URL(string: urlStr) else { continue }

            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse {
                    print("News HTTP \(http.statusCode) for \(symbol)")
                    guard http.statusCode == 200 else { continue }
                }

                let items = try JSONDecoder().decode([FinnhubNewsItem].self, from: data)

                // Filter: Finnhub must have tagged this symbol in `related`
                let relevant = items.filter { item in
                    item.related.uppercased()
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .contains(symbol.uppercased())
                }
                print("News: \(items.count) raw → \(relevant.count) tagged for \(symbol)")

                // Score all, sort best first
                let scored = relevant
                    .map { ($0, symbol, NewsScorer.score($0, forSymbol: symbol)) }
                    .sorted { $0.2 > $1.2 }

                var countForSymbol = 0
                for (item, sym, score) in scored {
                    guard countForSymbol < 4 else { break }

                    let headlineKey = item.headline.lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let existing = bestByHeadline[headlineKey] {
                        // Headline prominence tiebreaker:
                        // Check which symbol appears in the headline text.
                        // The one that does wins, regardless of score.
                        // Only fall back to score if both or neither appear.
                        let headline = item.headline.lowercased()
                        let newInHeadline      = headline.contains(sym.lowercased())
                        let existingInHeadline = headline.contains(existing.1.lowercased())

                        let shouldReplace: Bool
                        if newInHeadline && !existingInHeadline {
                            // New symbol is in headline, existing isn't → reassign
                            shouldReplace = true
                        } else if existingInHeadline && !newInHeadline {
                            // Existing symbol is in headline, new isn't → keep existing
                            shouldReplace = false
                        } else {
                            // Both or neither in headline → use score
                            shouldReplace = score > existing.2
                        }

                        if shouldReplace {
                            bestByHeadline[headlineKey] = (item, sym, score)
                            print("News: reassigned '\(item.headline.prefix(60))' from \(existing.1) → \(sym)")
                        }
                    } else {
                        bestByHeadline[headlineKey] = (item, sym, score)
                    }
                    countForSymbol += 1
                }

            } catch {
                print("News fetch failed for \(symbol): \(error)")
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let result = bestByHeadline.values
            .sorted { $0.2 > $1.2 }
            .map { (item, symbol, _) in
                NewsItem(
                    id: item.id,
                    headline: item.headline,
                    source: item.source,
                    url: item.url,
                    datetime: Date(timeIntervalSince1970: item.datetime),
                    summary: item.summary,
                    related: symbol
                )
            }

        // Display cap: max 3 stories per symbol shown in the feed.
        // Internal pipeline uses 4 candidates so dedup has backups to work with,
        // but no single company dominates the ribbon.
        var countPerSymbol: [String: Int] = [:]
        let capped = result.filter { item in
            let count = countPerSymbol[item.related, default: 0]
            guard count < 3 else { return false }
            countPerSymbol[item.related] = count + 1
            return true
        }

        print("News loaded: \(capped.count) items (display-capped at 3/symbol)")
        return capped
    }
}

enum FinnhubError: LocalizedError {
    case noData(symbol: String)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .noData(let s): return "No data for \(s)"
        case .invalidResponse: return "Invalid response"
        }
    }
}
