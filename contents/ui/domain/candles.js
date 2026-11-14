.pragma library
// Candle aggregation for the chart. The helper functions that map a range to a target
// count and group the aligned OHLCV series are kept apart from the chart cleanup and
// session logic in chart.js, so the two can be tested independently.

.import "chart.js" as Chart

function candleTarget(range) {
    switch (range) {
        case "1D":  return 56;
        case "5D":  return 56;
        case "1M":  return 24;
        case "6M":  return 30;
        case "YTD": return 45;
        case "1Y":  return 52;
        case "5Y":  return 60;
        case "Max": return 60;
        default:    return 60;
    }
}

// Yesterday's close, independent of the chart range. Yahoo sends `previousClose` only
// for the 1D range; longer ranges still carry the day's change, so derive it from
// regularMarketPrice - fulldayChange (or from the change percentage).

function buildCandles(chart, range, asked) {
    var n = chart && chart.values ? chart.values.length : 0;
    if (n < 2) return [];
    var target = Math.min(n, asked > 0 ? Math.round(asked) : candleTarget(range));
    var candles = [];
    for (var i = 0; i < target; i++) {
        var start = Math.floor(i * n / target);
        var end = Math.floor((i + 1) * n / target);
        if (end <= start) end = start + 1;
        if (start >= n) break;

        var open = chart.opens[start] !== undefined ? chart.opens[start] : chart.values[start];
        var close = chart.values[end - 1];
        var high = open;
        var low = open;
        var volume = 0;
        for (var j = start; j < end; j++) {
            var h = chart.highs[j] !== undefined ? chart.highs[j] : chart.values[j];
            var l = chart.lows[j] !== undefined ? chart.lows[j] : chart.values[j];
            if (h > high) high = h;
            if (l < low) low = l;
            volume += chart.volumes[j] || 0;
        }
        if (close > high) high = close;
        if (close < low) low = close;
        candles.push({
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            time: chart.times[start] || 0
        });
    }
    return candles;
}

// Candles for one extended session (pre or post) of the displayed day, so the
// candlestick chart can draw them around the regular session like the line chart.
// The target count follows the session length, keeping the zone widths proportional
// to time even though the candles are laid out by index.
function sessionCandles(quote, timestamps, period, day, zone) {
    if (!period || !quote || !timestamps) return [];
    var opens = [], highs = [], lows = [], closes = [], volumes = [], times = [];
    for (var i = 0; i < timestamps.length; i++) {
        var t = timestamps[i];
        if (!Chart.inExtendedSession(period, t, zone)) continue;
        var c = quote.close ? quote.close[i] : null;
        if (c === null || c === undefined) continue;
        closes.push(c);
        opens.push(quote.open && quote.open[i] !== null && quote.open[i] !== undefined ? quote.open[i] : c);
        highs.push(quote.high && quote.high[i] !== null && quote.high[i] !== undefined ? quote.high[i] : c);
        lows.push(quote.low && quote.low[i] !== null && quote.low[i] !== undefined ? quote.low[i] : c);
        volumes.push(quote.volume && quote.volume[i] !== null && quote.volume[i] !== undefined ? quote.volume[i] : 0);
        times.push(t);
    }
    if (closes.length < 2) return [];
    var target = candleTarget("1D");
    if (day && day.regular && day.regular.end > day.regular.start)
        target = Math.max(4, Math.round(target * (period.end - period.start)
                                           / (day.regular.end - day.regular.start)));
    var candles = buildCandles({ values: closes, times: times, opens: opens,
                                 highs: highs, lows: lows, volumes: volumes }, "1D", target);
    for (var c2 = 0; c2 < candles.length; c2++) candles[c2].zone = zone;
    return candles;
}

// The candle series for a 1D chart: the regular session plus the pre-market and
// after-hours sessions around it, each candle tagged with its zone.
function chartCandlesFor(chart, range, quote, timestamps, day) {
    var regular = buildCandles(chart, range);
    for (var i = 0; i < regular.length; i++) regular[i].zone = "regular";
    if (range !== "1D" || !day || !quote || !timestamps) return regular;
    var pre = day.pre ? sessionCandles(quote, timestamps, day.pre, day, "pre") : [];
    var post = day.post ? sessionCandles(quote, timestamps, day.post, day, "post") : [];
    if (pre.length === 0 && post.length === 0) return regular;
    return pre.concat(regular, post);
}
