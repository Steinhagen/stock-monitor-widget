import QtQuick
import QtTest

TestCase {
    name: "QuoteCacheController"

    Component {
        id: fakeApplet
        QtObject {
            property string singleTicker: "SAP.DE"
            property string panelTicker: "SAP.DE"
            property string singleCompanyName: ""
            property string singleExchange: ""
            property string singleExchangeFull: ""
            property string currentPrice: "---"
            property double currentRawPrice: 0
            property string priceChange: ""
            property string percentChange: ""
            property bool isPositive: true
            property double previousClose: 0
            property string currencySym: ""
            property string quoteCurrency: ""
            property double quoteTimestamp: 0
            property string panelCurrentPrice: "---"
            property string panelCurrentPercent: "+0.00%"
            property bool panelCurrentIsPositive: true
            property bool panelCurrentIsCached: false
            property string lastUpdated: ""
            property string nextUpdate: ""
            property string singleDataRange: ""
            property string singleDataTicker: ""
            property string chartRange: "1D"
            property string effectiveChartRange: "1D"
            property bool isMultiMode: false
            property string loadingText: "Loading..."

            property int panelUpdates: 0
            function checkTimeAndRefresh() {}
            function ensureStockRows(tickers) {}
            function configuredTickers() { return ["SAP.DE"] }
            function updatePanelFromRow(ticker) { panelUpdates++ }
        }
    }

    QtObject {
        id: fakeConfig
        property string cachedQuotes: ""
        property string cachedQuotesTime: "0"
    }

    QtObject {
        id: fakeConfiguration
        property string cachedQuotes: ""
        property string cachedQuotesTime: "0"
    }

    ListModel { id: rows }

    function snapshot(now) {
        return {
            "time": now, "range": "1D", "rowsRange": "1D", "rowsTime": now,
            "rows": [{ "ticker": "SAP.DE", "name": "SAP SE", "price": "€213.45",
                       "change": "+1.20", "pct": "+0.57%", "isPos": true,
                       "currentRaw": 213.45, "prevClose": 212.25,
                       "currencySym": "€ ", "currency": "EUR",
                       "exchange": "XETRA", "exchangeFull": "XETRA",
                       "quoteTime": now }],
            "single": { "ticker": "SAP.DE", "name": "SAP SE", "price": "€213.45",
                        "change": "+1.20", "pct": "+0.57%", "isPos": true,
                        "currentRaw": 213.45, "prevClose": 212.25,
                        "currencySym": "€ ", "currency": "EUR",
                        "exchange": "XETRA", "exchangeFull": "XETRA",
                        "quoteTime": now, "range": "1D" },
            "singleTime": now
        };
    }

    function make(applet) {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/QuoteCacheController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var cache = component.createObject(this, {
            "applet": applet, "model": rows, "configuration": fakeConfiguration, "config": fakeConfig
        });
        verify(cache !== null);
        return cache;
    }

    function reset() {
        rows.clear();
        fakeConfig.cachedQuotes = "";
        fakeConfig.cachedQuotesTime = "0";
        fakeConfiguration.cachedQuotes = "";
        fakeConfiguration.cachedQuotesTime = "0";
    }

    function test_readSingle() {
        reset();
        var now = Math.floor(Date.now() / 1000);
        fakeConfig.cachedQuotes = JSON.stringify(snapshot(now));
        fakeConfig.cachedQuotesTime = String(now);
        var applet = createTemporaryObject(fakeApplet, this);
        var cache = make(applet);
        cache.read();
        compare(applet.currentPrice, "€213.45");
        compare(applet.priceChange, "+1.20");
        compare(applet.quoteCurrency, "EUR");
        compare(applet.singleDataTicker, "SAP.DE");
        compare(applet.panelCurrentPrice, "€213.45");
        compare(applet.panelCurrentIsCached, true);
        compare(cache.showingCachedData, true);
        compare(cache.cachedQuotesTime, now);
    }

    function test_applyToRows() {
        reset();
        var now = Math.floor(Date.now() / 1000);
        fakeConfig.cachedQuotes = JSON.stringify(snapshot(now));
        fakeConfig.cachedQuotesTime = String(now);
        rows.append({ "ticker": "SAP.DE", "name": "Loading", "price": "---", "cached": false });
        var applet = createTemporaryObject(fakeApplet, this);
        applet.isMultiMode = true;
        var cache = make(applet);
        cache.read(); // multi mode: creates/caches rows through the applet stub
        // The stub's ensureStockRows does not build rows, so apply directly.
        cache.applyToRows();
        compare(rows.get(0).cached, true);
        compare(rows.get(0).price, "€213.45");
        verify(applet.lastUpdated !== "");
        compare(applet.panelUpdates, 1);
        compare(applet.currentPrice, "€213.45");
    }

    function test_write() {
        reset();
        var applet = createTemporaryObject(fakeApplet, this);
        var cache = make(applet);
        applet.currentPrice = "€213.45";
        applet.priceChange = "+1.20";
        applet.percentChange = "+0.57%";
        applet.singleDataTicker = "SAP.DE";
        applet.singleDataRange = "1D";
        applet.currentRawPrice = 213.45;
        applet.previousClose = 212.25;
        applet.quoteCurrency = "EUR";
        applet.singleCompanyName = "SAP SE";
        cache.write();
        var saved = JSON.parse(fakeConfiguration.cachedQuotes);
        compare(saved.single.ticker, "SAP.DE");
        compare(saved.single.price, "€213.45");
        verify(Number(fakeConfiguration.cachedQuotesTime) > 0);
        compare(cache.cachedQuotesTime, Number(fakeConfiguration.cachedQuotesTime));
    }
}
