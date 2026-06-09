# Stock Ticker — macOS

A floating, always-on-top dual-row stock ticker for macOS 14+.
- **Row 1:** Live stock prices (LLY, AAPL, MSFT, NVDA, GOOGL, AMZN, TSLA, SPY) with change %
- **Row 2:** Scrolling financial news headlines filtered to your portfolio
- Refreshes every 60 seconds via Finnhub API
- Skips fetching on weekends and US market holidays (shows "Market Closed")
- Floats above all windows, draggable anywhere on screen
- Hover to reveal Refresh (↺) and Quit (✕) buttons

---

## Setup in Xcode

1. **Open** `StockTicker.xcodeproj` in Xcode 15+
2. In the project navigator, select the **StockTicker** target
3. Under **Signing & Capabilities**, set your Team to your Apple Developer account
4. Change `com.yourdomain.StockTicker` in build settings to a bundle ID you own
5. Press **⌘R** to build and run

---

## Changing Your Portfolio

Open `TickerViewModel.swift` and edit the `symbols` array:

```swift
let symbols = ["LLY", "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "TSLA", "SPY"]
```

---

## Changing the Refresh Interval

In `TickerViewModel.swift`:

```swift
let refreshInterval: TimeInterval = 60  // seconds
```

---

## Updating the API Key

In `FinnhubService.swift`:

```swift
private let apiKey = "YOUR_NEW_KEY_HERE"
```

---

## Window Behavior

| Action | Result |
|---|---|
| Drag anywhere | Window follows — floats above all apps |
| Hover | Reveals refresh and quit buttons (top-right) |
| Scroll speed | Prices: 60 pts/sec · News: 45 pts/sec |
| Market closed | Shows grey "CLOSED" indicator, last known prices dimmed |

---

## File Overview

| File | Purpose |
|---|---|
| `StockTickerApp.swift` | App entry, window chrome (floating, transparent, rounded) |
| `Models.swift` | Data types: StockQuote, NewsItem, API response structs |
| `FinnhubService.swift` | All Finnhub API calls (quote, news, market-status) |
| `TickerViewModel.swift` | Refresh loop, market hours logic, state management |
| `PriceTicker.swift` | Scrolling price row with QuoteChip components |
| `NewsTicker.swift` | Scrolling news row with NewsChip components |
| `ContentView.swift` | Root layout: two rows, hover controls, closed-market view |

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later
- Free Finnhub API key (60 calls/min on free tier)
