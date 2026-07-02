import SwiftUI
import AppKit

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                aboutHeader
                infoSection("Data Sources", rows: [
                    InfoRow("Price Data",
                            "Finnhub.io — Real-time US equity quotes delayed ~15–20 minutes on free plan. Covers stocks, ETFs, and major indices."),
                    InfoRow("News Feed",
                            "Finnhub Company News API — Stories are fetched per-symbol and filtered to items where Finnhub's own 'related' field explicitly contains the queried symbol."),
                    InfoRow("Market Status",
                            "Finnhub Market Status API — Checked on every refresh cycle to detect US market holidays. Weekend detection is done locally.")
                ])
                infoSection("Refresh Cadence", rows: [
                    InfoRow("Stock Prices",      "Every 60 seconds during market hours (weekdays, non-holidays)."),
                    InfoRow("News Stories",       "Every 5 minutes — fetched independently of prices to conserve API quota."),
                    InfoRow("Market Closed",      "No fetches on weekends or US market holidays. Last known prices are shown dimmed with a \"Market Closed\" indicator."),
                    InfoRow("Price Delay",        "Quotes are delayed ~15–20 minutes on Finnhub's free tier. They are not real-time."),
                    InfoRow("API Rate Limit",     "Price and news calls are staggered with small delays between symbols to stay within API limits.")
                ])
                scoringSection
                infoSection("Limitations & Disclaimers", rows: [
                    InfoRow("Requirements",           "macOS 14 (Sonoma) or later."),
                    InfoRow("Not Financial Advice",   "This app is for informational purposes only. Nothing displayed constitutes investment advice."),
                    InfoRow("Delayed Prices",         "All prices are delayed ~15–20 minutes. Do not use for time-sensitive trading decisions."),
                    InfoRow("News Accuracy",          "News is sourced from Finnhub's aggregation. Story relevance is determined by Finnhub's tagging — occasional misattribution may occur."),
                    InfoRow("News Links",             "Tapping a headline opens the article in an in-app viewer. The app runs as a background overlay and cannot open your default browser directly."),
                    InfoRow("Max Portfolio",          "Up to 10 symbols supported. More symbols increase API call frequency."),
                    InfoRow("Data Provider",          "finnhub.io", isLink: true, linkURL: "https://finnhub.io")
                ])
                aboutFooter
            }
            .padding(24)
        }
        .background(Color(red: 0.051, green: 0.059, blue: 0.078))
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
    }

    // MARK: Header

    private var aboutHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.118, green: 0.533, blue: 0.898),
                                 Color(red: 0.486, green: 0.302, blue: 1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 44, height: 44)
                    .cornerRadius(10)
                    Text("📈").font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stock Ticker")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Data sources, refresh cadence & news scoring assumptions")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.420, green: 0.447, blue: 0.510))
                }
            }
            .padding(.bottom, 20)
            Rectangle()
                .fill(Color(red: 0.118, green: 0.133, blue: 0.188))
                .frame(height: 1)
        }
    }

    // MARK: Generic info section

    private func infoSection(_ title: String, rows: [InfoRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.294, green: 0.620, blue: 0.973))
                .kerning(1.0)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    infoRowView(row)
                    if idx < rows.count - 1 {
                        Rectangle()
                            .fill(Color(red: 0.102, green: 0.118, blue: 0.173))
                            .frame(height: 1)
                    }
                }
            }
            .background(Color(red: 0.074, green: 0.086, blue: 0.125))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.118, green: 0.133, blue: 0.188), lineWidth: 1))
        }
    }

    private func infoRowView(_ row: InfoRow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(row.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.608, green: 0.639, blue: 0.698))
                .frame(width: 150, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)

            if row.isLink, let urlStr = row.linkURL, let url = URL(string: urlStr) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text(row.value)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.294, green: 0.620, blue: 0.973))
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Text(row.value)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.831, green: 0.847, blue: 0.886))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    // MARK: Scoring section

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEWS PRIORITY SCORING FORMULA")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.294, green: 0.620, blue: 0.973))
                .kerning(1.0)

            Text("Each story is scored before display. Higher-impact, more recent, more credible, and more symbol-specific stories surface first.")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.608, green: 0.639, blue: 0.698))

            VStack(spacing: 0) {
                // Formula block
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(["score = (keyword_weight × 40)",
                             "     + (recency_score  × 35)",
                             "     + (source_tier    × 15)",
                             "     + (specificity    × 10)"], id: \.self) { line in
                        Text(line)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(red: 0.655, green: 0.545, blue: 0.980))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color(red: 0.118, green: 0.133, blue: 0.188))
                    .frame(height: 1)

                // Table header
                HStack(spacing: 0) {
                    Text("COMPONENT").frame(width: 110, alignment: .leading)
                    Text("WEIGHT").frame(width: 70, alignment: .leading)
                    Text("DETAILS").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.420, green: 0.447, blue: 0.510))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)

                Rectangle()
                    .fill(Color(red: 0.118, green: 0.133, blue: 0.188))
                    .frame(height: 1)

                scoringRow("Keyword", weight: "×40",
                    detail: "1.0 — earnings, beat, miss, EPS, revenue, guidance, FDA, approval, merger, acquisition, dividend, buyback, recall, lawsuit, SEC, DOJ, bankruptcy, downgrade, upgrade, target price\n0.6 — analyst, forecast, outlook, partnership, launch, CEO, CFO, appointed, resigned\n0.3 — all other news")

                Rectangle().fill(Color(red: 0.102, green: 0.118, blue: 0.173)).frame(height: 1)

                scoringRow("Recency", weight: "×35",
                    detail: "<1h → 1.0  ·  <3h → 0.8  ·  <6h → 0.6  ·  <12h → 0.4  ·  <24h → 0.2  ·  older → 0.1")

                Rectangle().fill(Color(red: 0.102, green: 0.118, blue: 0.173)).frame(height: 1)

                scoringRow("Source Tier", weight: "×15",
                    detail: "Tier 1 (1.0) — Reuters, Bloomberg, WSJ, Financial Times, CNBC, SEC, AP\nTier 2 (0.6) — MarketWatch, Barron's, Forbes, Fortune, Business Insider, Yahoo Finance, Benzinga, Motley Fool\nTier 3 (0.3) — SeekingAlpha, blogs, press releases, all others")

                Rectangle().fill(Color(red: 0.102, green: 0.118, blue: 0.173)).frame(height: 1)

                scoringRow("Specificity", weight: "×10",
                    detail: "1 ÷ symbols in Finnhub's 'related' field.\ne.g. related=\"LLY\" → 1.0  ·  related=\"LLY,PFE\" → 0.5  ·  related=\"LLY,PFE,MRK,ABBV\" → 0.25\nStories about fewer symbols are more specific to your holding.")
            }
            .background(Color(red: 0.074, green: 0.086, blue: 0.125))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.118, green: 0.133, blue: 0.188), lineWidth: 1))
        }
    }

    private func scoringRow(_ name: String, weight: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.831, green: 0.847, blue: 0.886))
                .frame(width: 110, alignment: .leading)
            Text(weight)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .leading)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.831, green: 0.847, blue: 0.886))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    // MARK: Footer

    private var aboutFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.118, green: 0.133, blue: 0.188))
                .frame(height: 1)
            HStack(spacing: 0) {
                Spacer()
                Text("Stock Ticker for macOS  ·  Built with SwiftUI  ·  Data by ")
                    .foregroundColor(Color(red: 0.294, green: 0.318, blue: 0.369))
                Button("finnhub.io") {
                    if let url = URL(string: "https://finnhub.io") { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(red: 0.294, green: 0.620, blue: 0.973))
                Spacer()
            }
            .font(.system(size: 12))
            .padding(.top, 16)
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting type

private struct InfoRow {
    let label: String
    let value: String
    var isLink: Bool = false
    var linkURL: String? = nil

    init(_ label: String, _ value: String, isLink: Bool = false, linkURL: String? = nil) {
        self.label = label
        self.value = value
        self.isLink = isLink
        self.linkURL = linkURL
    }
}
