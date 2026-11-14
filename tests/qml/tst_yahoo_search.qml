import QtQuick
import QtTest
import "Fixture.js" as Fixture
import "../../contents/ui/providers/yahoo/search.js" as YahooSearch

TestCase {
    name: "YahooSearch"

    function test_searchUrl() {
        compare(YahooSearch.searchUrl("SAP SE"),
                "https://query2.finance.yahoo.com/v1/finance/search?q=SAP%20SE");
    }

    function test_parseFixture() {
        var reply = JSON.parse(Fixture.read(Qt.resolvedUrl("../fixtures/yahoo-search-sap.json")));
        var results = YahooSearch.parse(reply);
        compare(results.length, 1);
        compare(results[0].symbol, "SAP");
        compare(results[0].name, "SAP  SE");
    }

    function test_parseSkipsIncomplete() {
        var results = YahooSearch.parse({ quotes: [null, {}, { symbol: "X", longname: "Ex" }] });
        compare(results.length, 1);
        compare(results[0].symbol, "X");
        compare(results[0].name, "Ex");
        compare(YahooSearch.parse(null).length, 0);
    }

    function test_emptyQuery() {
        var called = false;
        var out = null;
        YahooSearch.search(" ", function(results, error) {
            called = true;
            out = results;
        });
        verify(called);
        compare(out.length, 0);
    }
}
