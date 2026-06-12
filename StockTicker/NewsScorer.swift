import Foundation

// MARK: - News Priority Scorer (v1.1)
//
// Changes from v1.0:
//  - Keyword scoring is now ADDITIVE — more matching keywords = higher score
//  - Price movement keywords added ("surges", "plunges", "rallies" etc.)
//  - Recency decays SLOWER for high-impact stories (earnings stay relevant longer)
//  - Portfolio match bonus: ×1.1 if symbol appears in headline or summary
//  - Source tier and category modifier unchanged

struct NewsScorer {

    // MARK: - Score

    static func score(_ item: FinnhubNewsItem, forSymbol symbol: String) -> Double {
        let kw             = keywordScore(item)
        let rec            = recency(item.datetime, keywordWeight: kw)
        let sourceScore    = sourceTier(item.source)
        let specificScore  = specificity(item.related)
        let catMod         = categoryModifier(item.category)
        let matchBonus     = portfolioMatchBonus(item, symbol: symbol)

        return ((kw * 40) + (rec * 35) + (sourceScore * 15) + (specificScore * 10))
               * catMod
               * matchBonus
    }

    // MARK: - Keyword Score (ADDITIVE — v1.1)
    // Count all matching keywords, normalize to 0–1.
    // More matching keywords = higher score, capped at 1.0.
    // A story with 3 high-impact keywords scores much higher than one with 1.

    static func keywordScore(_ item: FinnhubNewsItem) -> Double {
        let text = "\(item.headline) \(item.summary)".lowercased()

        let highImpact: [String: Double] = [
            // Fundamentals
            "earnings": 1.0, "beat": 1.0, "miss": 1.0, "eps": 1.0,
            "revenue": 1.0, "guidance": 1.0, "raised": 1.0, "lowered": 1.0,
            // Price movement — NEW in v1.1
            "surges": 1.0, "plunges": 1.0, "rallies": 1.0, "soars": 1.0,
            "tumbles": 1.0, "jumps": 1.0, "slides": 1.0, "spikes": 1.0,
            "selloff": 1.0, "sell-off": 1.0, "crashes": 1.0, "skyrockets": 1.0,
            // Regulatory / pharma
            "fda": 1.0, "approval": 1.0, "approved": 1.0, "rejected": 1.0,
            "clinical trial": 1.0, "nda": 1.0, "pdufa": 1.0,
            // Corporate events
            "merger": 1.0, "acquisition": 1.0, "acquired": 1.0,
            "buyout": 1.0, "takeover": 1.0, "deal": 1.0,
            "dividend": 1.0, "buyback": 1.0,
            // Negative events
            "recall": 1.0, "investigation": 1.0, "lawsuit": 1.0,
            "sec filing": 1.0, "doj": 1.0, "bankruptcy": 1.0, "default": 1.0,
            // Analyst actions
            "downgrade": 1.0, "upgrade": 1.0,
            "target price": 1.0, "price target": 1.0,
        ]

        let mediumImpact: [String: Double] = [
            "analyst": 0.6, "forecast": 0.6, "outlook": 0.6,
            "raises": 0.6, "cuts": 0.6, "initiates": 0.6, "reiterates": 0.6,
            "partnership": 0.6, "contract": 0.6, "launch": 0.6, "product": 0.6,
            "ceo": 0.6, "cfo": 0.6, "appointed": 0.6, "resigned": 0.6,
        ]

        var totalScore = 0.0
        var matchCount = 0

        for (kw, weight) in highImpact {
            if text.contains(kw) {
                totalScore += weight
                matchCount += 1
            }
        }
        for (kw, weight) in mediumImpact {
            if text.contains(kw) {
                totalScore += weight
                matchCount += 1
            }
        }

        if matchCount == 0 { return 0.3 }  // no keywords — baseline score

        // Normalize: first keyword gives most value, diminishing returns after
        // Score = 1 - (1 / (1 + totalScore)) mapped to 0.3–1.0 range
        let normalized = 0.3 + (0.7 * (1.0 - 1.0 / (1.0 + totalScore)))
        return min(normalized, 1.0)
    }

    // MARK: - Recency (v1.1 — slow decay for high-impact stories)
    // High-impact stories (keyword score ≥ 0.8) decay 50% slower than routine ones.
    // An earnings report from 12 hours ago stays relevant longer than a routine note.

    private static func recency(_ timestamp: TimeInterval, keywordWeight: Double) -> Double {
        let ageHours = -Date(timeIntervalSince1970: timestamp).timeIntervalSinceNow / 3600

        // Base decay
        let base: Double
        switch ageHours {
        case ..<1:   base = 1.0
        case ..<3:   base = 0.8
        case ..<6:   base = 0.6
        case ..<12:  base = 0.4
        case ..<24:  base = 0.2
        case ..<48:  base = 0.12
        default:     base = 0.05
        }

        // High-impact stories decay slower — multiply decay penalty by 0.6
        // so they stay higher in the feed longer
        if keywordWeight >= 0.8 && ageHours >= 3 {
            let slowBase: Double
            switch ageHours {
            case ..<6:   slowBase = 0.85
            case ..<12:  slowBase = 0.70
            case ..<24:  slowBase = 0.45
            case ..<48:  slowBase = 0.25
            default:     slowBase = 0.10
            }
            return slowBase
        }

        return base
    }

    // MARK: - Portfolio Match Bonus (NEW in v1.1)
    // ×1.1 if the symbol (or its ticker) appears in the headline or summary.
    // Directly boosts stories that are explicitly about the user's holding.

    private static func portfolioMatchBonus(_ item: FinnhubNewsItem, symbol: String) -> Double {
        let text = "\(item.headline) \(item.summary)".lowercased()
        return text.contains(symbol.lowercased()) ? 1.1 : 1.0
    }

    // MARK: - Category Modifier (unchanged)

    private static func categoryModifier(_ category: String) -> Double {
        switch category.lowercased() {
        case "company news": return 1.20
        case "merger":       return 1.15
        case "top news":     return 0.75
        case "general":      return 0.70
        case "forex", "crypto": return 0.50
        default:             return 1.00
        }
    }

    // MARK: - Source Tier (unchanged)

    private static func sourceTier(_ source: String) -> Double {
        let s = source.lowercased().trimmingCharacters(in: .whitespaces)
        let tier1Exact    = ["ap", "reuters", "bloomberg", "cnbc", "sec"]
        let tier1Contains = ["wall street journal", "wsj", "financial times", "associated press"]
        let tier2Contains = ["marketwatch", "barron", "forbes", "fortune",
                             "business insider", "yahoo finance", "investopedia",
                             "motley fool", "benzinga"]
        if tier1Exact.contains(s)                 { return 1.0 }
        for t in tier1Contains { if s.contains(t) { return 1.0 } }
        for t in tier2Contains { if s.contains(t) { return 0.6 } }
        return 0.3
    }

    // MARK: - Specificity (unchanged)

    private static func specificity(_ related: String) -> Double {
        let count = related
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
        return count > 0 ? 1.0 / Double(count) : 1.0
    }
}
