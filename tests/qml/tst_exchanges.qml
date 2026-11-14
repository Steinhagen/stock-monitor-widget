import QtQuick
import QtTest
import "../../contents/ui/domain/exchanges.js" as Exchanges

TestCase {
    name: "Exchanges"

    function test_suffix() {
        compare(Exchanges.suffix("BRD.RO"), ".RO");
        compare(Exchanges.suffix("sap.de"), ".DE");
        compare(Exchanges.suffix("BRK-B"), "");
        compare(Exchanges.suffix("AAPL"), "");
        compare(Exchanges.suffix(".RO"), "");
        compare(Exchanges.hasSuffix("TLV.RO"), true);
        compare(Exchanges.hasSuffix("AAPL"), false);
    }

    function test_baseSymbol() {
        compare(Exchanges.baseSymbol("BRD.RO"), "BRD");
        compare(Exchanges.baseSymbol("BRK-B"), "BRK-B");
        compare(Exchanges.baseSymbol("AAPL"), "AAPL");
    }

    function test_shortLabel() {
        // Yahoo's exchange code wins, then the suffix, then the reported full name.
        compare(Exchanges.shortLabel("SAP.DE", "GER", "XETRA"), "XETRA");
        compare(Exchanges.shortLabel("TLV.RO", "", ""), "BVB");
        compare(Exchanges.shortLabel("8001.T", "", ""), "TSE");
        compare(Exchanges.shortLabel("AAPL", "NMS", ""), "NASDAQ");
        compare(Exchanges.shortLabel("XYZ.ZZ", "", ""), "");
        // An unknown code is shown as-is rather than dropped.
        compare(Exchanges.shortLabel("XYZ.ZZ", "ZZZ", ""), "ZZZ");
    }

    function test_fullLabel() {
        compare(Exchanges.fullLabel("TLV.RO", "BVB", "Bucharest Stock Exchange"),
                "Bucharest Stock Exchange");
        compare(Exchanges.fullLabel("TLV.RO", "BVB", ""), "BVB");
    }
}
