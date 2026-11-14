import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "domain/currencies.js" as Currency
import "domain/portfolio.js" as Portfolio
import "domain/exchanges.js" as Exchanges
import "domain/symbols.js" as Symbols
import "domain/format.js" as Format
import "app"
import "state"
import "controllers"
import "list"
import "panel"
import "tooltip"

PlasmoidItem {
    id: root

    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }
    SystemPalette { id: disabledPalette; colorGroup: SystemPalette.Disabled }

    App {
        id: app
        configuration: Plasmoid.configuration
        hostTextColor: systemPalette.windowText
        systemBackgroundColor: systemPalette.window
        hostDisabledTextColor: disabledPalette.windowText
    }

    QuoteStore {
        id: quoteStore
    }

    WatchlistController {
        id: watchlist
        applet: root
        store: quoteStore
        market: app.market
        singleQuotes: singleQuote
    }

    SingleQuoteController {
        id: singleQuote
        applet: root
        store: quoteStore
        market: app.market
        stockModel: watchlist.model
    }

    readonly property var stockModel: watchlist.model

    QuoteCacheController {
        id: quoteCache
        applet: root
        model: watchlist.model
        configuration: Plasmoid.configuration
        config: app.config
    }

    AppActions {
        id: actions
        applet: root
        model: watchlist.model
        configuration: Plasmoid.configuration
    }

    // --- CONFIGURATION ---
    // The compact panel indicator is always transparent over the panel. On the desktop,
    // Plasma leaves the background to the system, while Application paints the cards.
    Plasmoid.backgroundHints: !root.inPanel && root.usesPlasmaSurface
        ? PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
        : PlasmaCore.Types.NoBackground
    // Detect where we are (Panel vs Desktop) to switch views
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical) ? root.compactRepresentation : root.fullRepresentation

    // The applet container reads its size constraints from this root item, not from the
    // full-view component. The full view updates these when its mode or minimum changes,
    // so switching from a minimum-sized list to the graph can grow the applet to the
    // graph's minimum instead of leaving the chart clipped inside a smaller card.
    // In a panel the compact representation owns the size: forcing the full-view
    // minimum here widened the panel applet to the graph's minimum and left the compact
    // contents stranded at its left edge. Mirror the compact item's implicit size
    // instead; the full-view hints apply only outside a panel.
    readonly property var panelItem: root.compactRepresentationItem
    readonly property real panelItemWidth: root.panelItem ? root.panelItem.implicitWidth : -1
    readonly property real panelItemHeight: root.panelItem ? root.panelItem.implicitHeight : -1
    property real fullViewMinimumWidth: 322
    property real fullViewMinimumHeight: 360
    property real fullViewPreferredWidth: 600
    property real fullViewPreferredHeight: 520
    Layout.minimumWidth: !root.inPanel ? root.fullViewMinimumWidth
                        : (root.isVerticalPanel ? 0 : root.panelItemWidth)
    Layout.minimumHeight: !root.inPanel ? root.fullViewMinimumHeight
                         : (root.isVerticalPanel ? root.panelItemHeight : 0)
    Layout.preferredWidth: !root.inPanel ? root.fullViewPreferredWidth : root.panelItemWidth
    Layout.preferredHeight: !root.inPanel ? root.fullViewPreferredHeight : root.panelItemHeight

    property string singleTicker: app.config.ticker
    property bool isMultiMode: app.config.isMultiMode
    property bool showTwoList: app.config.showTwoList
    // Left column width in the side-by-side desktop view, in pixels. 0 means automatic
    // (both columns share the available width).
    property int twoColumnLeftWidth: app.config.twoColumnLeftWidth
    property string panelTicker: ""
    // Remember the row selected in the multi-stock list, so it is still the default
    // selection after Plasma or the host restarts.
    property string manualPanelTickerOverride: app.config.selectedTicker
    property string multiTickers: app.config.multiTickers
    // Mouse actions: right click is always the context menu; these three are configurable.
    property string mouseRowLeftAction: app.config.mouseRowLeftAction || "select"
    property string mouseMiddleAction: app.config.mouseMiddleAction || "refresh"
    property string mouseDoubleClickAction: app.config.mouseDoubleClickAction || "open"
    property bool sortAlphabetically: app.config.sortAlphabetically
    property bool swapNameAndTicker: app.config.swapNameAndTicker
    property bool showNameAndTicker: app.config.showNameAndTicker
    // 0 = the full Yahoo Finance symbol (BRD.RO), 1 = the base symbol (BRD),
    // 2 = the base symbol with a short exchange badge (BRD · BVB).
    readonly property int symbolDisplayMode: {
        var mode = Number(app.config.symbolDisplayMode);
        return mode >= 0 && mode <= 2 ? mode : 0;
    }
    // Polling interval, shown by the market-status tooltip so the refresh rate is visible.
    readonly property int refreshIntervalMinutes: app.config.refreshInterval

    // Yahoo returns some non-US short names from a fixed-width vendor field: the company
    // name is padded with spaces and followed by a share-class letter, e.g.
    // "DEUTSCHE LUFTHANSA AG         V". That padding is not part of the name, so use the
    // long name for those quotes and collapse any whitespace that is left over.
    function companyName(meta, fallback) {
        return Symbols.companyName(meta, fallback);
    }

    // What the widget shows for a ticker. The stored symbol always stays the full Yahoo
    // one: it is the key for quote requests, portfolio lots and the selected row.
    function displayTicker(ticker) {
        return Symbols.displayTicker(ticker, root.symbolDisplayMode);
    }

    // Short exchange label for the badge, or "" when badges are off, the symbol has no
    // exchange suffix, or no exchange is known. A plain US ticker has no suffix to
    // replace, so it does not need a badge.
    function exchangeBadge(ticker, exchange) {
        return Symbols.exchangeBadge(ticker, exchange, root.symbolDisplayMode);
    }

    // Name and ticker together: "Company Name (TICK)", or "TICK (Company Name)" when
    // "swap names" is on. Falls back to just the ticker while the name is not known yet
    // or when Yahoo only returned the ticker as the name.
    function nameAndTicker(name, ticker) {
        return Symbols.nameAndTicker(name, ticker, root.swapNameAndTicker, root.loadingText);
    }

    // Same text, but when it does not fit in `avail` pixels only the company name is shortened
    // ("Advanced Micro… (AMD)" / "AMD (Advanced Micro…)"), so the ticker always stays visible.
    // When there is hardly any room for the name, only the ticker is shown.
    // `metrics` is a FontMetrics of the Text.
    function fitNameAndTicker(name, ticker, avail, metrics) {
        var full = nameAndTicker(name, ticker);
        if (avail <= 0 || metrics.advanceWidth(full) <= avail) return full;
        var t = (ticker || "").trim().toUpperCase();
        if (full === t) return full;
        var before = root.swapNameAndTicker ? t + " (" : "";
        var after = root.swapNameAndTicker ? ")" : " (" + t + ")";
        var room = avail - metrics.advanceWidth(before + after);
        if (room < metrics.advanceWidth("MMM…")) return t;
        return before + metrics.elidedText(name, Qt.ElideRight, room) + after;
    }
    property string chartRange: app.config.chartRange
    // Range selected with the buttons in the chart. It only affects the chart; the
    // multi-stock list keeps using `chartRange` from the settings.
    property string chartViewRange: app.config.chartViewRange
    // The value actually used by the chart. Keeping it apart from the config binding means
    // a button click takes effect immediately, even if the config write is delivered later.
    property string chartViewRangeActive: root.chartViewRange
    readonly property string effectiveChartRange: root.showChartRangeButtons && root.chartViewRangeActive
                                                 ? root.chartViewRangeActive : root.chartRange
    // Show the range selector in the chart instead of using the preset from the settings.
    property bool showChartRangeButtons: app.config.showChartRangeButtons
    // Time Limits Config
    property bool limitHours: app.config.limitHours
    property bool skipWeekendRefresh: app.config.skipWeekendRefresh
    property int startHour: app.config.startHour
    property int startMinute: app.config.startMinute
    property int endHour: app.config.endHour
    property int endMinute: app.config.endMinute
    // Placeholders shown while a quote is still being fetched. They are kept in
    // properties so the text that is displayed is the same one the code compares against.
    readonly property string loadingText: i18n("Loading...")
    // Short session tags in the panel. Properties, because the width reserved for the
    // widest tag is measured from the same strings that are displayed.
    readonly property string tagPreMarket: i18nc("@item:panel stock market session tag", "PRE")
    readonly property string tagAfterHours: i18nc("@item:panel stock market session tag", "AH")
    readonly property string tagClosed: i18nc("@item:panel stock market session tag", "CLOSED")
    // Internal Properties for Single View
    property string singleCompanyName: root.loadingText
    // Exchange of the single-view symbol: short label (BVB) and Yahoo's full name
    // (Bucharest Stock Exchange). Kept apart from the ticker for display only.
    property alias singleExchange: quoteStore.singleExchange
    property alias singleExchangeFull: quoteStore.singleExchangeFull
    property alias currentPrice: quoteStore.currentPrice
    property alias currentRawPrice: quoteStore.currentRawPrice
    // Timestamp of the quote (seconds since epoch), shown by the market-status tooltip so
    // it is clear how fresh the Yahoo Finance data is.
    property alias quoteTimestamp: quoteStore.quoteTimestamp
    property alias priceChange: quoteStore.priceChange
    property alias percentChange: quoteStore.percentChange
    property alias chartDataPoints: quoteStore.chartDataPoints
    // Unix timestamps (seconds) parallel to chartDataPoints, used for the chart's time scale.
    property alias chartTimestamps: quoteStore.chartTimestamps
    // Pre-market / after-hours points around the displayed 1D session (see
    // extendedSessionSeries), or null when the chart shows the regular session only.
    property alias chartSessions: quoteStore.chartSessions
    // Candle aggregates (open/high/low/close/volume/time) for the candlestick chart, and
    // yesterday's close, used as the reference line of the reference-line chart.
    property alias chartCandles: quoteStore.chartCandles
    property alias chartReferencePrice: quoteStore.chartReferencePrice
    // Start of the session a 1D chart is showing, and whether it is today's session (the
    // running pre-market or the regular one). When it is not, the chart still shows a
    // previous session and the view labels it so it is not mistaken for today's.
    property alias chartSessionStart: quoteStore.chartSessionStart
    property alias chartSessionCurrent: quoteStore.chartSessionCurrent
    // True when the 1D chart plots the running pre-market; the canvas hatches it like the
    // pre-market zone of a full-day chart.
    property alias chartPreSession: quoteStore.chartPreSession
    // Evaluated here rather than in the threaded Canvas paint, so the legend text is
    // translated on the main thread.
    readonly property string chartReferenceLabel: i18nc("@item:chart previous close", "Previous close")
    property alias previousClose: quoteStore.previousClose
    property alias isPositive: quoteStore.isPositive
    property alias currencySym: quoteStore.currencySym
    // The currency Yahoo quotes the shown instrument in (e.g. "USD", "GBp"). Used to
    // convert the live price to the currency a portfolio lot was bought in.
    property alias quoteCurrency: quoteStore.quoteCurrency
    // Values for the compact panel indicator. They always follow the configured data
    // range; the range picked only for the chart must not change them.
    property alias panelCurrentPrice: quoteStore.panelCurrentPrice
    property alias panelCurrentPercent: quoteStore.panelCurrentPercent
    property alias panelCurrentIsPositive: quoteStore.panelCurrentIsPositive
    readonly property string panelSymbol: root.isMultiMode ? root.panelTicker : root.singleTicker
    // --- THEME ---
    // The colour system lives in platform/Theme.qml; the applet passes the system palette
    // in and exposes the result under the names the views already use.
    readonly property int themePreset: app.theme.themePreset
    readonly property int themeColors: app.theme.themeColors
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool usesPlasmaSurface: app.theme.usesPlasmaSurface
    readonly property bool appDrawnSurface: app.theme.appDrawnSurface
    readonly property bool systemLightColors: app.theme.systemLightColors
    readonly property bool appLightPalette: app.theme.appLightPalette
    readonly property bool isLightTheme: app.theme.isLightTheme
    readonly property color panelTextColor: app.theme.panelTextColor
    readonly property color panelPositiveColor: app.theme.panelPositiveColor
    readonly property color panelNegativeColor: app.theme.panelNegativeColor
    // A vertical panel constrains the applet to the panel thickness.
    readonly property bool isVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property color contrastBackground: app.theme.contrastBackground
    readonly property color positiveColor: app.theme.positiveColor
    readonly property color negativeColor: app.theme.negativeColor
    readonly property color tickerColor: app.theme.tickerColor
    readonly property int tickerOpacity: app.theme.tickerOpacity
    readonly property color priceColor: app.theme.priceColor
    readonly property int priceOpacity: app.theme.priceOpacity
    readonly property int bgOpacity: app.theme.bgOpacity

    property bool hideChangePercentage: app.config.hideChangePercentage
    property bool hideTimestamps: app.config.hideTimestamps
    property bool formatPrices: app.config.formatPrices
    property bool hideDecimals: app.config.hideDecimals
    property bool showChartAxis: app.config.showChartAxis
    property bool showTimeAxis: app.config.showTimeAxis
    // 0 = reference line split at the session open, 1 = candlesticks.
    property int chartStyle: app.config.chartStyle === 1 ? 1 : 0
    // 0 = smooth line, 1 = straight segments.
    property int chartLineStyle: app.config.chartLineStyle === 1 ? 1 : 0
    // Show the Line/Candles toggle in the chart.
    property bool showChartStyleButtons: app.config.showChartStyleButtons
    // Volume is opt-in and is drawn for both chart styles.
    property bool showChartVolume: app.config.showChartVolume
    // Analyst price-target markers under the chart, also opt-in.
    property bool showAnalystTargets: app.config.showAnalystTargets
    property bool showChartHover: app.config.showChartHover
    // Latest news headlines for the single-stock view (the Chart/News icons in its header).
    property bool showNews: app.config.showNews
    property bool newsSourceYahoo: app.config.newsSourceYahoo
    property bool newsSourceBvb: app.config.newsSourceBvb
    property bool newsSourceGoogle: app.config.newsSourceGoogle
    property int newsCount: app.config.newsCount
    property int newsRefreshMinutes: app.config.newsRefreshMinutes
    // "chart" or "news": what the single-stock view shows below the quote. Not persisted:
    // the widget always starts on the chart, so a login never fetches news.
    property string singleViewPane: "chart"
    // Portfolio Tracking (purchase price vs current price). Each purchase is its own lot
    // (same ticker can have several, bought at different prices); the lots of a ticker are
    // added up into one position, summarised on a single line.
    property bool showPortfolioMode: app.config.showPortfolioMode
    property string portfolioData: app.config.portfolioData
    // Currency the portfolio totals are shown in. Lots keep their own currency; this is
    // only the common currency they are converted to when they have to be added up.
    property string portfolioCurrency: Currency.isKnown(app.config.portfolioCurrency)
                                        ? Currency.major(app.config.portfolioCurrency)
                                        : "USD"
    property var portfolioSummary: root.getPortfolioSummary(root.singleTicker, root.portfolioData, root.currentRawPrice, root.previousClose, root.quoteCurrency)
    property bool hasPortfolioEntry: root.portfolioSummary !== null
    // What the change in the summary covers: today for the 1D chart, otherwise the chart range.
    property string portfolioChangeLabel: root.chartRange === "1D" ? i18n("Today") : root.rangeLabel(root.chartRange)
    // Same label for the chart/single view, which can use a range of its own.
    readonly property string chartPeriodLabel: root.effectiveChartRange === "1D" ? i18n("Today") : root.rangeLabel(root.effectiveChartRange)
    property string lastUpdated: ""
    property string nextUpdate: ""
    // The range and ticker the current single-view numbers were fetched for (empty while
    // they are placeholders). The cache stores change/percentage per range, so a save
    // that races a ticker or range change must not label old values as the new ones.
    property alias singleDataRange: quoteStore.singleDataRange
    property alias singleDataTicker: quoteStore.singleDataTicker
    // The last successful quote batch, persisted in the applet config. At login Plasma
    // can start the widget before the network (or a VPN) is up; showing the previous
    // values with their real timestamp keeps the widget useful as long as they are
    // never presented as live prices.
    property alias cachedQuotesTime: quoteCache.cachedQuotesTime
    // True while the list (or, in single mode, the whole view) still shows cached values.
    property alias showingCachedData: quoteCache.showingCachedData
    // Whether the values in the panel indicator come from the snapshot. In multi mode one
    // row can still be cached while another is already live, so the panel marks its own
    // ticker instead of trusting the list-wide flag.
    property alias panelCurrentIsCached: quoteStore.panelCurrentIsCached
    readonly property string cachedQuotesLabel: root.cachedQuotesTime > 0
        ? new Date(root.cachedQuotesTime * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
        : ""
    // One status line for the list and the tooltip: the cached state replaces the usual
    // "Updated … Next …" so the age of the data is never hidden.
    readonly property string updateStatusText: root.showingCachedData
        ? i18n("Cached data from %1", root.cachedQuotesLabel)
        : (root.lastUpdated !== "" && root.nextUpdate !== ""
           ? i18n("Updated: %1 • Next: %2", root.lastUpdated, root.nextUpdate) : "")
    // The single view can show a live row while another list row is still cached, so its
    // line follows its own ticker rather than the list-wide state.
    readonly property bool currentShowingCached: !root.showingCachedData ? false
        : (!root.isMultiMode || root.rowIsCached(root.panelSymbol))
    readonly property string currentStatusText: root.currentShowingCached
        ? i18n("Cached data from %1", root.cachedQuotesLabel)
        : (root.lastUpdated !== "" && root.nextUpdate !== ""
           ? i18n("Updated: %1 • Next: %2", root.lastUpdated, root.nextUpdate) : "")
    // Amber that stays readable on light and dark cards, used while data is cached.
    readonly property color warningTextColor: app.theme.warningTextColor
    readonly property color bgColor: app.theme.bgColor
    readonly property color chartBaseColor: app.theme.chartBaseColor
    readonly property color secondaryTextColor: app.theme.secondaryTextColor

    Component.onCompleted: {
        app.config.migrateThemeSettings();
        // Before the startup timer sends its first request, so the placeholders are
        // replaced by the previous values while the network comes up.
        root.readCachedQuotes();
    }

    function getCurrencySymbol(code) {
        return Format.currencySymbol(code);
    }

    // --- EXCHANGE RATES ---
    // The rates, their cache and the hourly refresh live in FxController; these wrappers
    // keep the API the portfolio views already use.
    readonly property var exchangeRates: app.fx.exchangeRates
    readonly property double exchangeRatesUpdated: app.fx.exchangeRatesUpdated
    readonly property double exchangeRatesNext: app.fx.exchangeRatesNext
    readonly property bool exchangeRatesFetching: app.fx.exchangeRatesFetching

    function convertMoney(amount, from, to) {
        return app.fx.convertMoney(amount, from, to);
    }

    function exchangeRatesDue() { return app.fx.exchangeRatesDue(); }
    function finishExchangeRates(error) { app.fx.finishExchangeRates(error); }
    function saveExchangeRates(base, rates, updated, next) {
        return app.fx.saveExchangeRates(base, rates, updated, next);
    }
    function fetchExchangeRates() { app.fx.fetchExchangeRates(); }
    function maybeRefreshExchangeRates() { app.fx.maybeRefreshExchangeRates(); }

    // --- NEWS HEADLINES ---
    // Fetched only while the News pane is on screen, never by the quote timer. Kept in
    // memory per symbol, so switching rows in the two-column view reuses fresh results;
    // headlines go stale quickly, so they are not saved in the config like the quotes.
    // Yahoo supplies the general headlines, Google News searches the web by company
    // name, and Bucharest symbols (.RO) also get the issuer's announcements from BVB.
    // All are merged into `items`, each item keeping its `source`, so the news view can
    // filter by provider.
    // Set by our own panel popup; Plasma's popup reports through `expanded`.
    property bool panelPopupShown: false
    readonly property bool fullViewShown: !root.inPanel || root.expanded || root.panelPopupShown
    // The News pane exists only when the feature is on and at least one source can
    // provide something for the shown symbol; the controller's registry decides that
    // (BVB only covers Romanian listings, for example).
    readonly property bool newsAvailable: root.showNews
                                          && root.singleTicker.trim() !== ""
                                          && newsController.available
    // The single-stock view is not shown in the list-only multi-stock view.
    readonly property bool newsPaneShown: root.newsAvailable && root.singleViewPane === "news"
                                          && root.fullViewShown && (!root.isMultiMode || root.showTwoList)
                                          && root.singleTicker.trim() !== ""

    NewsController {
        id: newsController
        applet: root
    }

    readonly property var newsEntry: newsController.entry
    readonly property var newsItems: newsController.items

    function newsKey(symbol) { return newsController.newsKey(symbol); }
    function requestNews(symbol, force) { newsController.requestNews(symbol, force); }
    function refreshNewsSources() { newsController.refreshNewsSources(); }
    function retryNewsWithName() { newsController.retryNewsWithName(); }
    function newsAge(timeSec) { return newsController.newsAge(timeSec); }
    function openNewsLink(url) { newsController.openNewsLink(url); }
    function openYahooNews(symbol) { newsController.openYahooNews(symbol); }
    function openBvbNews(symbol) { newsController.openBvbNews(symbol); }
    function openGoogleNews(symbol) { newsController.openGoogleNews(symbol); }

    // --- ANALYST PRICE TARGETS ---
    // Fetched only when the option is on, for the shown symbol. The controller keeps
    // one cached reply per ticker; the chart reads the items and draws the markers.
    AnalystController {
        id: analystController
        applet: root
    }
    readonly property var analystItems: analystController ? analystController.items : []
    readonly property var analystSummary: analystController ? analystController.summary : null
    function requestAnalystTargets(force) {
        if (analystController) analystController.request(root.singleTicker, force);
    }
    onShowAnalystTargetsChanged: {
        if (root.showAnalystTargets) root.requestAnalystTargets(false);
    }
    Timer {
        interval: 6 * 60 * 60 * 1000
        running: root.showAnalystTargets && root.singleTicker.trim() !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.requestAnalystTargets(false)
    }

    onShowNewsChanged: {
        if (!root.showNews) root.singleViewPane = "chart";
    }
    onNewsSourceYahooChanged: Qt.callLater(root.refreshNewsSources)
    onNewsSourceBvbChanged: Qt.callLater(root.refreshNewsSources)
    onNewsSourceGoogleChanged: Qt.callLater(root.refreshNewsSources)
    // A larger count must not wait for the next interval.
    onNewsCountChanged: {
        newsController.invalidate();
        if (root.newsPaneShown) root.requestNews(root.singleTicker, true);
    }
    onSingleCompanyNameChanged: Qt.callLater(root.retryNewsWithName)
    onSingleDataTickerChanged: Qt.callLater(root.retryNewsWithName)

    // --- PORTFOLIO TRACKING HELPERS ---
    // A ticker can have several saved lots (bought at different times/prices). They are added up
    // into one position with the figures a portfolio view leads with: shares, average cost,
    // market value, total gain (against the cost of all the lots) and the gain over the period
    // the widget shows (today for the 1D chart). Returns null when the ticker has no lots.
    //
    // Every lot's average cost is in that lot's own currency. The live quote is in the
    // instrument's Yahoo currency, so it is converted before it is compared with the cost.
    // A position whose lots all share a currency is shown in that currency; mixed lots are
    // converted to the configured portfolio currency so they can be added up.
    function getPortfolioSummary(ticker, dataStr, rawPrice, prevClose, quoteCurrency) {
        return Portfolio.getPortfolioSummary(ticker, dataStr, rawPrice, prevClose, quoteCurrency,
                                             root.portfolioCurrency, root.convertMoney, Currency);
    }

    // "-$1,234.50", or "+$1,234.50" when `signed` and the amount is positive.
    function formatMoney(sym, v, signed) {
        return Format.money(sym, v, signed, root.hideDecimals, root.formatPrices);
    }

    function getPortfolioTickers(dataStr) {
        return Portfolio.getPortfolioTickers(dataStr);
    }

    // The stored data-range codes ("1D", "5D", …) are what the API and the config use;
    // this is the (translated) label shown for them in the views and the tooltip.
    function rangeLabel(range) {
        switch (range) {
            case "1D":  return i18n("1D");
            case "5D":  return i18n("5D");
            case "1M":  return i18n("1M");
            case "6M":  return i18n("6M");
            case "YTD": return i18n("YTD");
            case "1Y":  return i18n("1Y");
            case "5Y":  return i18n("5Y");
            case "Max": return i18n("Max");
            default:    return range;
        }
    }

    // Label for the range buttons in the chart. The whole history is called "All" there,
    // as in Yahoo Finance, while the stored/configured value stays "Max".
    function chartRangeButtonLabel(range) {
        return range === "Max" ? i18nc("@item:chart range", "All") : root.rangeLabel(range);
    }

    // Range selected from the chart buttons. It is stored separately from the list's
    // configured range, so switching the chart range does not reload the whole list.
    function setChartViewRange(range) { actions.setChartViewRange(range); }

    // Chart type selected from the chart buttons. It writes the same setting as the
    // Chart & News page, so both stay in sync.
    function setChartStyle(style) { actions.setChartStyle(style); }

    // Side-by-side layout: the divider applies the width live and the configuration is
    // written only when the drag ends, so moving it does not hammer the config file.
    function setTwoColumnLeftWidth(width) { actions.setTwoColumnLeftWidth(width); }
    function saveTwoColumnLeftWidth() { actions.saveTwoColumnLeftWidth(); }

    // Copy the list row's values (configured data range) into the panel indicator.
    function updatePanelFromRow(ticker) { actions.updatePanelFromRow(ticker); }

    // Select a watchlist row. The list already has the row's quote, so only the chart
    // needs a request; refreshing the whole list here made all rows update in chunks
    // before the selected ticker's chart arrived.
    function selectTicker(ticker, persist) { actions.selectTicker(ticker, persist); }

    // --- MOUSE ACTIONS ---
    // Open the Yahoo Finance quote page for a symbol. Used by the configurable mouse
    // actions and by the context menus, so all paths behave the same.
    function openYahooQuote(symbol) { actions.openYahooQuote(symbol); }

    // Left click on a watchlist row: select it (recommended) or open its quote page.
    function performRowLeftClick(symbol) { actions.performRowLeftClick(symbol); }

    // Middle click on a row, the chart or the panel indicator. Returns true when the
    // action was a refresh, so the caller can show the existing opacity flicker.
    function performMiddleClick(symbol) { return actions.performMiddleClick(symbol); }

    function performDoubleClick(symbol) { actions.performDoubleClick(symbol); }

    // --- PRE-MARKET / AFTER-HOURS ---
    // The extended-hours state, the session clock and the selection rules live in
    // MarketController; these wrappers keep the API used by the views and the quote
    // workflows.
    property bool showExtendedHours: app.config.showExtendedHours
    property bool keepExtendedAfterClose: app.config.keepExtendedAfterClose

    function setExtendedData(symbol, entry) { app.market.setExtendedData(symbol, entry); }
    function setLastExtendedData(symbol, entry) { app.market.setLastExtendedData(symbol, entry); }
    function setMarketSession(symbol, meta) { app.market.setMarketSession(symbol, meta); }
    function hasPrePostDataFor(symbol) { return app.market.hasPrePostDataFor(symbol); }
    function marketStatusFor(symbol) { return app.market.statusFor(symbol); }
    function isMarketClosedFor(symbol) { return app.market.isMarketClosedFor(symbol); }
    function awaitingFirstRegularQuote(symbol) { return app.market.awaitingFirstRegularQuote(symbol); }
    function extendedQuote(symbol) { return app.market.extendedQuoteFor(symbol); }
    function processExtendedData(symbol, json) { app.market.processExtendedData(symbol, json); }
    function fetchExtendedHours(symbol) { app.market.fetchExtendedHours(symbol); }

    function refreshExtendedHours() { refreshCycle.refreshExtended(); }

    onShowExtendedHoursChanged: {
        if (!showExtendedHours) app.market.clearExtended();
        // The 1D chart request includes pre/post data only while this is on.
        refreshData();
    }

    onKeepExtendedAfterCloseChanged: {
        if (keepExtendedAfterClose) {
            if (showExtendedHours) refreshExtendedHours();
        } else {
            app.market.clearLastExtended();
        }
    }

    function refreshData() { refreshCycle.refreshQuotes(); }

    // --- NEW CHECK: IS MARKET OPEN? ---
    function checkTimeAndRefresh() { refreshCycle.checkTime(); }

    // --- STARTUP RETRY / CACHED QUOTES ---
    // The retry back-off and the persisted quote snapshot live in QuoteCacheController;
    // these wrappers keep the API the quote controllers and the views already use.
    function scheduleQuoteRetry() { quoteCache.scheduleQuoteRetry(); }
    function noteQuoteReceived() { quoteCache.noteQuoteReceived(); }
    function readCachedQuotes() { quoteCache.read(); }
    function parseCachedQuotes() { return quoteCache.parse(); }
    function applyCachedQuotesToRows() { quoteCache.applyToRows(); }
    function applyCachedSingleFromRow(ticker) { quoteCache.applySingleFromRow(ticker); }
    function refreshCachedRowsState() { quoteCache.refreshRowsState(); }
    function dropUnrefreshedCachedRows() { quoteCache.dropUnrefreshed(); }
    function queueQuotesCacheSave() { quoteCache.queueSave(); }
    function writeQuotesCache() { quoteCache.write(); }

    function fetchSingleStock(symbol, range) {
        singleQuote.fetch(symbol, range);
    }

    // Quote for the compact panel indicator, fetched separately when the chart uses a
    // range of its own. The panel always follows the configured data range.
    function fetchPanelStock(symbol) {
        singleQuote.fetchPanel(symbol);
    }

    // The configured watchlist, cleaned and in display order.
    function configuredTickers() {
        return watchlist.configuredTickers();
    }

    // Creates the list placeholders in display order and keeps the panel selection. Used
    // before fetching, and by the cached values at startup when a refresh is skipped
    // (weekend, or outside the configured hours), so the list is not left empty.
    function ensureStockRows(targetTickers) {
        watchlist.ensureRows(targetTickers);
    }

    function fetchMultiStocks() {
        watchlist.fetch();
    }

    function formatNumber(amount, isChange) {
        return Format.number(amount, isChange, root.hideDecimals, root.formatPrices);
    }

    // Empty the list and forget any cached state attached to its rows. The next fetch
    // re-applies the snapshot when it belongs to the new tickers/range.
    function clearStockRows() {
        stockModel.clear();
        // Do not persist the rows that are about to be rebuilt.
        quoteCache.stopPendingSave();
        root.showingCachedData = false;
        root.panelCurrentIsCached = false;
        quoteCache.stopGrace();
    }
    onSingleTickerChanged: {
        // In multi mode selecting a row reuses its cached chart; the periodic list
        // refresh keeps that cache current, so no request is needed here. Only the
        // single view needs a refresh when its configured ticker changes.
        if (!root.isMultiMode) {
            // The values on screen (and any save already queued) belong to the previous
            // ticker, not to the one that is about to be fetched.
            quoteCache.stopPendingSave();
            root.singleDataRange = "";
            root.singleDataTicker = "";
            // Drop the previous symbol's exchange badge; the suffix fallback is enough
            // until the new quote supplies the real exchange name.
            root.singleExchange = Exchanges.shortLabel(root.singleTicker, "", "");
            root.singleExchangeFull = root.singleExchange;
            // A cached single-view value belongs to the previous ticker; carrying it
            // over would show the old symbol's price under the new one if the network
            // is still down.
            if (root.showingCachedData) {
                root.showingCachedData = false;
                root.panelCurrentIsCached = false;
                root.singleCompanyName = root.loadingText;
                root.currentPrice = "---";
                root.priceChange = "";
                root.percentChange = "";
                root.currentRawPrice = 0;
                root.previousClose = 0;
                root.quoteTimestamp = 0;
                root.panelCurrentPrice = "---";
                root.panelCurrentPercent = "+0.00%";
            }
            root.readCachedQuotes();
            root.refreshData();
        }
        if (root.newsPaneShown) root.requestNews(root.singleTicker, false);
        if (root.showAnalystTargets) Qt.callLater(function() { root.requestAnalystTargets(false); });
    }
    onIsMultiModeChanged: {
        root.clearStockRows();
        if (!isMultiMode) {
            root.singleTicker = Qt.binding(function() { return app.config.ticker; });
            quoteCache.stopPendingSave();
            root.singleDataRange = "";
            root.singleDataTicker = "";
            root.singleCompanyName = root.loadingText;
            root.currentPrice = "---";
            root.priceChange = "";
            root.percentChange = "";
            root.chartDataPoints = [];
            root.chartTimestamps = [];
            root.chartSessions = null;
            root.chartCandles = [];
            root.chartReferencePrice = 0;
            root.readCachedQuotes();
        }
        refreshData();
    }
    onMultiTickersChanged: { root.clearStockRows(); refreshData(); }
    onSortAlphabeticallyChanged: { root.clearStockRows(); refreshData(); }
    onFormatPricesChanged: refreshData()
    onHideDecimalsChanged: refreshData()
    // CHANGED: Update when the list's configured range changes
    onChartRangeChanged: {
        // The values on screen (and any save already queued) belong to the previous
        // range, not to the one that is about to be fetched.
        quoteCache.stopPendingSave();
        root.singleDataRange = "";
        root.singleDataTicker = "";
        // A cached change belongs to the range it was fetched with; do not keep it on
        // screen under the new range while the first request is in flight.
        if (!root.isMultiMode && root.showingCachedData) {
            root.showingCachedData = false;
            root.panelCurrentIsCached = false;
            root.currentPrice = "---";
            root.priceChange = "";
            root.percentChange = "";
            root.currentRawPrice = 0;
            root.previousClose = 0;
            root.quoteTimestamp = 0;
            root.panelCurrentPrice = "---";
            root.panelCurrentPercent = "+0.00%";
        }
        root.clearStockRows();
        refreshData();
    }
    // The chart's own range only refreshes the chart, never the list.
    onChartViewRangeChanged: {
        // A value changed outside the chart buttons (backup import, for example).
        if (root.chartViewRangeActive === root.chartViewRange) return;
        root.chartViewRangeActive = root.chartViewRange;
        if (root.showChartRangeButtons && root.singleTicker.trim() !== "")
            root.fetchSingleStock(root.singleTicker, root.effectiveChartRange);
    }
    onShowChartRangeButtonsChanged: {
        if (root.singleTicker.trim() !== "")
            root.fetchSingleStock(root.singleTicker, root.effectiveChartRange);
    }
    // Note: no explicit handler needed when portfolioData changes — both the single-ticker
    // view and the multi-stock list compute their lot P/L directly from root.portfolioData
    // in their bindings, so QML re-evaluates them automatically.

    // --- TOOLTIP ---
    // Plasma's fallback tooltip for an applet is the name and the description from
    // metadata.json ("Plasma Stock Monitor" / "Modernized stock monitor for KDE…"), which says
    // nothing about the stocks. Put the quotes in it instead: the heading names the stock
    // (or the number of stocks) and the body lists the prices and changes, in the
    // same gain/loss colours as the rest of the widget.
    toolTipMainText: tooltipContent.title
    toolTipSubText: tooltipContent.body
    toolTipTextFormat: Text.RichText

    // ListModel rows do not notify property reads through get(), so the body is bound to
    // this counter and the connections below bump it whenever the model changes.
    property int tooltipRevision: 0

    Connections {
        target: stockModel
        function onDataChanged() { root.tooltipRevision++ }
        function onRowsInserted() { root.tooltipRevision++ }
        function onRowsRemoved() { root.tooltipRevision++ }
        function onModelReset() { root.tooltipRevision++ }
    }

    TooltipContent {
        id: tooltipContent
        applet: root
        stockList: stockModel
    }

    // Whether a list row still shows its restored value. Reading tooltipRevision makes
    // bindings that call this re-evaluate whenever a row changes.
    function rowIsCached(ticker) {
        var revision = root.tooltipRevision;
        for (var i = 0; i < stockModel.count; i++) {
            var row = stockModel.get(i);
            if (row.ticker === ticker) return row.cached === true;
        }
        return false;
    }

    // Optionally show the price and the change percentage in the same spot of
    // the panel indicator, switching between them every N seconds, instead of
    // showing both side by side.
    readonly property bool panelAlternate: app.config.alternatePricePercent
                                           && !root.hideChangePercentage
                                           && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    // The expanded panel view uses our transparent popup for Application, which paints
    // its own cards. Plasma keeps the standard Plasma popup and its system background.
    readonly property bool customPanelPopup: !root.usesPlasmaSurface
    property bool panelShowPercent: false

    RefreshController {
        id: refreshCycle
        applet: root
        market: app.market
    }

    Timer {
        interval: Math.max(3, app.config.alternateInterval) * 1000
        running: root.panelAlternate
        repeat: true
        onTriggered: root.panelShowPercent = !root.panelShowPercent
        onRunningChanged: if (!running) root.panelShowPercent = false
    }

    // Exchange rates change once a day. Checking hourly keeps the download close to the
    // feed's own daily update without polling it repeatedly; the cached rates are only
    // replaced when a complete response arrives.
    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.maybeRefreshExchangeRates()
    }

    // Optionally rotate the panel stock every N seconds (multi-stock mode).
    // The panel text is filled from the already-fetched list data; a single
    // request then refreshes the chart for the newly selected stock.
    Timer {
        interval: Math.max(3, app.config.autoCycleInterval) * 1000
        // Pause while the full view is open, so the stock does not change under the user.
        running: app.config.autoCycle && root.isMultiMode && stockModel.count > 1
                 && !root.expanded
        repeat: true
        onTriggered: {
            var current = 0;
            for (var i = 0; i < stockModel.count; i++) {
                if (stockModel.get(i).ticker === root.panelTicker) { current = i; break; }
            }
            var row = stockModel.get((current + 1) % stockModel.count);
            // The panel takes the cached list row; only the chart is fetched.
            // Auto-cycling is not a user selection, so do not persist it.
            root.selectTicker(row.ticker, false);
        }
    }

    // Open the expanded panel view in Plasma's popup (with its background) or in our own
    // popup, which draws no background and therefore shows only the widget's surface.
    function togglePanelPopup() {
        if (!root.customPanelPopup) {
            root.expanded = !root.expanded;
            return;
        }

        if (!panelPopupWindowLoader.item)
            panelPopupWindowLoader.active = true;

        var popup = panelPopupWindowLoader.item;
        if (!popup)
            return;

        if (popup.visible)
            popup.visible = false;
        else if (!root.panelPopupRecentlyClosed)
            popup.visible = true;
    }

    // The dialog hides itself when it loses focus. That is what a click on the panel
    // widget does, so ignore that same click briefly instead of reopening the popup.
    property bool panelPopupRecentlyClosed: false
    Timer {
        id: panelPopupCloseGuard
        interval: 250
        onTriggered: root.panelPopupRecentlyClosed = false
    }

    onCustomPanelPopupChanged: {
        // Close the mode that is no longer selected, so changing the theme takes effect
        // immediately instead of leaving the old popup on screen.
        if (!root.customPanelPopup) {
            if (panelPopupWindowLoader.item)
                panelPopupWindowLoader.item.visible = false;
            panelPopupWindowLoader.active = false;
        } else {
            root.expanded = false;
        }
    }

    // --- PANEL VIEW (Compact Representation) ---
    compactRepresentation: CompactPanel {
        applet: root
        stockList: stockModel
    }

    // --- FULL VIEW (desktop widget and the panel expanded popup) ---

    Component {
        id: fullViewComponent

        FullView {
            applet: root
            stockList: stockModel
        }
    }

    // Assign after the component has been declared, so Plasma never sees a null full
    // representation during initialisation on older Plasma versions.
    fullRepresentation: fullViewComponent

    // Plasma always draws the frame of the popup it creates for an expanded panel applet.
    // When the user disables that background, show the same full view in our own popup
    // with no background instead, so only the two widget cards remain visible.
    //
    // The dialog is created on demand: with the default setting the applet never
    // instantiates it, which also keeps older Plasma versions safe at startup.
    Loader {
        id: panelPopupWindowLoader
        active: false
        sourceComponent: panelPopupComponent
    }

    Component {
        id: panelPopupComponent

        PlasmaCore.Dialog {
            id: panelPopup
            objectName: "panelPopup"

            type: PlasmaCore.Dialog.AppletPopup
            location: Plasmoid.location
            visible: false
            visualParent: root.compactRepresentationItem
            appletInterface: root
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: true

            onVisibleChanged: {
                root.panelPopupShown = visible;
                if (visible) {
                    Qt.callLater(function() { panelPopupFocus.forceActiveFocus(); });
                } else {
                    root.panelPopupRecentlyClosed = true;
                    panelPopupCloseGuard.restart();
                }
            }

            mainItem: FocusScope {
                id: panelPopupFocus
                focus: true

                Keys.onEscapePressed: panelPopup.visible = false

                // Mirror the full view's size hints so the dialog sizes itself exactly like
                // Plasma's standard expanded representation does.
                Layout.minimumWidth: panelPopupLoader.item ? panelPopupLoader.item.Layout.minimumWidth : 0
                Layout.minimumHeight: panelPopupLoader.item ? panelPopupLoader.item.Layout.minimumHeight : 0
                Layout.preferredWidth: panelPopupLoader.item ? Math.max(panelPopupLoader.item.Layout.preferredWidth,
                                                                         panelPopupLoader.item.Layout.minimumWidth) : 0
                Layout.preferredHeight: panelPopupLoader.item ? Math.max(panelPopupLoader.item.Layout.preferredHeight,
                                                                          panelPopupLoader.item.Layout.minimumHeight) : 0

                Loader {
                    id: panelPopupLoader
                    anchors.fill: parent
                    // Do not instantiate a second copy of the full view unless the custom
                    // panel popup is actually in use.
                    active: root.customPanelPopup
                    sourceComponent: fullViewComponent
                }

                // The no-background dialog has no theme frame, so Dialog's own resize
                // margins are zero. These invisible handles start the same system resize
                // that the standard Plasma popup uses.
                MouseArea {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 6
                    cursorShape: Qt.SizeVerCursor
                    onPressed: panelPopup.startSystemResize(Qt.TopEdge)
                }

                MouseArea {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 6
                    cursorShape: Qt.SizeVerCursor
                    onPressed: panelPopup.startSystemResize(Qt.BottomEdge)
                }

                MouseArea {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: panelPopup.startSystemResize(Qt.LeftEdge)
                }

                MouseArea {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: panelPopup.startSystemResize(Qt.RightEdge)
                }

                MouseArea {
                    anchors { top: parent.top; left: parent.left }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeFDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
                }

                MouseArea {
                    anchors { top: parent.top; right: parent.right }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeBDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.TopEdge | Qt.RightEdge)
                }

                MouseArea {
                    anchors { bottom: parent.bottom; left: parent.left }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeBDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
                }

                MouseArea {
                    anchors { bottom: parent.bottom; right: parent.right }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeFDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
                }
            }
        }
    }
}
