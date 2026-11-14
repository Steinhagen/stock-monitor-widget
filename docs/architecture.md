# Architecture

Status: target structure for Plasma Stock Monitor. The tree below is the destination,
not the current layout; the current code is being moved towards it in phases (see the
end of this file). Reviewed with the 1.7 feature set on 2026-11-14.

## Why this exists

The widget works, but three files still carry most of the behaviour: `main.qml`
(1,816 lines, ~65 functions), `SingleStockView.qml` (2,231) and
`config/portfolio.qml` (1,478) — together about half of the source tree. That has
concrete costs:

- `main.qml` mixes configuration, theming, formatting, network I/O, market sessions,
  chart-data assembly, quote caching and view wiring. Almost every feature edits it.
- Views reach through `rootItem` for colours, formatting and actions, so a view cannot
  be reused or rendered without the whole applet.
- News providers are hardcoded inside `NewsController`; adding a source means editing
  the controller again.
- Timeouts, generation tokens, caching and error handling are re-implemented per
  feature.
- Domain logic lives in QML files that need a Plasma context, so it cannot be tested.

## Principles

1. **One dependency direction:** `ui → controllers → state → providers → domain → core`.
   Nothing imports upward.
2. **`domain/` is pure JavaScript** — no QML types, no network, no `Qt.*`. It is the
   part that gets unit tests.
3. **Providers are adapters, not policy.** They turn a wire format into domain objects.
   Retry, caching, merging and deduplication live in controllers/domain.
4. **One reason to change per file.** Target 150–400 lines; 500 is the ceiling.
5. **Views receive data and commands, not the applet.** `Theme` for colours, stores for
   state, `AppActions` for commands.
6. **No new framework.** QML properties are the reactive store; this is about
   boundaries, not abstraction for its own sake.

## Target tree

```
contents/
├── config/
│   ├── main.xml                        # KConfigXT schema
│   └── config.qml                      # category list; sources -> "settings/pages/*.qml"
├── code/backup-io.sh
└── ui/
    ├── main.qml                        # entry only: PlasmoidItem, representations, App
    ├── app/
    │   ├── App.qml                     # composition: settings -> controllers/stores -> views
    │   ├── AppConfig.qml               # typed, defaulted, migrated configuration
    │   ├── AppActions.qml              # intents: select, refresh, openLink, cyclePanel
    │   └── AppFacade.qml               # what views receive: stores + actions + theme
    ├── core/
    │   ├── Http.js                     # XHR get/text/json, timeout, generation/cancel
    │   ├── Cache.js                    # TTL entries, invalidate, per-key generation
    │   ├── Json.js                     # safe parse
    │   ├── Text.js                     # entities, URL safety, whitespace, accent folding
    │   └── Log.js                      # categorized console logging
    ├── domain/                         # pure JS, fully testable
    │   ├── symbols.js                  # base/suffix parsing, display modes, badges
    │   ├── exchanges.js                # suffix -> exchange labels/names
    │   ├── currencies.js               # symbols, minor units (GBp/ILA), conversion
    │   ├── sessions.js                 # open/closed, pre/post, weekends, update windows
    │   ├── quotes.js                   # meta -> Quote, change/percent, extended hours
    │   ├── chart.js                    # range slicing, first/last session, previous close
    │   ├── candles.js                  # candle aggregation per range
    │   ├── curve.js                    # monotone curve geometry
    │   ├── formatting.js               # numbers, prices, percentages, dates, range labels
    │   ├── news.js                     # NewsItem, merge, dedupe, sort, sources, ages
    │   ├── analysts.js                 # targets -> groups, consensus, marker values
    │   └── portfolio.js                # lots, positions, P&L, totals, conversions
    ├── providers/
    │   ├── yahoo/
    │   │   ├── chart.js                # v8/chart
    │   │   ├── search.js               # v1/search: symbols, company name, news
    │   │   ├── quoteSummary.js         # cookie/crumb flow for analyst data
    │   │   ├── news.js                 # search headlines, relatedTickers filter
    │   │   └── search.js               # symbol search for the settings page
    │   ├── bvb/
    │   │   └── issuer.js               # instrument page, announcements, postback
    │   ├── google/news.js              # RSS search: query, locale, parse, filters
    │   ├── fx/rates.js                   # daily rates, primary + fallback feed
    │   └── news/
    │       ├── registry.js             # descriptors: id, label, supports(), fetch()
    │       ├── yahooSource.js
    │       ├── bvbSource.js
    │       └── googleSource.js
    ├── state/
    │   ├── QuoteStore.qml
    │   ├── ChartStore.qml
    │   ├── NewsStore.qml
    │   ├── AnalystStore.qml
    │   ├── PortfolioStore.qml
    │   ├── FxStore.qml
    │   └── WatchlistStore.qml
    ├── controllers/
    │   ├── QuotesController.qml        # timer, market gating, startup retry, cache
    │   ├── ChartController.qml         # range -> fetch -> series/candles
    │   ├── NewsController.qml          # sources, retries, merge, cache
    │   ├── AnalystController.qml
    │   ├── PortfolioController.qml
    │   ├── FxController.qml
    │   ├── MarketController.qml         # pre/post sessions, extended quote
    │   └── PanelController.qml         # cycle, alternate labels, panel ticker
    ├── platform/
    │   ├── PlasmaSettings.qml          # configuration + one-time migration
    │   ├── Theme.qml                   # singleton: colours, opacities, contrast
    │   ├── PanelAdapter.qml            # form factor, size hints, panel measurement
    │   ├── CachedQuotes.qml            # last-quote snapshot in/out of config
    │   └── ExternalLinks.qml           # openUrlExternally + safe URL policy
    ├── ui/
    │   ├── FullView.qml
    │   ├── single/
    │   │   ├── SingleStockView.qml     # composition only
    │   │   ├── StockHeader.qml
    │   │   ├── QuoteBlock.qml
    │   │   ├── ChartPane.qml
    │   │   ├── ChartCanvas.qml         # painting only
    │   │   ├── ChartControls.qml
    │   │   ├── AnalystOverlay.qml      # was analyst/AnalystMarkers.qml
    │   │   ├── NewsPane.qml
    │   │   ├── NewsRow.qml
    │   │   └── PortfolioStrip.qml
    │   ├── list/
    │   │   ├── MultiStockView.qml
    │   │   ├── WatchRow.qml
    │   │   ├── WatchHeader.qml
    │   │   └── TwoColumnSplit.qml
    │   ├── panel/CompactPanel.qml
    │   ├── tooltip/TooltipContent.qml
    │   └── components/
    │       ├── PillButton.qml          # range/style/source-filter pill
    │       ├── IconAction.qml
    │       ├── TickerBadge.qml
    │       ├── PriceText.qml
    │       ├── ChangeText.qml
    │       ├── PositionLine.qml        # moved from ui/
    │       ├── SectionLabel.qml
    │       ├── EmptyState.qml
    │       └── Divider.qml
    └── settings/
        ├── pages/
        │   ├── GeneralPage.qml
        │   ├── SymbolsListsPage.qml
        │   ├── ChartNewsPage.qml
        │   ├── PanelViewPage.qml
        │   ├── PortfolioPage.qml       # composition
        │   ├── AppearancePage.qml
        │   ├── MouseActionsPage.qml
        │   └── ImportExportPage.qml
        ├── portfolio/
        │   ├── LotEditor.qml
        │   ├── PositionForm.qml
        │   ├── LotsList.qml
        │   └── PortfolioTotals.qml
        ├── importExport/
        │   ├── BackupIO.qml            # moved from ui/
        │   ├── backupFormat.js         # was backup.js
        │   └── FileDialogs.qml
        └── components/
            ├── ColorRow.qml
            ├── NumberRow.qml
            └── SettingsWindow.js       # was window.js

tests/
├── run.sh
├── README.md
├── qml/                                # tst_*.qml
└── fixtures/                           # captured, trimmed provider payloads

docs/
├── architecture.md                     # this file
└── adr/                                # short decisions, added when they are made
```

## Dependency rules

```
ui/            may import components, state, actions, theme
controllers/   may import state, providers, domain, core
state/         may import domain only
providers/     may import core + domain only
domain/        imports nothing (pure JS)
core/          imports nothing
platform/      imported only by app/ and main.qml
settings/      imports platform settings + settings components only
```

`main.qml` must not contain business logic: it creates `App`, defines the compact and
full representations, and forwards size hints.

## Contracts

**HTTP** — one implementation of timeouts, cancellation and status codes:

```js
Http.get(url, { timeout: 20000, parse: "json" }, function (data, error) { … });
// error: null | { code: "http"|"timeout"|"network"|"parse", status: 0, message: "" }
```

**News provider** — sources become data instead of branches:

```js
// providers/news/googleSource.js
var source = {
    id: "google",
    label: "Google",                    // brand, not translated
    supports: function (ctx) { return ctx.name !== ""; },
    fetch: function (ctx, done) {       // ctx: symbol, name, locale, limit, http
        done(items, error);             // items: domain NewsItem[]
    }
};
```

The controller only filters the registry by settings, calls the sources, and hands the
result to `domain/news.js` for merging. The "company name arrives later" retry becomes
a `supports()` re-check, not a special case per provider.

**Store** — reactive state, no logic:

```qml
QtObject {
    property var entries: ({})          // key -> entry
    readonly property var current: entries[key] || null
    function put(key, entry) { /* copy-on-write */ }
}
```

**Theme** — one source for colours instead of `rootItem.*` reach-through. A `qmldir`
singleton is preferred; if that is awkward in a Plasma package, one `Theme.qml`
instance is created in `App.qml` and passed as a `required property`.

**AppActions** — the only way views change state: `selectTicker`, `refreshQuotes`,
`setPane`, `openNewsLink`, `cyclePanel`, `addLot`, … .

## Where today's code goes

| Today | Target |
|---|---|
| `main.qml` (config, theme, math, I/O) | `app/*`, `platform/*`, `controllers/*`, `state/*` |

Phase 1 moved the pure modules (`currencies`, `exchanges`, `chart`, `candles`, `curve`,
`portfolio`, `format`, `symbols`, `sessions`, `quotes`, `news`) into `contents/ui/domain/`;
the rows above describe where the remaining files will go.
| `chartdata.js` | `domain/chart.js`, `domain/candles.js`, `providers/yahoo/chart.js` |
| `chartcurve.js` | `domain/curve.js` |
| `portfolio.js` | `domain/portfolio.js` |
| `currencies.js`, `exchanges.js` | `domain/currencies.js`, `domain/exchanges.js`, `domain/symbols.js` |
| `news.js` | `providers/yahoo/news.js` + `domain/news.js` |
| `bvbnews.js` | `providers/bvb/issuer.js` + `providers/news/bvbSource.js` |
| `googlenews.js` | `providers/google/news.js` + `providers/news/googleSource.js` |
| `NewsController.qml` | `controllers/NewsController.qml` + `state/NewsStore.qml` |
| `analyst/*` | `providers/yahoo/quoteSummary.js`, `domain/analysts.js`, `controllers/AnalystController.qml`, `ui/single/AnalystOverlay.qml` |
| `SingleStockView.qml` | `ui/single/*` + `ui/components/*` |
| `MultiStockView.qml`, `PositionLine.qml` | `ui/list/*`, `ui/components/PositionLine.qml` |
| `CompactPanel.qml`, `FullView.qml`, `TooltipContent.qml` | `ui/panel/`, `ui/FullView.qml`, `ui/tooltip/` |
| `config/*.qml` | `settings/pages/*`, `settings/portfolio/*`, `settings/importExport/*` |
| `backup.js`, `BackupIO.qml` | `settings/importExport/backupFormat.js`, `BackupIO.qml` |

## Flows after the split

- **Quotes:** `QuotesController` asks `domain/sessions.js` whether to refresh, calls
  `providers/yahoo/chart`, normalises through `domain/quotes.js`, writes `QuoteStore`.
- **Chart:** `ChartController` reacts to range/quote changes, fetches, builds
  series/candles in `domain/`, writes `ChartStore`; `ChartCanvas` only paints.
- **News:** `NewsController` picks enabled registry entries, runs them, merges through
  `domain/news.js`, writes `NewsStore`.
- **Portfolio:** `PortfolioController` owns lots, calls `domain/portfolio.js` with rates
  from `FxStore`; `PositionLine` only formats what it receives.

## Testing

`tests/` is the harness: `qmltestrunner` against `tests/qml`, fixtures in
`tests/fixtures`, no network. Run it with:

```
./tests/run.sh
```

Covered today: currencies (minor units/conversion), exchange labels, number/money and
symbol formatting, market sessions, chart API parameters, Yahoo news and symbol search
parsing, Google news parsing, BVB announcement parsing, backup format, chart-data and
candle helpers, cache rules, the news registry, and the per-source merge in
`NewsController`. Provider and controller tests take
fixtures or injected data, so they stay deterministic.

Fixtures are trimmed captures of real responses; when a provider changes its payload,
update the fixture and the parser test together.

## Migration plan

- [x] **Phase 0 — harness.** `tests/` with qmltestrunner + fixtures. No production
      change (apart from the BVB parser fix the first fixture exposed).
- [x] **Phase 1 — domain extraction.** Formatting, symbols, sessions, quotes, news
      merge, chart/candles, curve, currencies, exchanges and portfolio now live in
      `contents/ui/domain/`, with tests. `main.qml` keeps thin wrappers with the old
      names so the views did not change; those wrappers go away with the controllers
      in Phase 3.
- [x] **Phase 2 — core + providers.** `core/Http` and `core/Cache` now hold the
      request and freshness rules. Yahoo (chart, search, quoteSummary, news), BVB and
      Google live under `providers/`, and `NewsController` drives them through a
      registry: adding a source is a descriptor plus one registry entry. `main.qml`
      uses the Yahoo chart and FX providers for every request it makes.
- [ ] **Phase 3 — controllers and stores.** Split `main.qml`; introduce `AppConfig`,
      `AppActions`, `App.qml`; `main.qml` becomes composition. In progress:
      `app/AppConfig.qml`, `app/App.qml`, `controllers/FxController.qml`,
      `controllers/MarketController.qml`, `state/QuoteStore.qml` and
      `controllers/SingleQuoteController.qml` are in. The multi-stock rows, the
      remaining stores and `AppActions` are next.
- [ ] **Phase 4 — view decomposition.** Split `SingleStockView`; extract shared
      components; `Theme`; remove `rootItem.*` from components.
- [ ] **Phase 5 — settings reorganisation.** Move pages under `settings/`, split the
      portfolio page, move backup into `settings/importExport/`.
- [x] **Phase 6 — CI.** `.github/workflows/tests.yml` runs `tests/run.sh` on main and
      on every pull request (done ahead of the other phases).

Every phase is shippable on its own and should not change behaviour (except where a
test exposes a bug).

## Notes and trade-offs

- QML directory imports are relative; keep nesting at three levels or less.
- Do not fragment below this level: a 20-line file with one binding is worse than a
  coherent 300-line component. The target is ~75 files for ~13k lines.
- Keep callbacks rather than introducing a promise layer unless there is a concrete
  need; the existing providers already use `done(items, error)`.
- QML settings are read-only from the applet; `AppConfig` is a typed facade, not a
  second store.
