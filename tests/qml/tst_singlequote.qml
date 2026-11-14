import QtQuick
import QtTest
import "Fixture.js" as Fixture

TestCase {
    name: "SingleQuoteController"

    Component {
        id: fakeApplet
        QtObject {
            property string singleTicker: "SAP.DE"
            property string singleCompanyName: ""
            property string effectiveChartRange: "1D"
            property string chartRange: "1D"
            property string panelSymbol: "SAP.DE"
            property bool isMultiMode: false
            property bool showExtendedHours: true
            property bool hideDecimals: false
            property bool formatPrices: true
            property int refreshIntervalMinutes: 5
            property string lastUpdated: ""
            property string nextUpdate: ""
            property bool showingCachedData: true

            function scheduleQuoteRetry() {}
            function noteQuoteReceived() {}
            function queueQuotesCacheSave() {}
        }
    }

    function make() {
        var applet = createTemporaryObject(fakeApplet, this);

        var storeComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/state/QuoteStore.qml"));
        compare(storeComponent.status, Component.Ready, storeComponent.errorString());
        var store = storeComponent.createObject(this);
        verify(store !== null);

        var marketComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/MarketController.qml"));
        compare(marketComponent.status, Component.Ready, marketComponent.errorString());
        var market = marketComponent.createObject(this, { "showExtendedHours": true, "keepExtendedAfterClose": true });
        verify(market !== null);

        var controllerComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/SingleQuoteController.qml"));
        compare(controllerComponent.status, Component.Ready, controllerComponent.errorString());
        var controller = controllerComponent.createObject(this, {
            "applet": applet, "store": store, "market": market, "stockModel": null
        });
        verify(controller !== null);
        return { applet: applet, store: store, market: market, controller: controller };
    }

    function test_process() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.process(json, "SAP.DE", "1D");

        compare(o.store.singleDataTicker, "SAP.DE");
        compare(o.store.singleDataRange, "1D");
        compare(o.store.quoteCurrency, "EUR");
        compare(o.store.currentRawPrice, 213.45);
        verify(o.store.currentPrice.indexOf("213.45") >= 0);
        verify(o.store.previousClose > 0);
        verify(o.store.chartDataPoints.length > 0);
        compare(o.store.chartDataPoints.length, o.store.chartTimestamps.length);
        verify(o.store.chartCandles.length > 0);
        verify(o.applet.lastUpdated !== "");
        verify(o.applet.nextUpdate !== "");
        compare(o.applet.showingCachedData, false);
        verify(o.market.hasSession("SAP.DE"));
        // The chart and the panel use the same configured range here.
        compare(o.store.panelCurrentPrice, o.store.currentPrice);
    }

    function test_processPanel() {
        var o = make();
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.processPanel(json, "SAP.DE", "1D");
        verify(o.store.panelCurrentPrice.indexOf("213.45") >= 0);
        verify(o.store.panelCurrentPercent.indexOf("%") > 0);
        compare(o.store.panelCurrentIsCached, false);
    }
}
