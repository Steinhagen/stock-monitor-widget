import QtQuick
import QtTest
import "../../contents/ui/domain/format.js" as Format

TestCase {
    name: "Format"

    function test_number() {
        compare(Format.number(1234.567, false, false, true), "1,234.57");
        compare(Format.number(1234.567, false, true, true), "1,235");
        compare(Format.number(1234.567, false, false, false), "1234.57");
        // A change keeps its decimals even when prices hide them, and carries a sign.
        compare(Format.number(1.5, true, true, false), "+1.50");
        compare(Format.number(-1.5, true, true, false), "-1.50");
        compare(Format.number(0, true, false, false), "0.00");
        // Non-numeric values are passed through.
        compare(Format.number("n/a", false, false, true), "n/a");
    }

    function test_currencySymbol() {
        compare(Format.currencySymbol("USD"), "$");
        compare(Format.currencySymbol("GBp"), "GBp ");
        compare(Format.currencySymbol("null"), "");
        compare(Format.currencySymbol(""), "");
    }

    function test_money() {
        compare(Format.money("$", 1234.5, false, false, true), "$1,234.50");
        compare(Format.money("$", 1234.5, true, false, true), "+$1,234.50");
        compare(Format.money("$", -1234.5, true, false, true), "-$1,234.50");
        compare(Format.money("$", 0, true, false, true), "$0.00");
    }
}
