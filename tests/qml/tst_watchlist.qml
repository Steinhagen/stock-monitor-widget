import QtQuick
import QtTest
import "Fixture.js" as Fixture

TestCase {
    name: "WatchlistController"

    Component {
        id: fakeApplet
        QtObject {
            property string multiTickers: "TLV.RO, SAP.DE"
            property bool sortAlphabetically: false
            property string manualPanelTickerOverride: ""
            property string panelTicker: ""
            property string singleTicker: ""
            property string loadingText: "Loading..."
            property string chartRange: "1D"
            property string effectiveChartRange: "1D"
            property bool isMultiMode: true
            property bool showExtendedHours: true
            property bool hideDecimals: false
            property bool formatPrices: true
            property int refreshIntervalMinutes: 5
            property string lastUpdated: ""
            property string nextUpdate: ""

            function applyCachedQuotesToRows() {}
            function scheduleQuoteRetry() {}
            function noteQuoteReceived() {}
            function queueQuotesCacheSave() {}
        }
    }

    Component {
        id: fakeSingleQuotes
        QtObject {
            property int calls: 0
            function process(json, symbol, range) { calls++ }
        }
    }

    function make() {
        var applet = createTemporaryObject(fakeApplet, this);
        var single = createTemporaryObject(fakeSingleQuotes, this);

        var storeComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/state/QuoteStore.qml"));
        var store = storeComponent.createObject(this);
        var marketComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/MarketController.qml"));
        var market = marketComponent.createObject(this, { "showExtendedHours": true, "keepExtendedAfterClose": true });
        var controllerComponent = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/WatchlistController.qml"));
        compare(controllerComponent.status, Component.Ready, controllerComponent.errorString());
        var controller = controllerComponent.createObject(this, {
            "applet": applet, "store": store, "market": market, "singleQuotes": single
        });
        verify(controller !== null);
        return { applet: applet, store: store, market: market, single: single, controller: controller };
    }

    function test_configuredTickers() {
        var o = make();
        o.applet.multiTickers = "TLV.RO, , SAP.DE ";
        compare(o.controller.configuredTickers().join(","), "TLV.RO,SAP.DE");
        o.applet.sortAlphabetically = true;
        compare(o.controller.configuredTickers().join(","), "SAP.DE,TLV.RO");
    }

    function test_ensureRows() {
        var o = make();
        o.controller.ensureRows(["SAP.DE", "TLV.RO"]);
        compare(o.controller.model.count, 2);
        compare(o.applet.panelTicker, "SAP.DE");
        compare(o.applet.singleTicker, "SAP.DE");
        compare(o.controller.model.get(0).ticker, "SAP.DE");
        // Re-running with the same list keeps the rows.
        o.controller.ensureRows(["SAP.DE", "TLV.RO"]);
        compare(o.controller.model.count, 2);
    }

    function test_processRow() {
        var o = make();
        o.controller.ensureRows(["SAP.DE"]);
        var json = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-chart-sap-1d.json")));
        o.controller.processRow("SAP.DE", json, "1D");

        compare(o.controller.model.count, 1);
        var row = o.controller.model.get(0);
        compare(row.ticker, "SAP.DE");
        compare(row.currency, "EUR");
        verify(row.price.indexOf("213.45") >= 0);
        verify(row.pct.indexOf("%") > 0);
        verify(JSON.parse(row.chartPoints).length > 0);
        compare(JSON.parse(row.chartPoints).length, JSON.parse(row.chartTimes).length);
        compare(row.cached, false);
        // The panel row also refreshes the panel quote and reuses the chart reply.
        compare(o.store.panelCurrentPrice, row.price);
        verify(o.applet.lastUpdated !== "");
        compare(o.single.calls, 1);
    }
}
