import QtQuick
import QtTest
import "../../contents/ui/settings/portfolio/portfolioValuation.js" as Valuation

TestCase {
    name: "PortfolioValuation"

    readonly property var rates: ({ "EUR": 1, "USD": 1.1 })

    function test_convert() {
        verify(Math.abs(Valuation.convert(10, "EUR", "USD", rates) - 11) < 1e-9);
        compare(Valuation.convert(10, "USD", "USD", null), 10);
        // No rate for the pair: unknown, not zero.
        compare(Valuation.convert(10, "EUR", "JPY", rates), null);
    }

    function test_lotMarketData() {
        var lot = { ticker: "SAP", shares: 2, averageCost: 50, currency: "USD" };
        var quote = { price: 100, currency: "USD", previousClose: 90 };
        var market = Valuation.lotMarketData(lot, quote, null);
        compare(market.value, 200);
        compare(market.gain, 100);
        compare(market.percent, 100);
        compare(market.perShare, 50);
        compare(market.dayGain, 20);
        verify(Math.abs(market.dayPercent - 20 / 180 * 100) < 1e-9);
        compare(market.currency, "USD");

        compare(Valuation.lotMarketData(lot, null, null), null);
        compare(Valuation.lotMarketData(lot, { price: 0, currency: "USD" }, null), null);
    }

    function test_lotCurrencyConversion() {
        var lot = { ticker: "SAP", shares: 1, averageCost: 90, currency: "USD" };
        var quote = { price: 100, currency: "EUR", previousClose: 100 };
        var market = Valuation.lotMarketData(lot, quote, rates);
        verify(Math.abs(market.value - 110) < 1e-9);
        verify(Math.abs(market.price - 110) < 1e-9);
        compare(market.currency, "USD");
        // Conversion without the needed rate is unknown.
        compare(Valuation.lotMarketData(lot, quote, null), null);
    }

    function test_totals() {
        var lots = [
            { ticker: "SAP", shares: 2, averageCost: 50, currency: "USD" },
            { ticker: "TLV", shares: 10, averageCost: 2, currency: "USD" }
        ];
        var quotes = {
            "SAP": { price: 100, currency: "USD", previousClose: 90 },
            "TLV": { price: 3, currency: "USD", previousClose: 3 }
        };
        var totals = Valuation.totals(lots, quotes, "USD", null);
        compare(totals.currency, "USD");
        compare(totals.cost, 120);
        compare(totals.value, 230);
        compare(totals.gain, 110);
        verify(Math.abs(totals.gainPercent - 110 / 120 * 100) < 1e-9);
        compare(totals.day, 20);
    }

    function test_totalsUnknownQuote() {
        var lots = [{ ticker: "SAP", shares: 1, averageCost: 50, currency: "USD" }];
        var totals = Valuation.totals(lots, {}, "USD", null);
        compare(totals.cost, 50);
        compare(totals.value, null);
        compare(totals.gain, null);
        compare(totals.day, null);
    }

    function test_totalsEmpty() {
        var totals = Valuation.totals([], {}, "EUR", rates);
        compare(totals.currency, "EUR");
        compare(totals.cost, 0);
        compare(totals.value, 0);
        compare(totals.gain, 0);
    }

    function test_totalsTargetCurrency() {
        var lots = [{ ticker: "SAP", shares: 1, averageCost: 100, currency: "EUR" }];
        var quotes = { "SAP": { price: 100, currency: "EUR", previousClose: 100 } };
        var totals = Valuation.totals(lots, quotes, "USD", rates);
        verify(Math.abs(totals.cost - 110) < 1e-9);
        verify(Math.abs(totals.value - 110) < 1e-9);
        verify(Math.abs(totals.gain) < 1e-9);
    }
}
