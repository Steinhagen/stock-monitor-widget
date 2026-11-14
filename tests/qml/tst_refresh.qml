import QtQuick
import QtTest

TestCase {
    name: "RefreshController"

    Component {
        id: fakeApplet
        QtObject {
            property bool isMultiMode: false
            property string multiTickers: "SAP.DE,TLV.RO"
            property string singleTicker: "SAP.DE"
            property bool showExtendedHours: true
            property string effectiveChartRange: "1D"
            property string chartRange: "1D"
            property bool skipWeekendRefresh: false
            property bool limitHours: false
            property int startHour: 0
            property int startMinute: 0
            property int endHour: 23
            property int endMinute: 59
            property int refreshIntervalMinutes: 5

            property int multiFetches: 0
            property int singleFetches: 0
            property int panelFetches: 0
            function fetchMultiStocks() { multiFetches++ }
            function fetchSingleStock(symbol, range) { singleFetches++ }
            function fetchPanelStock(symbol) { panelFetches++ }
        }
    }

    Component {
        id: fakeMarket
        QtObject {
            property int extendedFetches: 0
            function fetchExtendedHours(symbol) { extendedFetches++ }
        }
    }

    function make(applet) {
        var market = createTemporaryObject(fakeMarket, this);
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/controllers/RefreshController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var refresh = component.createObject(this, {
            "applet": applet, "market": market, "enabled": false
        });
        verify(refresh !== null);
        return { market: market, refresh: refresh };
    }

    function test_singleMode() {
        var applet = createTemporaryObject(fakeApplet, this);
        var o = make(applet);
        o.refresh.refreshQuotes();
        compare(applet.singleFetches, 1);
        compare(applet.multiFetches, 0);
        compare(applet.panelFetches, 0);
        compare(o.market.extendedFetches, 1);
    }

    function test_singleModeWithChartOnlyRange() {
        var applet = createTemporaryObject(fakeApplet, this);
        applet.effectiveChartRange = "5D";
        var o = make(applet);
        o.refresh.refreshQuotes();
        compare(applet.singleFetches, 1);
        compare(applet.panelFetches, 1);
    }

    function test_multiMode() {
        var applet = createTemporaryObject(fakeApplet, this);
        applet.isMultiMode = true;
        applet.effectiveChartRange = "5D";
        var o = make(applet);
        o.refresh.refreshQuotes();
        compare(applet.multiFetches, 1);
        compare(applet.singleFetches, 1);
        // Both configured tickers get an extended-hours request.
        compare(o.market.extendedFetches, 2);
    }

    function test_checkTimeWithinWindow() {
        var applet = createTemporaryObject(fakeApplet, this);
        var o = make(applet);
        o.refresh.checkTime();
        compare(applet.singleFetches, 1);
    }

    function test_checkTimeOutsideWindow() {
        var applet = createTemporaryObject(fakeApplet, this);
        applet.limitHours = true;
        applet.startHour = 0;
        applet.startMinute = 0;
        applet.endHour = 0;
        applet.endMinute = 0;
        var o = make(applet);
        o.refresh.checkTime();
        compare(applet.singleFetches, 0);
    }
}
