import QtQuick
import QtTest

TestCase {
    name: "AppConfig"

    QtObject {
        id: fake
        property string ticker: "SAP.DE"
        property bool showNews: true
        property int newsCount: 100
        property int symbolDisplayMode: 9
        property string mouseRowLeftAction: ""
        property bool showExtendedHours: false
        property string multiTickers: ""
    }

    function make(configuration) {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/app/AppConfig.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var config = component.createObject(this, { "configuration": configuration });
        verify(config !== null);
        return config;
    }

    function test_defaults() {
        var config = make(null);
        compare(config.ticker, "AAPL");
        compare(config.newsCount, 24);
        compare(config.newsRefreshMinutes, 30);
        compare(config.symbolDisplayMode, 0);
        compare(config.mouseRowLeftAction, "select");
        compare(config.newsSourceYahoo, true);
        compare(config.showExtendedHours, true);
    }

    function test_overridesAndClamps() {
        var config = make(fake);
        compare(config.ticker, "SAP.DE");
        compare(config.showNews, true);
        compare(config.newsCount, 50);
        compare(config.symbolDisplayMode, 2);
        compare(config.mouseRowLeftAction, "select");
        compare(config.showExtendedHours, false);
        // An intentionally emptied ticker list stays empty.
        compare(config.multiTickers, "");
    }

    function test_reactive() {
        var config = make(fake);
        compare(config.showNews, true);
        fake.showNews = false;
        compare(config.showNews, false);
    }
}
