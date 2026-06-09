# Stock Ticker — macOS App Instructions
*Reference document for building, maintaining, and extending the app*

---

## App Overview

A floating, always-on-top dual-row stock ticker streamer for macOS 14+.
- **Row 1:** Live stock prices with change % — continuous horizontal scroll
- **Row 2:** Financial news headlines filtered and scored per portfolio symbol — continuous horizontal scroll
- Transparent frosted-glass window, draggable anywhere on screen
- Lives in the macOS menu bar (no Dock icon)

---

## Platform & Stack

- **Language:** Swift / SwiftUI
- **Target:** macOS 14.0 (Sonoma) or later
- **Framework:** Native macOS — no Electron, no web wrapper
- **Data source:** Finnhub.io API (single source for prices, news, and market status)

---

## Finnhub API

- **Base URL:** `https://finnhub.io/api/v1`
- **Key:** stored in `FinnhubService.swift` → `private let apiKey`
- **Endpoints used:**
  - `/quote?symbol=X&token=KEY` — current price
  - `/company-news?symbol=X&from=DATE&to=DATE&token=KEY` — news per symbol
  - `/stock/market-status?exchange=US&token=KEY` — holiday/open detection

---

## Refresh Cadence

| Data | Frequency | Condition |
|---|---|---|
| Stock prices | Every 60 seconds | Weekdays, non-holidays only |
| News | Every 5 minutes | Weekdays, non-holidays only |
| Market status | Every refresh cycle | Used to detect holidays |

- On weekends and US market holidays: **no fetching**. Last known prices shown dimmed with "Market Closed" indicator.
- Prices are delayed ~15–20 minutes (exchange standard delay).

---

## Portfolio

- Symbols stored in `UserDefaults` key `"portfolio_symbols"`
- Default symbols: `["LLY", "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "TSLA", "SPY"]`
- Maximum **12 symbols**
- Managed via the Portfolio editor (menu bar → Portfolio → Edit Portfolio…)
- Supports add, remove, and drag-to-reorder
- Changes take effect immediately on "Apply & Refresh"

---

## Window Behavior

- **Level:** `.floating` — always above other windows
- **Style:** `.hiddenTitleBar` + `.fullSizeContentView` — no visible chrome
- **Background:** Transparent + `NSVisualEffectView` frosted glass (`.hudWindow` material)
- **Draggable:** `isMovableByWindowBackground = true`
- **Position:** Saved to `UserDefaults` key `"ticker_window_frame"` on every drag; restored on launch
- **Titlebar buttons** (red/yellow/green): hidden by default, revealed when cursor enters top-left corner (~80pt hot zone)

### Maximize / Restore
- **Green button:** expands window to full screen width, snaps Y position to top of screen flush with macOS menu bar
- **ESC:** restores window to previous size and position
- In maximized mode, the titlebar container is hidden; hover the left edge to reveal it

---

## Menu Bar

App lives in the macOS menu bar as a status item (no Dock icon — `LSUIElement = true`).

Menu structure:
```
About & Data Assumptions…
─────────────────────────
Edit Portfolio…        ⌘,
─────────────────────────
Refresh Now            ⌘R
─────────────────────────
Quit Stock Ticker      ⌘Q
```

"About & Data Assumptions…" writes `AssumptionsPage.html` to a temp directory and opens it in the default browser.

---

## News Logic

### Fetch Pipeline (per symbol)

1. Call `/company-news` for each symbol (last 7 days)
2. **Filter:** keep only items where Finnhub's own `related` field explicitly contains the queried symbol (comma-separated list — exact match required)
3. **Score** ALL filtered items using the formula below (no cap before scoring)
4. Sort descending by score, take **top 4 per symbol**
5. Apply cross-symbol deduplication (see below)
6. Final feed sorted by score descending

> Broad or mis-tagged stories are handled by the **category modifier** in scoring (see below) rather than a hard filter. This keeps the pipeline scalable — no hardcoded company name lookups required.

### Scoring Formula

```
score = (keyword_weight × 40)
      + (recency_score  × 35)
      + (source_tier    × 15)
      + (specificity    × 10)

...then multiplied by a category modifier (see below)
```

### Category Modifier
Finnhub returns a `category` field on each news item. Used as a final multiplier on the total score:

| Category | Multiplier | Reason |
|---|---|---|
| `company news` | ×1.20 | Explicitly about this company |
| `merger` | ×1.15 | High-value corporate event |
| `top news` | ×0.75 | Broad market — often mis-tagged |
| `general` | ×0.70 | Generic — low company relevance |
| `forex` / `crypto` | ×0.50 | Almost never relevant to equities |
| anything else | ×1.00 | Neutral |

### Keyword Weights
Scan headline + summary, case-insensitive:

| Weight | Keywords |
|---|---|
| **1.0** | earnings, beat, miss, EPS, revenue, guidance, raised, lowered, FDA, approval, approved, rejected, clinical trial, NDA, PDUFA, merger, acquisition, acquired, buyout, takeover, deal, dividend, buyback, recall, investigation, lawsuit, SEC filing, DOJ, bankruptcy, default, downgrade, upgrade, target price, price target |
| **0.6** | analyst, forecast, outlook, raises, cuts, initiates, reiterates, partnership, contract, launch, product, CEO, CFO, appointed, resigned |
| **0.3** | everything else |

### Recency Score

| Age | Score |
|---|---|
| < 1 hour | 1.0 |
| < 3 hours | 0.8 |
| < 6 hours | 0.6 |
| < 12 hours | 0.4 |
| < 24 hours | 0.2 |
| > 24 hours | 0.1 |

### Source Tier

| Tier | Score | Sources |
|---|---|---|
| **Tier 1** | 1.0 | Reuters, Bloomberg, WSJ, Wall Street Journal, Financial Times, CNBC, SEC, Associated Press, AP (matched as exact full source name — not substring — to avoid false matches on e.g. "Apple") |
| **Tier 2** | 0.6 | MarketWatch, Barron's, Forbes, Fortune, Business Insider, Yahoo Finance, Investopedia, The Motley Fool, Benzinga |
| **Tier 3** | 0.3 | Everything else (SeekingAlpha, blogs, press releases) |

### Specificity Score

```
1 / number_of_symbols_in_related_field

Examples:
  related = "LLY"              → 1.00
  related = "LLY,PFE"         → 0.50
  related = "LLY,PFE,MRK,ABBV" → 0.25
```

### Cross-Symbol Deduplication

- Collect all scored `(item, symbol, score)` tuples across **all** symbols first
- For headlines appearing in multiple symbols' feeds (e.g. `related="AAPL,MSFT"`), resolve with **headline prominence first, score second**:
  - If the new symbol appears in the headline but the existing symbol doesn't → reassign to new symbol
  - If the existing symbol appears in the headline but the new symbol doesn't → keep existing symbol
  - If both or neither appear in the headline → keep the higher-scoring instance
- **Rationale:** "Apple kicks off WWDC" tagged `related="AAPL,MSFT"` should always map to AAPL because "Apple" appears in the headline, even if MSFT somehow scores marginally higher
- Deduplication happens **after** scoring, never before

---

## File Structure

| File | Responsibility |
|---|---|
| `StockTickerApp.swift` | App entry, `NSApplicationDelegate`, menu bar extra, `WindowAccessor` (window chrome, zoom, ESC, mouse tracker, position persistence) |
| `AppDelegate` (in StockTickerApp.swift) | Menu bar status item, menu actions, `openAbout` |
| `ContentView.swift` | Root SwiftUI layout: two ribbon rows, hover controls, notifications |
| `TickerViewModel.swift` | `@MainActor` state, 60s refresh loop, market hours check, symbol management |
| `FinnhubService.swift` | All API calls: quote, batch quotes, news pipeline, market status |
| `NewsScorer.swift` | Stateless scoring: keyword, recency, source tier, specificity |
| `PriceTicker.swift` | `PriceTickerRow`, `QuoteChip`, `ScrollingContent` |
| `NewsTicker.swift` | `NewsTickerRow`, `NewsChip` (hover, click-to-open, pause-on-hover) |
| `PortfolioEditorView.swift` | Add/remove/reorder symbols, gradient UI, persists to UserDefaults |
| `AssumptionsPage.swift` | Static HTML string for the About page (opened in browser) |
| `Models.swift` | `StockQuote`, `NewsItem`, Finnhub response decodables |

---

## Key Implementation Notes

### Market Hours (ET)
```
Pre-market:   4:00 AM – 9:30 AM  (session label: "PRE")
Regular:      9:30 AM – 4:00 PM  (session label: "OPEN")
After-hours:  4:00 PM – 8:00 PM  (session label: "AFTER")
Closed:       all other times    (session label: "CLOSED")
```

### Stale Data Guard
If quote timestamp age > 30 minutes during expected market hours, the data may be stale. The `isStale` property on `StockQuote` flags this (threshold: 3600s currently).

### News Click Behavior
- Hovering a news chip: scrolling pauses, headline underlines, `↗` icon appears, cursor becomes pointer
- Clicking: opens URL in default browser via `NSWorkspace.shared.open(url)`
- `WindowMouseTracker` overrides `hitTest` to return `nil` so it never intercepts clicks

### Position Persistence
- `NSWindow.didMoveNotification` → saves `NSStringFromRect(window.frame)` to `UserDefaults`
- On launch: `NSRectFromString` → validate still on screen → `setFrameOrigin`

### Entitlements
`com.apple.security.app-sandbox = true`
`com.apple.security.network.client = true`

---

## Assumptions Page Content

The About page (`AssumptionsPage.swift`) should cover:
- Data source: Finnhub.io
- Price delay: ~15–20 minutes
- Refresh cadence: prices every 60s, news every 5 min, paused on weekends/holidays
- News scoring formula (all four components with weights)
- Max portfolio size: 12 symbols
- Not financial advice disclaimer
- News accuracy caveat (symbol attribution is based on Finnhub's own tagging)

Do **not** mention free tier plan limits or API quota numbers — these vary by subscription level.

---

## Coding Conventions

- All async work via Swift `async/await` — no callbacks or Combine publishers
- `@MainActor` on `TickerViewModel` — all UI state updates on main thread
- `Task { await ... }` for fire-and-forget async from SwiftUI actions
- Rate limiting between API calls: `Task.sleep(nanoseconds: 150_000_000)` (0.15s) for quotes, `200_000_000` (0.2s) for news
- UserDefaults keys are string constants defined at point of use
- No third-party dependencies — pure Apple frameworks only

---

## Known Constraints

- Finnhub free tier returns `id: 0` on many news items — deduplicate by headline text, not `id`
- `NSEvent.addLocalMonitorForEvents` is blocked by sandbox — use `NSView.keyDown` override instead for key handling
- Yahoo Finance v8/chart endpoint works from native Mac context but has CORS issues in browsers — not used currently, available as fallback
- `onChange(of:)` with single-parameter closure is deprecated in macOS 14 — use two-parameter form `{ _, newValue in }`
