import QtQuick
import QtTest

TestCase {
    name: "NewsController"
    width: 400
    height: 300

    Component {
        id: fakeApplet
        QtObject {
            property string singleTicker: "SAP.DE"
            property string singleDataTicker: "SAP.DE"
            property bool isMultiMode: false
            property string singleCompanyName: "SAP SE"
            property string loadingText: "Loading…"
            property bool newsAvailable: true
            property bool newsSourceYahoo: true
            property bool newsSourceBvb: false
            property bool newsSourceGoogle: true
            property int newsCount: 5
            property int newsRefreshMinutes: 30
            property bool newsPaneShown: false
            property string singleViewPane: "chart"
        }
    }

    function makeController() {
        var applet = createTemporaryObject(fakeApplet, this);
        verify(applet !== null);
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/NewsController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var controller = component.createObject(this, { "applet": applet });
        verify(controller !== null);
        return controller;
    }

    function test_mergeDedupesAndSorts() {
        var controller = makeController();
        var yahoo = [
            { title: "Same story", link: "https://a", source: "Yahoo", time: 10 },
            { title: "Older", link: "https://b", source: "Yahoo", time: 5 }
        ];
        var bvb = [
            { title: "Same story", link: "https://c", source: "BVB", time: 20 }
        ];
        var google = [
            { title: "Newest", link: "https://d", source: "Google", time: 30 },
            { title: "Older", link: "https://e", source: "Google", time: 1 }
        ];
        var merged = controller.mergeNews(yahoo, bvb, google);
        compare(merged.length, 3);
        compare(merged[0].title, "Newest");
        compare(merged[0].source, "Google");
        compare(merged[1].title, "Same story");
        compare(merged[1].source, "Yahoo");
        compare(merged[2].title, "Older");
    }

    function test_newsKey() {
        var controller = makeController();
        compare(controller.newsKey(" tlv.ro "), "TLV.RO");
        compare(controller.newsKey(""), "");
        compare(controller.newsKey(undefined), "");
    }
}
