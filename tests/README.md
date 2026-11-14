# Tests

QML unit and controller tests for the widget, run with `qmltestrunner`.

```
./tests/run.sh
```

The script exports `QML_XHR_ALLOW_FILE_READ=1` (the fixture loader reads local files
with `XMLHttpRequest`) and runs with the offscreen platform, so no display is needed.

## Layout

```
tests/
├── run.sh                  # the only entry point
├── qml/
│   ├── Fixture.js          # read(url) helper for fixtures
│   └── tst_*.qml           # one TestCase per module
└── fixtures/               # trimmed captures of real provider payloads
```

## What is covered

| Test | Modules |
|---|---|
| `tst_currencies.qml` | minor units (GBp/ILA), conversion, symbols |
| `tst_exchanges.qml` | suffix parsing, base symbol, exchange labels |
| `tst_news.qml` | Yahoo search URL, safe links, entity decoding, parsing, dedupe |
| `tst_googlenews.qml` | locale query, name cleaning, RSS parsing, quote-page filter |
| `tst_bvbnews.qml` | BVB symbol handling, announcement table, ASP.NET postback |
| `tst_backup.qml` | backup round-trip, validation, legacy portfolio data |
| `tst_chart.qml` | sessions, trading days, previous close |
| `tst_candles.qml` | candle targets and aggregation |
| `tst_newsmodel.qml` | news merge, dedupe and age buckets |
| `tst_symbols.qml` | company names, display ticker, exchange badge |
| `tst_format.qml` | number and money formatting |
| `tst_sessions.qml` | market status, closed state, first-quote wait |
| `tst_quotes.qml` | chart range to API parameters |
| `tst_news_controller.qml` | the controller delegates to the news model |

Tests are offline: providers are called with fixture bodies, and the controller test
only exercises pure merging in `NewsController`.

## Fixtures

Fixtures are real responses trimmed to the fields the parsers read:

- `yahoo-search-sap.json` — Yahoo search reply for "SAP SE".
- `google-news-sap.xml` — Google News RSS for "SAP SE", first six items.
- `google-news-blocked.html` — the HTML page Google returns instead of a feed.
- `bvb-issuer-tlv.html` — the BVB instrument page for TLV, reduced to the news table
  and the ASP.NET form state.

When a provider changes its payload, update the fixture and the matching test in the
same change.

## Adding a test

1. Import the module by relative path:
   `import "../../contents/ui/news.js" as News`.
2. For fixtures: `Fixture.read(Qt.resolvedUrl("../fixtures/file.json"))`.
3. Keep each test deterministic — no network, no timers, no clock-dependent values
   (pass the `now` argument where the module supports it).

Qt 6 is required. The harness is developed against Qt 6.12; older Qt releases that do
not support `QML_XHR_ALLOW_FILE_READ` cannot load the fixtures.
