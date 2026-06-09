import Foundation

struct AssumptionsPage {
    static let html = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Stock Ticker — Data & Assumptions</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
    background: #0d0f14;
    color: #e0e2e8;
    padding: 40px 24px 80px;
    max-width: 780px;
    margin: 0 auto;
    line-height: 1.6;
  }
  header {
    display: flex;
    align-items: center;
    gap: 14px;
    margin-bottom: 40px;
    border-bottom: 1px solid #1e2230;
    padding-bottom: 24px;
  }
  .logo {
    width: 44px; height: 44px;
    background: linear-gradient(135deg, #1e88e5, #7c4dff, #00bfa5);
    border-radius: 10px;
    display: flex; align-items: center; justify-content: center;
    font-size: 22px;
  }
  header h1 { font-size: 22px; font-weight: 600; color: #fff; }
  header p  { font-size: 13px; color: #6b7280; margin-top: 2px; }

  section { margin-bottom: 36px; }
  h2 {
    font-size: 13px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #4b9ef8;
    margin-bottom: 14px;
  }
  .card {
    background: #131620;
    border: 1px solid #1e2230;
    border-radius: 10px;
    overflow: hidden;
  }
  .row {
    display: grid;
    grid-template-columns: 200px 1fr;
    gap: 0;
    border-bottom: 1px solid #1a1e2c;
    padding: 13px 18px;
    align-items: start;
  }
  .row:last-child { border-bottom: none; }
  .label {
    font-size: 13px;
    font-weight: 500;
    color: #9ba3b2;
  }
  .value {
    font-size: 13px;
    color: #d4d8e2;
  }
  .value strong { color: #fff; font-weight: 600; }
  .value .tag {
    display: inline-block;
    font-size: 11px;
    font-weight: 600;
    padding: 2px 7px;
    border-radius: 4px;
    margin-right: 4px;
  }
  .tag.green  { background: rgba(52,211,153,0.12); color: #34d399; }
  .tag.blue   { background: rgba(75,158,248,0.12); color: #4b9ef8; }
  .tag.yellow { background: rgba(251,191,36,0.12); color: #fbbf24; }
  .tag.purple { background: rgba(167,139,250,0.12); color: #a78bfa; }

  .score-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .score-table th {
    text-align: left;
    padding: 10px 18px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #6b7280;
    border-bottom: 1px solid #1e2230;
  }
  .score-table td {
    padding: 11px 18px;
    border-bottom: 1px solid #141720;
    color: #d4d8e2;
    vertical-align: top;
  }
  .score-table tr:last-child td { border-bottom: none; }
  .weight { font-weight: 600; color: #fff; font-variant-numeric: tabular-nums; }
  .kw-list { color: #9ba3b2; font-size: 12px; margin-top: 3px; line-height: 1.5; }

  .tier-1 { color: #34d399; }
  .tier-2 { color: #4b9ef8; }
  .tier-3 { color: #9ba3b2; }

  footer {
    margin-top: 48px;
    padding-top: 20px;
    border-top: 1px solid #1e2230;
    font-size: 12px;
    color: #4b5563;
    text-align: center;
  }
  a { color: #4b9ef8; text-decoration: none; }
  a:hover { text-decoration: underline; }
</style>
</head>
<body>

<header>
  <div class="logo">📈</div>
  <div>
    <h1>Stock Ticker</h1>
    <p>Data sources, refresh cadence &amp; news scoring assumptions</p>
  </div>
</header>

<!-- Data Sources -->
<section>
  <h2>Data Sources</h2>
  <div class="card">
    <div class="row">
      <div class="label">Price Data</div>
      <div class="value">
        <strong>Finnhub.io</strong><br>
        <span class="kw-list">Real-time US equity quotes delayed ~15–20 minutes on free plan. Covers stocks, ETFs, and major indices.</span>
      </div>
    </div>
    <div class="row">
      <div class="label">News Feed</div>
      <div class="value">
        <strong>Finnhub Company News API</strong><br>
        <span class="kw-list">Stories are fetched per-symbol using Finnhub's <code>/company-news</code> endpoint and filtered to items where Finnhub's own <code>related</code> field explicitly contains the queried symbol.</span>
      </div>
    </div>
    <div class="row">
      <div class="label">Market Status</div>
      <div class="value">
        <strong>Finnhub Market Status API</strong><br>
        <span class="kw-list">Checked on every refresh cycle to detect US market holidays. Weekend detection is done locally.</span>
      </div>
    </div>
  </div>
</section>

<!-- Refresh Cadence -->
<section>
  <h2>Refresh Cadence</h2>
  <div class="card">
    <div class="row">
      <div class="label">Stock Prices</div>
      <div class="value">
        <span class="tag green">Every 60 seconds</span>
        during market hours (weekdays, non-holidays)
      </div>
    </div>
    <div class="row">
      <div class="label">News Stories</div>
      <div class="value">
        <span class="tag blue">Every 5 minutes</span>
        News is fetched independently of prices to conserve API quota
      </div>
    </div>
    <div class="row">
      <div class="label">Market Closed</div>
      <div class="value">
        <span class="tag yellow">Paused</span>
        No fetches on weekends or US market holidays. Last known prices are shown dimmed with a "Market Closed" indicator.
      </div>
    </div>
    <div class="row">
      <div class="label">Price Delay</div>
      <div class="value">
        Quotes are delayed <strong>~15–20 minutes</strong> on Finnhub's free tier. They are <em>not</em> real-time.
      </div>
    </div>
    <div class="row">
      <div class="label">API Rate Limit</div>
      <div class="value">
        Price and news calls are staggered with small delays between symbols to stay well within API limits.
      </div>
    </div>
  </div>
</section>

<!-- News Scoring -->
<section>
  <h2>News Priority Scoring Formula</h2>
  <p style="font-size:13px; color:#9ba3b2; margin-bottom:14px;">
    Each story is scored before display. Higher-impact, more recent, more credible, and more symbol-specific stories surface first.
  </p>
  <div class="card">
    <div style="padding: 14px 18px; border-bottom: 1px solid #1e2230;">
      <code style="font-size:13px; color:#a78bfa; line-height:2;">
        score = (keyword_weight × 40)<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;+ (recency_score &nbsp;× 35)<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;+ (source_tier &nbsp;&nbsp;&nbsp;× 15)<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;+ (specificity &nbsp;&nbsp;&nbsp;× 10)
      </code>
    </div>
    <table class="score-table">
      <tr>
        <th style="width:140px">Component</th>
        <th style="width:80px">Weight</th>
        <th>Details</th>
      </tr>
      <tr>
        <td><strong>Keyword</strong></td>
        <td class="weight">×40</td>
        <td>
          <span class="tag green">1.0</span> earnings, beat, miss, EPS, revenue, guidance, FDA, approval, merger, acquisition, dividend, buyback, recall, lawsuit, SEC, DOJ, bankruptcy, downgrade, upgrade, target price<br>
          <span class="tag blue">0.6</span> analyst, forecast, outlook, partnership, launch, CEO, CFO, appointed, resigned<br>
          <span class="tag yellow">0.3</span> all other news
        </td>
      </tr>
      <tr>
        <td><strong>Recency</strong></td>
        <td class="weight">×35</td>
        <td>
          &lt;1h → 1.0 &nbsp;·&nbsp; &lt;3h → 0.8 &nbsp;·&nbsp; &lt;6h → 0.6<br>
          &lt;12h → 0.4 &nbsp;·&nbsp; &lt;24h → 0.2 &nbsp;·&nbsp; older → 0.1
        </td>
      </tr>
      <tr>
        <td><strong>Source Tier</strong></td>
        <td class="weight">×15</td>
        <td>
          <span class="tier-1">Tier 1 (1.0)</span> — Reuters, Bloomberg, WSJ, Financial Times, CNBC, SEC, AP<br>
          <span class="tier-2">Tier 2 (0.6)</span> — MarketWatch, Barron's, Forbes, Fortune, Business Insider, Yahoo Finance, Benzinga, Motley Fool<br>
          <span class="tier-3">Tier 3 (0.3)</span> — SeekingAlpha, blogs, press releases, all others
        </td>
      </tr>
      <tr>
        <td><strong>Specificity</strong></td>
        <td class="weight">×10</td>
        <td>
          1 ÷ number of symbols in Finnhub's <code>related</code> field.<br>
          e.g. related="LLY" → 1.0 &nbsp;·&nbsp; related="LLY,PFE" → 0.5 &nbsp;·&nbsp; related="LLY,PFE,MRK,ABBV" → 0.25<br>
          <span class="kw-list">Stories about fewer symbols are more specific to your holding.</span>
        </td>
      </tr>
    </table>
  </div>
</section>

<!-- Limitations -->
<section>
  <h2>Limitations &amp; Disclaimers</h2>
  <div class="card">
    <div class="row">
      <div class="label">Not Financial Advice</div>
      <div class="value">This app is for informational purposes only. Nothing displayed constitutes investment advice.</div>
    </div>
    <div class="row">
      <div class="label">Delayed Prices</div>
      <div class="value">All prices are delayed ~15–20 minutes. Do not use for time-sensitive trading decisions.</div>
    </div>
    <div class="row">
      <div class="label">News Accuracy</div>
      <div class="value">News is sourced directly from Finnhub's aggregation. Story relevance to a specific symbol is determined by Finnhub's tagging — occasional misattribution may occur.</div>
    </div>
    <div class="row">
      <div class="label">Max Portfolio</div>
      <div class="value">Up to <strong>12 symbols</strong> supported. More symbols increase API call frequency.</div>
    </div>
    <div class="row">
      <div class="label">Data Provider</div>
      <div class="value"><a href="https://finnhub.io" target="_blank">finnhub.io</a> — subject to Finnhub's terms of service and availability.</div>
    </div>
  </div>
</section>

<footer>
  Stock Ticker for macOS &nbsp;·&nbsp; Built with SwiftUI &nbsp;·&nbsp; Data by <a href="https://finnhub.io" target="_blank">Finnhub</a>
</footer>

</body>
</html>
"""
}
