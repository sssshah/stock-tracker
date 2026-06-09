# Stock Ticker Streamer

A floating, always-on-top stock price and financial news ticker for macOS 14+.

---

## Overview

Stock Ticker Streamer is a slim, frosted-glass ribbon that floats above all your windows — showing live stock prices and scored financial news for your portfolio, always visible while you work.

No switching apps. No digging through browser tabs. Your portfolio, always on screen.

---

## Features

- **Dual-row display** — live prices with change % on top, financial news headlines below
- **Always-on-top floating window** — stays visible above every other app
- **Intelligent news scoring** — stories ranked by impact, recency, source credibility, and symbol specificity — not just chronological order
- **Click news to read** — hover any headline to pause scrolling, click to open the full story in your browser
- **Full-width maximize** — green button expands to full screen width, ESC restores
- **Frosted glass design** — transparent, draggable, no clutter
- **Portfolio editor** — add, remove, and reorder up to 12 symbols
- **Market hours aware** — stops fetching on weekends and US holidays
- **No ads, no subscriptions**

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Finnhub.io API key (free at [finnhub.io](https://finnhub.io))

---

## Installation

### Mac App Store
Search for **Stock Ticker Streamer** on the Mac App Store.

### Build from Source
1. Clone the repo
   ```bash
   git clone https://github.com/sssshah/stock-tracker.git
   ```
2. Create `Config.xcconfig` in the project root with your Finnhub API key:
   ```
   FINNHUB_API_KEY = your_key_here
   ```
3. Open `StockTicker.xcodeproj` in Xcode 15+
4. Set your development team under **Signing & Capabilities**
5. Press **⌘R** to build and run

---

## News Scoring

Each story is scored before display using four signals:

| Signal | Weight | Details |
|---|---|---|
| **Keywords** | ×40 | Earnings, FDA, merger, acquisition, guidance etc. score highest |
| **Recency** | ×35 | Decays from 1.0 (<1hr) to 0.1 (>24hr) |
| **Source tier** | ×15 | Reuters/Bloomberg tier 1, Yahoo Finance tier 2, blogs tier 3 |
| **Specificity** | ×10 | 1 ÷ number of symbols tagged — more specific = higher score |

A category modifier is applied on top: `company news` ×1.2, `top news` ×0.75, `forex/crypto` ×0.5.

---

## Data

- Stock prices and news provided by [Finnhub.io](https://finnhub.io)
- Prices are delayed ~15–20 minutes
- News refreshes every 5 minutes during market hours
- Not financial advice

---

## Support

Found a bug or have a feature request? [Open an issue](https://github.com/sssshah/stock-tracker/issues).

For other questions: sssshah@yahoo.com

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with Swift / SwiftUI · macOS only*
