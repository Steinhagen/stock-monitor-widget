import QtQuick
import QtTest
import "../../contents/ui/providers/yahoo/chart.js" as YahooChart

TestCase {
    name: "YahooChart"

    function test_chartUrl() {
        compare(YahooChart.chartUrl("SAP.DE", "5D", false),
                "https://query1.finance.yahoo.com/v8/finance/chart/SAP.DE?range=5d&interval=15m");
        compare(YahooChart.chartUrl("SAP.DE", "1D", true),
                "https://query1.finance.yahoo.com/v8/finance/chart/SAP.DE?range=2d&interval=2m&includePrePost=true");
        compare(YahooChart.chartUrl("SAP.DE", "1D", false),
                "https://query1.finance.yahoo.com/v8/finance/chart/SAP.DE?range=2d&interval=2m");
    }

    function test_extendedUrl() {
        compare(YahooChart.extendedUrl("TLV.RO"),
                "https://query1.finance.yahoo.com/v8/finance/chart/TLV.RO?range=1d&interval=5m&includePrePost=true");
    }
}
