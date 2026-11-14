import QtQuick
import QtTest
import "../../contents/ui/domain/currencies.js" as Currency

TestCase {
    name: "Currency"

    function test_minorUnits() {
        compare(Currency.major("GBp"), "GBP");
        compare(Currency.major("usd"), "USD");
        compare(Currency.major(""), "");
        compare(Currency.minorFactor("GBp"), 0.01);
        compare(Currency.minorFactor("ILA"), 0.01);
        compare(Currency.minorFactor("EUR"), 1);
    }

    function test_symbols() {
        compare(Currency.symbol("GBp"), "GBp ");
        compare(Currency.symbol("usd"), "$");
        compare(Currency.symbol("CHF"), "CHF ");
        compare(Currency.symbol(""), "");
    }

    function test_convert() {
        compare(Currency.convert(100, "GBp", "GBP", null), 1);
        compare(Currency.convert(1, "USD", "USD", null), 1);

        var rates = { USD: 1, EUR: 0.9 };
        verify(Math.abs(Currency.convert(10, "USD", "EUR", rates) - 9) < 1e-9);
        verify(Math.abs(Currency.convert(10, "EUR", "USD", rates) - (10 / 0.9)) < 1e-9);
        // Pence are converted to the major unit before the rate is applied.
        verify(Math.abs(Currency.convert(100, "GBp", "USD", { USD: 1, GBP: 0.8 }) - 1.25) < 1e-9);

        compare(Currency.convert(1, "USD", "XYZ", rates), null);
        compare(Currency.convert(1, "", "USD", rates), null);
        compare(Currency.convert("nope", "USD", "EUR", rates), null);
    }

    function test_isKnown() {
        verify(Currency.isKnown("usd"));
        verify(Currency.isKnown("GBp"));
        verify(!Currency.isKnown("XYZ"));
    }
}
