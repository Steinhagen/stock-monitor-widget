import QtQuick
import QtTest
import "../../contents/ui/chartdata.js" as ChartData

TestCase {
    name: "ChartData"

    function test_inExtendedSession() {
        var period = { start: 100, end: 200 };
        verify(ChartData.inExtendedSession(period, 100, "pre"));
        verify(!ChartData.inExtendedSession(period, 200, "pre"));
        verify(ChartData.inExtendedSession(period, 200, "post"));
        verify(!ChartData.inExtendedSession(null, 150, "pre"));
    }

    function test_tradingDays() {
        var meta = { tradingPeriods: { regular: [[{ start: 10, end: 20 }]] },
                     currentTradingPeriod: { regular: { start: 10, end: 20 } } };
        var days = ChartData.tradingDays(meta);
        compare(days.length, 1);
        compare(days[0].regular.start, 10);
        compare(days[0].pre, null);
        compare(ChartData.tradingDays(null).length, 0);
    }

    function test_dailyPreviousClose() {
        compare(ChartData.dailyPreviousClose({ regularMarketPreviousClose: 10 }, 0), 10);
        compare(ChartData.dailyPreviousClose({ regularMarketPrice: 10, fulldayChange: 2 }, 0), 8);
        compare(ChartData.dailyPreviousClose({ regularMarketPrice: 11, regularMarketChangePercent: 10 }, 0), 10);
        compare(ChartData.dailyPreviousClose(null, 7), 7);
        compare(ChartData.dailyPreviousClose(null, 0), 0);
    }

    function test_buildCandles() {
        var values = [];
        var times = [];
        for (var i = 1; i <= 10; i++) { values.push(i); times.push(1000 + i); }
        var chart = { values: values, opens: values, highs: values, lows: values,
                      volumes: values.map(function (v) { return v * 10; }), times: times };
        var candles = ChartData.buildCandles(chart, "1D", 5);
        compare(candles.length, 5);
        compare(candles[0].open, 1);
        compare(candles[0].close, 2);
        compare(candles[0].time, 1001);
        compare(candles[4].close, 10);
        compare(candles[4].time, 1009);
        compare(candles[4].volume, 90 + 100);
        compare(ChartData.buildCandles({ values: [1] }, "1D", 5).length, 0);
    }
}
