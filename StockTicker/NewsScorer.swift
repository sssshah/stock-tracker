import Foundation

// MARK: - News Priority Scorer
// Scores each news item so the most impactful, relevant stories surface first.
// No hardcoded company name lookups — uses Finnhub's own category field
// plus the existing specificity score to down-rank generic market news.

struct NewsScorer {

    // MARK: - Score

    static func score(_ item: FinnhubNewsItem, forSymbol symbol: String) -> Double {
        let keywordScore  = keywordWeight(item) * 40
        let recencyScore  = recency(item.datetime) * 35
        let sourceScore   = sourceTier(item.source) * 15
        let specificScore = specificity(item.related) * 10

        // Category bonus/penalty — applied on top of base score
        // "company news" is the most specific Finnhub category
        // "top news" / "general" tend to be broad market pieces
        let categoryMod   = categoryModifier(item.category)

        return (keywordScore + recencyScore + sourceScore + specificScore) * categoryMod
    }

    // MARK: - Category Modifier
    // Multiplier applied to the total score based on Finnhub's category tag.
    // "company news" gets a boost; broad categories get penalized.

    private static func categoryModifier(_ category: String) -> Double {
        switch category.lowercased() {
        case "company news":        return 1.20  // clearly about this company
        case "merger":              return 1.15  // high value corporate event
        case "top news":            return 0.75  // broad market, likely mis-tagged
        case "forex", "crypto":     return 0.50  // almost never relevant to equities
        case "general":             return 0.70  // generic, low relevance
        default:                    return 1.00  // unknown — neutral
        }
    }

    // MARK: - Keyword Weight

    private static func keywordWeight(_ item: FinnhubNewsItem) -> Double {
        let text = "\(item.headline) \(item.summary)".lowercased()

        let highImpact = [
            "earnings","beat","miss","eps","revenue","guidance","raised","lowered",
            "fda","approval","approved","rejected","clinical trial","nda","pdufa",
            "merger","acquisition","acquired","buyout","takeover","deal",
            "dividend","buyback","recall","investigation","lawsuit","sec filing","doj",
            "bankruptcy","default","downgrade","upgrade","target price","price target"
        ]
        let mediumImpact = [
            "analyst","forecast","outlook","raises","cuts","initiates","reiterates",
            "partnership","contract","launch","product","ceo","cfo","appointed","resigned"
        ]

        for kw in highImpact   { if text.contains(kw) { return 1.0 } }
        for kw in mediumImpact { if text.contains(kw) { return 0.6 } }
        return 0.3
    }

    // MARK: - Recency

    private static func recency(_ timestamp: TimeInterval) -> Double {
        let ageHours = -Date(timeIntervalSince1970: timestamp).timeIntervalSinceNow / 3600
        switch ageHours {
        case ..<1:  return 1.0
        case ..<3:  return 0.8
        case ..<6:  return 0.6
        case ..<12: return 0.4
        case ..<24: return 0.2
        default:    return 0.1
        }
    }

    // MARK: - Source Tier

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

    // MARK: - Specificity

    private static func specificity(_ related: String) -> Double {
        let count = related
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
        return count > 0 ? 1.0 / Double(count) : 1.0
    }
}
