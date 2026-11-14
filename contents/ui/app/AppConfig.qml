import QtQuick

// Read-only, typed view of the applet configuration. Every default mirrors
// contents/config/main.xml, and the few values the code relies on are clamped here, so
// the rest of the app never has to guard against a missing or out-of-range entry.
//
// `configuration` is injected (the app passes Plasmoid.configuration, tests pass a
// plain object), which keeps this component free of Plasma and testable.
QtObject {
    id: config

    property var configuration: null

    function read(key) {
        return configuration ? configuration[key] : undefined;
    }
    function text(key, fallback) {
        var value = read(key);
        return (value === undefined || value === null || value === "") ? fallback : String(value);
    }
    function rawText(key, fallback) {
        var value = read(key);
        return (value === undefined || value === null) ? fallback : String(value);
    }
    function flag(key, fallback) {
        var value = read(key);
        return (value === undefined || value === null) ? fallback : value === true;
    }
    function integer(key, fallback) {
        var value = Number(read(key));
        return isFinite(value) ? Math.round(value) : fallback;
    }
    function clamped(key, fallback, min, max) {
        return Math.min(max, Math.max(min, integer(key, fallback)));
    }

    // Symbols and lists
    readonly property string ticker: rawText("ticker", "AAPL")
    readonly property bool isMultiMode: flag("isMultiMode", false)
    readonly property bool showTwoList: flag("showTwoList", false)
    readonly property int twoColumnLeftWidth: Math.max(0, integer("twoColumnLeftWidth", 0))
    readonly property string selectedTicker: text("selectedTicker", "")
    readonly property string multiTickers: rawText("multiTickers", "AAPL, TSLA")
    readonly property bool sortAlphabetically: flag("sortAlphabetically", false)
    readonly property bool swapNameAndTicker: flag("swapNameAndTicker", false)
    readonly property bool showNameAndTicker: flag("showNameAndTicker", true)
    readonly property int symbolDisplayMode: clamped("symbolDisplayMode", 0, 0, 2)

    // Mouse actions
    readonly property string mouseRowLeftAction: text("mouseRowLeftAction", "select")
    readonly property string mouseMiddleAction: text("mouseMiddleAction", "refresh")
    readonly property string mouseDoubleClickAction: text("mouseDoubleClickAction", "open")

    // Refresh
    readonly property int refreshInterval: Math.max(1, integer("refreshInterval", 5))
    readonly property bool limitHours: flag("limitHours", false)
    readonly property bool skipWeekendRefresh: flag("skipWeekendRefresh", true)
    readonly property int startHour: clamped("startHour", 9, 0, 23)
    readonly property int startMinute: clamped("startMinute", 15, 0, 59)
    readonly property int endHour: clamped("endHour", 15, 0, 23)
    readonly property int endMinute: clamped("endMinute", 30, 0, 59)

    // Chart
    readonly property string chartRange: text("chartRange", "1D")
    readonly property string chartViewRange: text("chartViewRange", "")
    readonly property bool showChartRangeButtons: flag("showChartRangeButtons", false)
    readonly property int chartStyle: clamped("chartStyle", 0, 0, 1)
    readonly property int chartLineStyle: clamped("chartLineStyle", 0, 0, 1)
    readonly property bool showChartStyleButtons: flag("showChartStyleButtons", false)
    readonly property bool showChartVolume: flag("showChartVolume", false)
    readonly property bool showAnalystTargets: flag("showAnalystTargets", false)
    readonly property bool showChartHover: flag("showChartHover", true)
    readonly property bool showChartAxis: flag("showChartAxis", true)
    readonly property bool showTimeAxis: flag("showTimeAxis", true)

    // News
    readonly property bool showNews: flag("showNews", false)
    readonly property bool newsSourceYahoo: flag("newsSourceYahoo", true)
    readonly property bool newsSourceBvb: flag("newsSourceBvb", true)
    readonly property bool newsSourceGoogle: flag("newsSourceGoogle", true)
    readonly property int newsCount: clamped("newsCount", 24, 5, 50)
    readonly property int newsRefreshMinutes: clamped("newsRefreshMinutes", 30, 10, 240)

    // Portfolio
    readonly property bool showPortfolioMode: flag("showPortfolioMode", false)
    readonly property string portfolioData: text("portfolioData", "")
    readonly property string portfolioCurrency: text("portfolioCurrency", "USD")

    // Extended hours
    readonly property bool showExtendedHours: flag("showExtendedHours", true)
    readonly property bool keepExtendedAfterClose: flag("keepExtendedAfterClose", true)

    // Panel
    readonly property bool hideChangePercentage: flag("hideChangePercentage", false)
    readonly property bool autoCycle: flag("autoCycle", false)
    readonly property int autoCycleInterval: Math.max(3, integer("autoCycleInterval", 15))
    readonly property bool hideTimestamps: flag("hideTimestamps", true)
    readonly property bool alternatePricePercent: flag("alternatePricePercent", false)
    readonly property int alternateInterval: Math.max(3, integer("alternateInterval", 15))

    // Appearance
    readonly property int themePreset: integer("themePreset", -1)
    readonly property int themeColors: integer("themeColors", -1)
    readonly property string tickerColor: text("tickerColor", "#FFFFFF")
    readonly property int tickerOpacity: clamped("tickerOpacity", 100, 0, 100)
    readonly property string priceColor: text("priceColor", "#FFFFFF")
    readonly property int priceOpacity: clamped("priceOpacity", 100, 0, 100)
    readonly property string positiveColor: text("positiveColor", "#4cd964")
    readonly property string negativeColor: text("negativeColor", "#FF3B30")
    readonly property int bgOpacity: clamped("bgOpacity", 100, 0, 100)
    readonly property bool panelBoldSymbol: flag("panelBoldSymbol", true)
    readonly property bool panelShowMarketStatus: flag("panelShowMarketStatus", true)

    // Formatting
    readonly property bool formatPrices: flag("formatPrices", true)
    readonly property bool hideDecimals: flag("hideDecimals", false)

    // Cached quotes (raw JSON string, parsed by the quote cache)
    readonly property string cachedQuotes: text("cachedQuotes", "")
    readonly property string cachedQuotesTime: text("cachedQuotesTime", "")

    // One-time rewrite of the old single Light/Dark/Plasma choice. Every new entry
    // defaults to -1 ("not migrated yet"), so a real value is what a previous run or the
    // settings dialog wrote; that makes the migration idempotent.
    function migrateThemeSettings() {
        if (!configuration) return;
        var c = configuration;
        // The Custom preset was removed: keep the background its desktop used.
        if (c.themePreset === 2) {
            c.themePreset = c.desktopThemeSource === 1 ? 1 : 0;
        }
        if (c.themePreset >= 0 && c.themeColors >= 0) return;
        try {
            var legacy = Number(c.selectedTheme);
            var preset = 1;
            var colors = 2;
            if (legacy === 0) {
                preset = 0;
                colors = 0;
            } else if (legacy === 1) {
                preset = 0;
                colors = 1;
            } else if (legacy === 2) {
                preset = 1;
            }
            // legacy === -1 means the old setting was never saved: use the new
            // defaults, Plasma with System colors.
            if (c.themePreset < 0) c.themePreset = preset;
            if (c.themeColors < 0) c.themeColors = colors;
        } catch (e) {
            console.log("Error migrating theme settings: " + e);
        }
    }
}
