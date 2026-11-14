import QtQuick
import QtTest

TestCase {
    name: "ChartCanvas"

    QtObject {
        id: fakeApplet
        property var chartDataPoints: [1, 2, 3, 2.5, 3.5]
        property var chartTimestamps: [1000, 2000, 3000, 4000, 5000]
        property var chartCandles: []
        property var chartSessions: null
        property real chartReferencePrice: 1
        property real previousClose: 1
        property bool isPositive: true
        property bool chartPreSession: false
        property int chartStyle: 0
        property int chartLineStyle: 0
        property bool showChartHover: false
        property bool showChartVolume: false
        property string effectiveChartRange: "1D"
        property bool isLightTheme: false
        property bool usesPlasmaSurface: false
        property color bgColor: "#1a1a1a"
        property color surfaceBackground: "#202326"
        property color chartBaseColor: "#333333"
        property color secondaryTextColor: "#888888"
        property color positiveColor: "#4cd964"
        property color negativeColor: "#FF3B30"
        property string tagPreMarket: "PRE"
        property string tagAfterHours: "AH"
        property string chartReferenceLabel: "Previous close"
        property string currencySym: "$"
        property real currentRawPrice: 3.5
        function formatNumber(value, isChange) { return String(value) }
    }

    QtObject {
        id: fakeHost
        property bool chartHoverActive: false
        property real chartHoverX: 0
        property bool analystMarkersShown: false
    }

    function makeContext() {
        var gradient = { addColorStop: function() {} };
        return {
            fillStyle: "", strokeStyle: "", lineWidth: 1, globalAlpha: 1,
            font: "", textAlign: "", textBaseline: "",
            clearRect: function() {}, save: function() {}, restore: function() {},
            beginPath: function() {}, closePath: function() {}, moveTo: function() {},
            lineTo: function() {}, quadraticCurveTo: function() {}, bezierCurveTo: function() {},
            arc: function() {}, rect: function() {}, clip: function() {},
            fill: function() {}, stroke: function() {}, fillRect: function() {},
            fillText: function() {}, setLineDash: function() {},
            createLinearGradient: function() { return gradient; },
            measureText: function(text) { return { width: String(text).length * 6 }; }
        };
    }

    function test_hoverCard() {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/single/ChartCanvas.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var canvas = component.createObject(this, { "applet": fakeApplet, "host": fakeHost });
        verify(canvas !== null);
        canvas.drawHover(makeContext(), 400, 300, 300, 200, 120, "#ff5f56",
                         "14:44", "€8.79", "-0.03 (-0.32%)", "#ff5f56", "Vol 5.3 K");
    }

    function test_drawReferenceChart() {
        var component = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/single/ChartCanvas.qml"));
        compare(component.status, Component.Ready, component.errorString());
        var canvas = component.createObject(this, { "applet": fakeApplet, "host": fakeHost });
        verify(canvas !== null);
        // Exercises the full reference-chart path; any missing property or context
        // method would throw here.
        canvas.drawChart(makeContext(), 400, 300, fakeApplet.chartDataPoints,
                         fakeApplet.chartTimestamps, fakeApplet.previousClose,
                         fakeApplet.isPositive, false, true, true);
        verify(true);
    }
}
