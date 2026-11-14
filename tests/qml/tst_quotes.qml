import QtQuick
import QtTest
import "../../contents/ui/domain/quotes.js" as Quotes

TestCase {
    name: "Quotes"

    function test_apiParams() {
        compare(Quotes.apiParams("1D", true), "range=2d&interval=2m&includePrePost=true");
        compare(Quotes.apiParams("1D", false), "range=2d&interval=2m");
        compare(Quotes.apiParams("5D", false), "range=5d&interval=15m");
        compare(Quotes.apiParams("1M", false), "range=1mo&interval=60m");
        compare(Quotes.apiParams("6M", false), "range=6mo&interval=1d");
        compare(Quotes.apiParams("YTD", false), "range=ytd&interval=1d");
        compare(Quotes.apiParams("1Y", false), "range=1y&interval=1d");
        compare(Quotes.apiParams("5Y", false), "range=5y&interval=1wk");
        compare(Quotes.apiParams("Max", false), "range=max&interval=1mo");
        compare(Quotes.apiParams("unknown", false), "range=1d&interval=2m");
    }
}
