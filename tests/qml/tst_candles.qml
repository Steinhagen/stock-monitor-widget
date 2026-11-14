import QtQuick
import QtTest
import "../../contents/ui/domain/candles.js" as Candles

TestCase {
    name: "Candles"

    function test_candleTarget() {
        compare(Candles.candleTarget("1D"), 56);
        compare(Candles.candleTarget("1M"), 24);
        compare(Candles.candleTarget("Max"), 60);
        compare(Candles.candleTarget("unknown"), 60);
    }

    function test_buildCandles() {
        var values = [];
        var times = [];
        for (var i = 1; i <= 10; i++) { values.push(i); times.push(1000 + i); }
        var chart = { values: values, opens: values, highs: values, lows: values,
                      volumes: values.map(function (v) { return v * 10; }), times: times };
        var candles = Candles.buildCandles(chart, "1D", 5);
        compare(candles.length, 5);
        compare(candles[0].open, 1);
        compare(candles[0].close, 2);
        compare(candles[0].time, 1001);
        compare(candles[4].close, 10);
        compare(candles[4].time, 1009);
        compare(candles[4].volume, 190);
        compare(Candles.buildCandles({ values: [1] }, "1D", 5).length, 0);
    }
}
