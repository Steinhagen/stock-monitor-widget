import QtQuick
import QtTest

TestCase {
    name: "AppActions"

    Component {
        id: fakeApplet
        QtObject {
            property string panelTicker: ""
            property string manualPanelTickerOverride: ""
            property string singleTicker: ""
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
            property var chartDataPoints: []
            property var chartTimestamps: []
            property var chartSessions: null
            property var chartCandles: []
            property double chartReferencePrice: 0
            property bool chartPreSession: false
            property double chartSessionStart: 0
            property bool chartSessionCurrent: true
            property string panelCurrentPrice: "---"
            property string panelCurrentPercent: "+0.00%"
            property bool panelCurrentIsPositive: true
            property bool panelCurrentIsCached: false
            property string chartRange: "1D"
            property string effectiveChartRange: "1D"
            property string chartViewRangeActive: "1D"
            property int chartStyle: 0
            property int twoColumnLeftWidth: 0
            property string mouseRowLeftAction: "select"
            property string mouseMiddleAction: "refresh"
            property string mouseDoubleClickAction: "open"

            property int fetches: 0
            property int refreshes: 0
            function fetchSingleStock(symbol, range) { fetches++ }
            function refreshData() { refreshes++ }
        }
    }

    QtObject {
        id: fakeConfiguration
        property string selectedTicker: ""
        property string chartViewRange: ""
        property int chartStyle: 0
        property int twoColumnLeftWidth: 0
    }

    ListModel { id: rows }

    function make() {
        rows.clear();
        rows.append({
            "ticker": "SAP.DE", "name": "SAP SE", "price": "€213.45",
            "change": "+1.20", "pct": "+0.57%", "isPos": true,
            "chartPoints": "[211,212]", "chartTimes": "[10,20]",
            "chartSessions": ({}), "chartCandles": "[]", "chartRef": 212.25,
            "chartPre": false, "chartSessionStart": 0, "chartSessionCurrent": true,
            "quoteTime": 5, "prevClose": 212.25, "currentRaw": 213.45,
            "currencySym": "€ ", "currency": "EUR",
            "exchange": "XETRA", "exchangeFull": "XETRA", "cached": false
        });
        var applet = createTemporaryObject(fakeApplet, this);
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/app/AppActions.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var actions = component.createObject(this, {
            "applet": applet, "model": rows, "configuration": fakeConfiguration
        });
        verify(actions !== null);
        return { applet: applet, actions: actions };
    }

    function resetConfig() {
        fakeConfiguration.selectedTicker = "";
        fakeConfiguration.chartViewRange = "";
        fakeConfiguration.chartStyle = 0;
        fakeConfiguration.twoColumnLeftWidth = 0;
    }

    function test_selectTicker() {
        resetConfig();
        var o = make();
        o.actions.selectTicker("SAP.DE", true);
        compare(o.applet.panelTicker, "SAP.DE");
        compare(o.applet.singleTicker, "SAP.DE");
        compare(o.applet.currentPrice, "€213.45");
        compare(o.applet.chartDataPoints.length, 2);
        compare(fakeConfiguration.selectedTicker, "SAP.DE");
        // The row already had a chart for the selected range.
        compare(o.applet.fetches, 0);
    }

    function test_selectTickerWithoutPersisting() {
        resetConfig();
        var o = make();
        o.actions.selectTicker("SAP.DE", false);
        compare(fakeConfiguration.selectedTicker, "");
        compare(o.applet.panelTicker, "SAP.DE");
    }

    function test_updatePanelFromRow() {
        var o = make();
        o.actions.updatePanelFromRow("SAP.DE");
        compare(o.applet.panelCurrentPrice, "€213.45");
        compare(o.applet.panelCurrentPercent, "+0.57%");
        compare(o.applet.panelCurrentIsCached, false);
    }

    function test_chartRangeAndStyle() {
        resetConfig();
        var o = make();
        o.applet.singleTicker = "SAP.DE";
        o.actions.setChartViewRange("5D");
        compare(o.applet.chartViewRangeActive, "5D");
        compare(fakeConfiguration.chartViewRange, "5D");
        compare(o.applet.fetches, 1);

        o.actions.setChartStyle(1);
        compare(fakeConfiguration.chartStyle, 1);
    }

    function test_twoColumnWidth() {
        resetConfig();
        var o = make();
        o.actions.setTwoColumnLeftWidth(-4);
        compare(o.applet.twoColumnLeftWidth, 0);
        o.actions.setTwoColumnLeftWidth(320.4);
        compare(o.applet.twoColumnLeftWidth, 320);
        o.actions.saveTwoColumnLeftWidth();
        compare(fakeConfiguration.twoColumnLeftWidth, 320);
    }

    function test_mouseActions() {
        var o = make();
        compare(o.actions.performMiddleClick("SAP.DE"), true);
        compare(o.applet.refreshes, 1);
    }
}
