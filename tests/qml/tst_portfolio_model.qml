import QtQuick
import QtTest
import "../../contents/ui/settings/portfolio/portfolioModel.js" as Model

TestCase {
    name: "PortfolioModel"

    function test_parse() {
        compare(Model.parse("").length, 0);
        compare(Model.parse("[]").length, 0);
        var lots = Model.parse('[{"ticker":"SAP"},{"ticker":"TLV"}]');
        compare(lots.length, 2);
        compare(lots[0].ticker, "SAP");
        // Malformed input must not break the page.
        compare(Model.parse("not json").length, 0);
    }

    function test_parseLocaleNumber() {
        compare(Model.parseLocaleNumber("1.234,56"), 1234.56);
        compare(Model.parseLocaleNumber("1,234.56"), 1234.56);
        compare(Model.parseLocaleNumber("50,21"), 50.21);
        compare(Model.parseLocaleNumber("1234.5"), 1234.5);
        verify(isNaN(Model.parseLocaleNumber("")));
    }

    function test_filterLots() {
        var lots = [
            { ticker: "SAP", details: "Broker A", currency: "EUR" },
            { ticker: "TLV", details: "", currency: "RON" }
        ];
        compare(Model.filterLots(lots, "").length, 2);
        var byDetails = Model.filterLots(lots, "broker");
        compare(byDetails.length, 1);
        compare(byDetails[0].ticker, "SAP");
        compare(byDetails[0]._index, 0);
        var byCurrency = Model.filterLots(lots, "ron");
        compare(byCurrency.length, 1);
        compare(byCurrency[0].ticker, "TLV");
        compare(byCurrency[0]._index, 1);
        compare(Model.filterLots(lots, "nothing").length, 0);
    }

    function test_sortValue() {
        var market = function(lot) { return lot.market || null; };
        compare(Model.sortValue({ ticker: "SAP" }, "symbol", market), "sap");
        compare(Model.sortValue({ shares: "3" }, "shares", market), 3);
        compare(Model.sortValue({ averageCost: "12.5" }, "averageCost", market), 12.5);
        compare(Model.sortValue({ currency: "EUR" }, "currency", market), "EUR");
        verify(Model.sortValue({ addedDate: "not a date" }, "date", market) === null);
        verify(Model.sortValue({ addedDate: "2024-01-02T00:00:00Z" }, "date", market) > 0);
        verify(Model.sortValue({}, "value", market) === null);
        compare(Model.sortValue({ market: { value: 10, gain: 2 } }, "value", market), 10);
        compare(Model.sortValue({ market: { value: 10, gain: 2 } }, "gain", market), 2);
    }

    function test_compareLots() {
        var market = function(lot) { return lot.market || null; };
        compare(Model.compareLots({ shares: 1 }, { shares: 2 }, "shares", true, market), -1);
        compare(Model.compareLots({ shares: 1 }, { shares: 2 }, "shares", false, market), 1);
        // Unknown values sort last in both directions.
        compare(Model.compareLots({}, { market: { value: 2, gain: 1 } }, "value", true, market), 1);
        compare(Model.compareLots({}, { market: { value: 2, gain: 1 } }, "value", false, market), 1);
        compare(Model.compareLots({ ticker: "A" }, { ticker: "B" }, "symbol", true, market), -1);
    }

    function test_formatNumber() {
        compare(Model.formatNumber(325183.75, true), "325,183.75");
        compare(Model.formatNumber(-1234.5, true), "-1,234.50");
        compare(Model.formatNumber(1234.5, false), "1234.50");
        compare(Model.formatNumber("x", false), "x");
    }

    function test_moneyText() {
        compare(Model.moneyText("USD", 1234.5, false), "$1234.50");
        compare(Model.moneyText("USD", -5, false), "-$5.00");
        compare(Model.moneyText("EUR", 0, false), "€0.00");
    }
}
