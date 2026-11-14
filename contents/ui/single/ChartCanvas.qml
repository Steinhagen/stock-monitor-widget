import QtQuick
import "../domain/curve.js" as ChartCurve

// The price chart: the Canvas and all of its drawing. The single view places it,
// drives the hover state on `host` and keeps the news pane on top of it.
    Canvas {
        id: canvas
        property var applet
        property var host
        anchors.fill: parent
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.Image
        onPaint: { drawChart(getContext("2d"), width, height, applet.chartDataPoints, applet.chartTimestamps, applet.previousClose, applet.isPositive, true, applet.showChartAxis, applet.showTimeAxis); }
        Connections {
            target: applet
            function onChartDataPointsChanged() { canvas.requestPaint(); }
            function onChartTimestampsChanged() { canvas.requestPaint(); }
            function onChartRangeChanged() { canvas.requestPaint(); }
            function onShowChartAxisChanged() { canvas.requestPaint(); }
            function onShowTimeAxisChanged() { canvas.requestPaint(); }
            function onChartStyleChanged() { canvas.requestPaint(); }
            function onShowChartVolumeChanged() { canvas.requestPaint(); }
            function onChartLineStyleChanged() { canvas.requestPaint(); }
            function onChartCandlesChanged() { canvas.requestPaint(); }
            function onChartReferencePriceChanged() { canvas.requestPaint(); }
            function onChartSessionsChanged() { canvas.requestPaint(); }
            function onChartPreSessionChanged() { canvas.requestPaint(); }
            // Theme changes alter the colors used while painting (and the
            // light/dark details), so repaint without waiting for new data.
            function onIsLightThemeChanged() { canvas.requestPaint(); }
            function onChartBaseColorChanged() { canvas.requestPaint(); }
            function onSecondaryTextColorChanged() { canvas.requestPaint(); }
            function onPositiveColorChanged() { canvas.requestPaint(); }
            function onNegativeColorChanged() { canvas.requestPaint(); }
            function onShowChartHoverChanged() {
                if (!applet.showChartHover) host.chartHoverActive = false;
                canvas.requestPaint();
            }
        }
        Connections {
            target: host
            function onChartHoverActiveChanged() { canvas.requestPaint(); }
            function onChartHoverXChanged() { canvas.requestPaint(); }
            function onAnalystMarkersShownChanged() { canvas.requestPaint(); }
            function onExtendedQuoteChanged() { canvas.requestPaint(); }
        }
        // Do not bring back a stale crosshair when returning to the chart.
        Connections {
            target: applet
            function onSingleViewPaneChanged() {
                host.chartHoverActive = false;
                canvas.requestPaint();
            }
        }
    function axisTicks(minVal, maxVal, targetCount) {
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var rawStep = range / Math.max(2, targetCount || 5);
        var mag = Math.pow(10, Math.floor(Math.log(rawStep) / Math.LN10));
        var norm = rawStep / mag;
        var step = (norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10) * mag;
        var ticks = [];
        for (var v = Math.ceil(minVal / step) * step; v <= maxVal + step * 1e-6; v += step)
            ticks.push(v);
        return ticks;
    }

    // Price scale on the right. Returns the x coordinate where the plot ends, so the
    // caller can draw the series to the left of the labels. The labels are measured with
    // the same font that is used to draw them, so a six-figure price cannot run off the
    // card.
    function drawRightAxis(ctx, w, minVal, maxVal, getY, showGrid) {
        var ticks = axisTicks(minVal, maxVal, 5);
        var labels = [];
        var labelW = 0;
        ctx.font = "9px sans-serif";
        for (var i = 0; i < ticks.length; i++) {
            var text = applet.formatNumber(ticks[i], false);
            labels.push(text);
            labelW = Math.max(labelW, ctx.measureText(text).width);
        }

        var plotRight = w - Math.ceil(labelW) - 10;
        if (plotRight < 24) {
            plotRight = w;
            return plotRight;
        }

        if (showGrid) {
            ctx.save();
            ctx.strokeStyle = applet.chartBaseColor;
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 4]);
            for (var j = 0; j < ticks.length; j++) {
                var gy = Math.round(getY(ticks[j])) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, gy);
                ctx.lineTo(plotRight, gy);
                ctx.stroke();
            }
            ctx.restore();
        }

        ctx.fillStyle = applet.secondaryTextColor;
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";
        for (var k = 0; k < ticks.length; k++)
            ctx.fillText(labels[k], plotRight + 7, getY(ticks[k]));
        return plotRight;
    }

    // The price line through the closes. "Straight" joins the points with plain segments.
    // "Smooth" uses monotone cubic interpolation (no overshoot, no loops) and keeps
    // segments across large time gaps straight; see domain/curve.js.
    // `xs` (optional) gives the pixel x of every point; without it the points are spread
    // evenly over 0..right. `times` (optional) are the timestamps, used to find gaps.
    function traceSmooth(ctx, data, right, getY, xs, times) {
        var n = data.length;
        if (n < 2) return;
        var stepX = right / (n - 1);
        function px(i) { return xs ? xs[i] : i * stepX; }
        ctx.beginPath();
        ctx.moveTo(px(0), getY(data[0]));
        if (applet.chartLineStyle === 1 || n < 3) {
            for (var j = 1; j < n; j++) ctx.lineTo(px(j), getY(data[j]));
            return;
        }
        var px_ = [], py_ = [];
        for (var k = 0; k < n; k++) {
            px_.push(px(k));
            py_.push(getY(data[k]));
        }
        var gaps = ChartCurve.gapFlags(times && times.length === n ? times : null);
        var m = ChartCurve.monotoneTangents(px_, py_, gaps);
        for (var i = 0; i < n - 1; i++) {
            if (gaps[i] || !(px_[i + 1] > px_[i])) {
                ctx.lineTo(px_[i + 1], py_[i + 1]);
                continue;
            }
            var c = ChartCurve.segmentControls(px_, py_, m, i);
            ctx.bezierCurveTo(c.c1x, c.c1y, c.c2x, c.c2y, px_[i + 1], py_[i + 1]);
        }
    }
    function drawEndDot(ctx, x, y, color) {
        ctx.save();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.12);
        ctx.beginPath();
        ctx.arc(x, y, 8, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.22);
        ctx.beginPath();
        ctx.arc(x, y, 4.8, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(x, y, 2.7, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }

    // Label for one timestamp, at the detail that fits the selected range: hours for a
    // day, days for a week, months for up to a year and years for long ranges.
    function timeAxisLabel(timestamp, span) {
        var date = new Date(timestamp * 1000);
        var locale = Qt.locale();
        switch (applet.effectiveChartRange) {
            case "1D":  return locale.toString(date, "HH:mm");
            case "5D":  return locale.toString(date, "ddd");
            case "1M":  return locale.toString(date, "d MMM");
            case "6M":
            case "1Y":  return locale.toString(date, "MMM");
            case "YTD":
                // Early in the year YTD covers only a few days, where month names would
                // all be the same; fall back to dates or times for those short spans.
                if (span > 60 * 86400) return locale.toString(date, "MMM");
                if (span > 2 * 86400) return locale.toString(date, "d MMM");
                return locale.toString(date, "HH:mm");
            case "5Y":  return locale.toString(date, "yyyy");
            case "Max":
                // Max can span anything from a few days to decades, so pick the detail
                // from the data rather than from the range name.
                if (span > 2 * 365 * 86400) return locale.toString(date, "yyyy");
                if (span > 90 * 86400) return locale.toString(date, "MMM yyyy");
                if (span > 2 * 86400) return locale.toString(date, "d MMM");
                return locale.toString(date, "HH:mm");
            default:
                return locale.toString(date, "d MMM");
        }
    }

    // Time scale under the plot. A handful of evenly spaced labels is enough for the
    // narrow chart; the label format follows the selected range and the available width
    // decides how many labels fit without overlapping.
    function drawTimeAxis(ctx, w, plotX, plotH, data, times) {
        if (!times || times.length !== data.length || data.length < 2) return;
        var plotW = w - plotX;
        if (plotW < 24) return;

        var span = times[times.length - 1] - times[0];
        var count = Math.max(2, Math.min(4, Math.floor(plotW / 45)));
        var lastRight = -1;
        var seen = {};

        ctx.save();
        ctx.font = "9px sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "top";
        ctx.fillStyle = applet.secondaryTextColor;
        ctx.strokeStyle = applet.chartBaseColor;
        ctx.lineWidth = 1;

        for (var i = 0; i < count; i++) {
            var index = Math.round(i * (data.length - 1) / (count - 1));
            var timestamp = times[index];
            if (!timestamp) continue;

            var label = timeAxisLabel(timestamp, span);
            if (Object.prototype.hasOwnProperty.call(seen, label)) continue;
            var textW = ctx.measureText(label).width;
            var x = plotX + index * plotW / (data.length - 1);
            // Keep the first and last labels inside the plot instead of letting them run
            // into the price scale or off the card.
            var center = Math.max(plotX + textW / 2, Math.min(w - textW / 2, x));
            var left = center - textW / 2;
            if (lastRight >= 0 && left < lastRight + 8) continue;

            ctx.beginPath();
            ctx.moveTo(Math.round(x) + 0.5, plotH);
            ctx.lineTo(Math.round(x) + 0.5, plotH + 3);
            ctx.stroke();
            ctx.fillText(label, center, plotH + 3);

            seen[label] = true;
            lastRight = center + textW / 2;
        }
        ctx.restore();
    }

    // Time scale for the full-day chart. The session boundaries come first, then the
    // first and last points; a label that would touch one already placed is skipped.
    function drawSessionTimeAxis(ctx, plotRight, plotH, allTimes, xAt, s, nPre, nPost) {
        if (plotRight < 24) return;
        var span = allTimes[allTimes.length - 1] - allTimes[0];
        var candidates = [];
        if (nPre > 0) candidates.push(s.regStart);
        if (nPost > 0) candidates.push(s.regEnd);
        candidates.push(allTimes[0]);
        candidates.push(allTimes[allTimes.length - 1]);
        var placed = [];
        ctx.save();
        ctx.font = "9px sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "top";
        ctx.fillStyle = applet.secondaryTextColor;
        ctx.strokeStyle = applet.chartBaseColor;
        ctx.lineWidth = 1;
        for (var i = 0; i < candidates.length; i++) {
            var label = timeAxisLabel(candidates[i], span);
            var textW = ctx.measureText(label).width;
            var x = xAt(candidates[i]);
            var center = Math.max(textW / 2, Math.min(plotRight - textW / 2, x));
            var left = center - textW / 2, right = center + textW / 2;
            var clash = false;
            for (var j = 0; j < placed.length; j++) {
                if (left < placed[j][1] + 8 && right > placed[j][0] - 8) { clash = true; break; }
            }
            if (clash) continue;
            ctx.beginPath();
            ctx.moveTo(Math.round(x) + 0.5, plotH);
            ctx.lineTo(Math.round(x) + 0.5, plotH + 3);
            ctx.stroke();
            ctx.fillText(label, center, plotH + 3);
            placed.push([left, right]);
        }
        ctx.restore();
    }
    // Diagonal hatch over an extended-hours zone.
    function drawHatch(ctx, x0, x1, plotH) {
        if (x1 <= x0) return;
        ctx.save();
        ctx.beginPath();
        ctx.rect(x0, 0, x1 - x0, plotH);
        ctx.clip();
        ctx.strokeStyle = applet.isLightTheme ? "rgba(0,0,0,0.08)" : "rgba(255,255,255,0.08)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (var k = x0 - plotH; k < x1; k += 6) {
            ctx.moveTo(k, plotH);
            ctx.lineTo(k + plotH, 0);
        }
        ctx.stroke();
        ctx.restore();
    }
    // Date/time shown in the hover tooltip. Longer ranges use a coarser label because
    // one point covers a day/week/month rather than a minute.
    function hoverTimeLabel(timestamp) {
        var date = new Date(timestamp * 1000);
        var locale = Qt.locale();
        switch (applet.effectiveChartRange) {
            case "1D":  return locale.toString(date, "HH:mm");
            case "5D":  return locale.toString(date, "ddd HH:mm");
            case "1M":  return locale.toString(date, "d MMM HH:mm");
            case "6M":
            case "YTD":
            case "1Y":  return locale.toString(date, "d MMM yyyy");
            case "5Y":
            case "Max": return locale.toString(date, "MMM yyyy");
            default:    return locale.toString(date, "d MMM yyyy");
        }
    }

    function compactVolume(value) {
        if (!(value > 0)) return "0";
        if (value >= 1e9) return (value / 1e9).toFixed(2) + " B";
        if (value >= 1e6) return (value / 1e6).toFixed(2) + " M";
        if (value >= 1e3) return (value / 1e3).toFixed(1) + " K";
        return Math.round(value).toString();
    }

    // Volume belongs to the regular session. Yahoo reports zero (or only the closing
    // auction in the first bar) for the pre-market and after-hours candles, so those
    // bars are never drawn.
    function candleHasVolume(candle) {
        return candle && candle.volume > 0
               && candle.zone !== "pre" && candle.zone !== "post";
    }

    // Regular-session candles in time order, including the zero-volume gaps so the
    // remaining bars keep their slots. Used by the line chart's volume strip; the
    // candle chart keeps the original indices.
    function regularCandles(candles) {
        var out = [];
        if (!Array.isArray(candles)) return out;
        for (var i = 0; i < candles.length; i++) {
            var candle = candles[i];
            if (!candle) continue;
            if (candle.zone !== "pre" && candle.zone !== "post") out.push(candle);
        }
        return out;
    }

    function roundRectPath(ctx, x, y, w, h, r) {
        var rr = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + rr, y);
        ctx.lineTo(x + w - rr, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
        ctx.lineTo(x + w, y + h - rr);
        ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
        ctx.lineTo(x + rr, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
        ctx.lineTo(x, y + rr);
        ctx.quadraticCurveTo(x, y, x + rr, y);
        ctx.closePath();
    }

    // Crosshair plus a small tooltip. `plotBottom` is where the tooltip must stay,
    // `crossBottom` is where the vertical hairline ends (the volume strip makes these
    // different in the candlestick chart).
    function drawHover(ctx, plotRight, plotBottom, crossBottom, x, y, accent, title, price, detail1, detail1Color, detail2) {
        if (plotRight < 20 || plotBottom < 20) return;

        var light = applet.isLightTheme;
        var bg = light ? "#ffffff" : "#101417";
        var border = light ? "rgba(0, 0, 0, 0.14)" : "rgba(255, 255, 255, 0.16)";
        var text = light ? "#171a1c" : "#f3f5f6";
        var muted = light ? "#5d656c" : "#9aa2a9";

        ctx.save();
        ctx.strokeStyle = Qt.rgba(applet.secondaryTextColor.r, applet.secondaryTextColor.g, applet.secondaryTextColor.b, light ? 0.38 : 0.42);
        ctx.lineWidth = 1;
        ctx.setLineDash([3, 3]);
        ctx.beginPath();
        ctx.moveTo(Math.round(x) + 0.5, 0);
        ctx.lineTo(Math.round(x) + 0.5, crossBottom);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, Math.round(y) + 0.5);
        ctx.lineTo(plotRight, Math.round(y) + 0.5);
        ctx.stroke();
        ctx.restore();

        ctx.save();
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(x, y, 3.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = bg;
        ctx.beginPath();
        ctx.arc(x, y, 1.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();

        ctx.font = "9px sans-serif";
        var titleWidth = ctx.measureText(title).width;
        ctx.font = "bold 12px sans-serif";
        var priceWidth = ctx.measureText(price).width;
        ctx.font = "9px sans-serif";
        var detail1Width = detail1 ? ctx.measureText(detail1).width : 0;
        var detail2Width = detail2 ? ctx.measureText(detail2).width : 0;
        var tipW = Math.max(titleWidth, priceWidth, detail1Width, detail2Width) + 16;
        var tipH = 7 + 12 + 16 + (detail1 ? 12 : 0) + (detail2 ? 12 : 0) + 5;

        var tipX = x + 12;
        if (tipX + tipW > plotRight - 2) tipX = x - 12 - tipW;
        if (tipX < 2) tipX = 2;
        var tipY = y - tipH / 2;
        if (tipY < 2) tipY = 2;
        if (tipY + tipH > plotBottom - 2) tipY = Math.max(2, plotBottom - tipH - 2);

        ctx.save();
        roundRectPath(ctx, tipX, tipY, tipW, tipH, 5);
        ctx.fillStyle = bg;
        ctx.fill();
        ctx.strokeStyle = border;
        ctx.lineWidth = 1;
        ctx.stroke();

        ctx.textAlign = "left";
        ctx.textBaseline = "top";
        ctx.font = "9px sans-serif";
        ctx.fillStyle = muted;
        ctx.fillText(title, tipX + 8, tipY + 7);
        ctx.font = "bold 12px sans-serif";
        ctx.fillStyle = text;
        ctx.fillText(price, tipX + 8, tipY + 19);

        var lineY = tipY + 36;
        if (detail1) {
            ctx.font = "9px sans-serif";
            ctx.fillStyle = detail1Color;
            ctx.fillText(detail1, tipX + 8, lineY);
            lineY += 12;
        }
        if (detail2) {
            ctx.font = "9px sans-serif";
            ctx.fillStyle = muted;
            ctx.fillText(detail2, tipX + 8, lineY);
        }
        ctx.restore();
    }

    // Reference chart: the area above yesterday's close is green and the area below it is
    // red; the line changes colour when it crosses the reference. The right-hand scale is
    // optional through the existing "Price scale" setting, but is on by default.
    function drawReferenceChart(ctx, w, h, data, times, prevClose, showPriceAxis, showTimeAxis) {
        var ref = applet.chartReferencePrice > 0 ? applet.chartReferencePrice
                                                   : (prevClose > 0 ? prevClose : data[0]);
        if (!(ref > 0)) ref = data[0];
        if (!isFinite(ref)) return;
        // Full-day layout (regular session plus pre-market / after-hours). Line style only.
        var s = (applet.chartStyle !== 1) ? applet.chartSessions : null;
        var nReg = data.length;
        var nPre = s ? s.preValues.length : 0;
        var nPost = s ? s.postValues.length : 0;
        var allData = s ? s.preValues.concat(data, s.postValues) : data;
        var allTimes = s ? s.preTimes.concat(times, s.postTimes) : times;
        if (s && (!times || times.length !== nReg || !(allTimes[allTimes.length - 1] > allTimes[0]))) {
            s = null;
            nPre = 0;
            nPost = 0;
            allData = data;
            allTimes = times;
        }
        var minVal = Math.min.apply(null, allData);
        var maxVal = Math.max.apply(null, allData);
        if (!isFinite(minVal) || !isFinite(maxVal)) {
            // A malformed cache or a bad quote must not take the whole chart down.
            minVal = ref - 1;
            maxVal = ref + 1;
        }
        if (ref < minVal) minVal = ref;
        if (ref > maxVal) maxVal = ref;
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var padding = range * 0.08;
        minVal -= padding;
        maxVal += padding;
        range = maxVal - minVal;

        var timeAxisHeight = (showTimeAxis && times && times.length === nReg && times[0] > 0) ? 16 : 0;
        var volumeBottom = h - timeAxisHeight;
        if (volumeBottom < 10) {
            timeAxisHeight = 0;
            volumeBottom = h;
        }
        // Optional volume strip. It is based on the same aggregated candles as the
        // candlestick view and covers only the regular session.
        var volumeCandles = [];
        var maxVolume = 0;
        if (applet.showChartVolume && !applet.chartPreSession) {
            volumeCandles = regularCandles(applet.chartCandles);
            for (var vi = 0; vi < volumeCandles.length; vi++) {
                if (volumeCandles[vi].volume > maxVolume) maxVolume = volumeCandles[vi].volume;
            }
        }
        var volumeHeight = volumeCandles.length > 1 && maxVolume > 0
                           ? Math.min(54, Math.max(26, h * 0.13)) : 0;
        var volumeTop = volumeBottom - volumeHeight;
        var markerSpace = host.analystMarkersShown ? 22 : 8;
        var plotH = volumeHeight > 0 ? volumeTop - markerSpace
                                     : volumeBottom - (host.analystMarkersShown ? 18 : 0);
        if (plotH < 36) {
            volumeHeight = 0;
            volumeTop = volumeBottom;
            plotH = volumeBottom - (host.analystMarkersShown ? 18 : 0);
        }
        function getY(val) { return plotH - ((val - minVal) / range * plotH); }

        var plotRight = showPriceAxis ? drawRightAxis(ctx, w, minVal, maxVal, getY, false) : w;
        if (plotRight < 24) plotRight = w;
        var refY = getY(ref);
        // createLinearGradient() aborts the whole paint if given a non-finite value.
        if (!isFinite(refY)) refY = plotH / 2;
        refY = Math.max(0, Math.min(plotH, refY));
        var pos = applet.positiveColor;
        var neg = applet.negativeColor;
        // Pixel x of every point. Without extended hours the points are evenly spaced.
        var t0 = s ? allTimes[0] : 0;
        var tSpan = s ? allTimes[allTimes.length - 1] - allTimes[0] : 1;
        function xAt(t) { return plotRight * (t - t0) / tSpan; }
        var xsAll = null, xsReg = null;
        if (s) {
            xsAll = [];
            for (var xi = 0; xi < allTimes.length; xi++) xsAll.push(xAt(allTimes[xi]));
            xsReg = xsAll.slice(nPre, nPre + nReg);
        }
        var xFirst = xsReg ? xsReg[0] : 0;
        var xLast = xsReg ? xsReg[nReg - 1] : plotRight;
        // Fill above the reference.
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, plotRight, refY);
        ctx.clip();
        var above = ctx.createLinearGradient(0, 0, 0, Math.max(1, refY));
        above.addColorStop(0.0, Qt.rgba(pos.r, pos.g, pos.b, 0.30));
        above.addColorStop(0.55, Qt.rgba(pos.r, pos.g, pos.b, 0.10));
        above.addColorStop(1.0, Qt.rgba(pos.r, pos.g, pos.b, 0.012));
        traceSmooth(ctx, data, plotRight, getY, xsReg, times);
        ctx.lineTo(xLast, refY);
        ctx.lineTo(xFirst, refY);
        ctx.closePath();
        ctx.fillStyle = above;
        ctx.fill();
        ctx.restore();

        // Fill below the reference.
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, refY, plotRight, Math.max(1, plotH - refY));
        ctx.clip();
        var below = ctx.createLinearGradient(0, refY, 0, plotH);
        below.addColorStop(0.0, Qt.rgba(neg.r, neg.g, neg.b, 0.012));
        below.addColorStop(0.5, Qt.rgba(neg.r, neg.g, neg.b, 0.11));
        below.addColorStop(1.0, Qt.rgba(neg.r, neg.g, neg.b, 0.30));
        traceSmooth(ctx, data, plotRight, getY, xsReg, times);
        ctx.lineTo(xLast, refY);
        ctx.lineTo(xFirst, refY);
        ctx.closePath();
        ctx.fillStyle = below;
        ctx.fill();
        ctx.restore();

        // A pre-market-only chart is entirely extended-hours data; hatch it like the
        // pre-market zone of a full-day chart.
        if (applet.chartPreSession) drawHatch(ctx, 0, plotRight, plotH);

        if (s) {
            var xOpen = xAt(s.regStart);
            var xClose = xAt(s.regEnd);
            if (nPre > 0) drawHatch(ctx, 0, xOpen, volumeBottom);
            if (nPost > 0) drawHatch(ctx, xClose, plotRight, volumeBottom);
            var sec = applet.secondaryTextColor;
            ctx.save();
            ctx.strokeStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.5);
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 3]);
            ctx.beginPath();
            if (nPre > 0) { ctx.moveTo(Math.round(xOpen) + 0.5, 0); ctx.lineTo(Math.round(xOpen) + 0.5, plotH); }
            if (nPost > 0) { ctx.moveTo(Math.round(xClose) + 0.5, 0); ctx.lineTo(Math.round(xClose) + 0.5, plotH); }
            ctx.stroke();
            ctx.restore();
            ctx.save();
            ctx.font = "8px sans-serif";
            ctx.fillStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.8);
            ctx.textAlign = "left";
            ctx.textBaseline = "middle";
            if (nPre > 0 && xOpen >= ctx.measureText(applet.tagPreMarket).width + 8)
                ctx.fillText(applet.tagPreMarket, 4, 22);
            if (nPost > 0 && plotRight - xClose >= ctx.measureText(applet.tagAfterHours).width + 8)
                ctx.fillText(applet.tagAfterHours, xClose + 4, 22);
            ctx.restore();
        }
        // Reference line.
        ctx.save();
        ctx.strokeStyle = Qt.rgba(applet.secondaryTextColor.r, applet.secondaryTextColor.g, applet.secondaryTextColor.b, 0.48);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, Math.round(refY) + 0.5);
        ctx.lineTo(plotRight, Math.round(refY) + 0.5);
        ctx.stroke();
        ctx.restore();

        // Draw a polyline split at the reference: green above it, red below it.
        function strokeSplit(values, xs, ts) {
            ctx.save();
            ctx.beginPath();
            ctx.rect(0, 0, plotRight, refY);
            ctx.clip();
            ctx.strokeStyle = pos;
            ctx.lineWidth = 2;
            traceSmooth(ctx, values, plotRight, getY, xs, ts);
            ctx.stroke();
            ctx.restore();

            ctx.save();
            ctx.beginPath();
            ctx.rect(0, refY, plotRight, Math.max(1, plotH - refY));
            ctx.clip();
            ctx.strokeStyle = neg;
            ctx.lineWidth = 2;
            traceSmooth(ctx, values, plotRight, getY, xs, ts);
            ctx.stroke();
            ctx.restore();
        }

        // The line changes colour exactly at the reference.
        strokeSplit(data, xsReg, times);

        // Extended-hours parts of the line: same reference split, no fill. Each segment
        // starts or ends on the neighbouring regular point so the line stays continuous.
        var regularClose = applet.currentRawPrice > 0 ? applet.currentRawPrice : data[nReg - 1];
        if (nPre > 0)
            strokeSplit(allData.slice(0, nPre + 1), xsAll.slice(0, nPre + 1), allTimes.slice(0, nPre + 1));
        if (nPost > 0)
            strokeSplit(allData.slice(nPre + nReg - 1), xsAll.slice(nPre + nReg - 1), allTimes.slice(nPre + nReg - 1));

        // Volume strip, on the same scale in both chart styles. Only regular-session
        // candles are drawn; the hatched pre-market/after-hours zones stay empty.
        if (volumeHeight > 0) {
            ctx.save();
            ctx.strokeStyle = applet.chartBaseColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, Math.round(volumeTop) + 0.5);
            ctx.lineTo(plotRight, Math.round(volumeTop) + 0.5);
            ctx.stroke();
            ctx.restore();

            var volStart = s ? xAt(s.regStart) : 0;
            var volEnd = s ? xAt(s.regEnd) : plotRight;
            if (volEnd > volStart) {
                var volStep = (volEnd - volStart) / volumeCandles.length;
                var volW = Math.max(2, Math.min(6, volStep * 0.62));
                for (var vk = 0; vk < volumeCandles.length; vk++) {
                    var volumeCandle = volumeCandles[vk];
                    if (!(volumeCandle.volume > 0)) continue;
                    var volH = Math.max(1, (volumeCandle.volume / maxVolume) * (volumeHeight - 4));
                    ctx.save();
                    ctx.globalAlpha = 0.20;
                    ctx.fillStyle = volumeCandle.close >= volumeCandle.open ? pos : neg;
                    ctx.fillRect(volStart + (vk + 0.5) * volStep - volW / 2,
                                 volumeBottom - volH, volW, volH);
                    ctx.restore();
                }
            }
        }

        // End dot.
        var lastValue = allData[allData.length - 1];
        var dotColor = lastValue >= ref ? pos : neg;
        drawEndDot(ctx, xsAll ? xsAll[xsAll.length - 1] : plotRight, getY(lastValue), dotColor);

        // Legend in the empty top-left corner.
        var legend = applet.chartReferenceLabel + " " + applet.formatNumber(ref, false);
        ctx.save();
        ctx.strokeStyle = Qt.rgba(applet.secondaryTextColor.r, applet.secondaryTextColor.g, applet.secondaryTextColor.b, 0.55);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, 9.5);
        ctx.lineTo(10, 9.5);
        ctx.stroke();
        ctx.fillStyle = applet.secondaryTextColor;
        ctx.font = "9px sans-serif";
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";
        ctx.fillText(legend, 14, 10);
        ctx.restore();

        // Hover crosshair: snap to the nearest close and show its time and value.
        if (host.chartHoverActive && times && times.length === data.length) {
            var hx = Math.max(0, Math.min(plotRight, host.chartHoverX));
            var index, hoverX, hoverPrice, hoverTime, hoverBase = ref;
            if (s) {
                index = 0;
                for (var hi = 1; hi < xsAll.length; hi++) {
                    if (Math.abs(xsAll[hi] - hx) < Math.abs(xsAll[index] - hx)) index = hi;
                }
                hoverX = xsAll[index];
                hoverPrice = allData[index];
                hoverTime = hoverTimeLabel(allTimes[index]);
                if (index < nPre) {
                    hoverTime += " " + applet.tagPreMarket;
                    if (prevClose > 0) hoverBase = prevClose;
                } else if (index >= nPre + nReg) {
                    hoverTime += " " + applet.tagAfterHours;
                    hoverBase = regularClose;
                }
            } else {
                index = Math.round((data.length - 1) * hx / plotRight);
                index = Math.max(0, Math.min(data.length - 1, index));
                hoverX = plotRight * index / (data.length - 1);
                hoverPrice = data[index];
                hoverTime = times[index] ? hoverTimeLabel(times[index]) : "";
            }
            var hoverY = getY(hoverPrice);
            var hoverChange = hoverPrice - hoverBase;
            var hoverPct = hoverBase > 0 ? (hoverChange / hoverBase) * 100 : 0;
            // The dot and the change text follow the sign of the change shown in the tooltip.
            var hoverAccent = hoverChange > 0 ? pos : (hoverChange < 0 ? neg : applet.secondaryTextColor);
            var hoverDetail = applet.formatNumber(hoverChange, true) + " (" + applet.formatNumber(hoverPct, true) + "%)";
            var hoverVolume = "";
            if (volumeHeight > 0) {
                var hvStart = s ? xAt(s.regStart) : 0;
                var hvEnd = s ? xAt(s.regEnd) : plotRight;
                if (hvEnd > hvStart && hoverX >= hvStart && hoverX <= hvEnd) {
                    var hvStep = (hvEnd - hvStart) / volumeCandles.length;
                    var hvIndex = Math.floor((hoverX - hvStart) / hvStep);
                    hvIndex = Math.max(0, Math.min(volumeCandles.length - 1, hvIndex));
                    if (candleHasVolume(volumeCandles[hvIndex]))
                        hoverVolume = "Vol " + compactVolume(volumeCandles[hvIndex].volume);
                }
            }
            drawHover(ctx, plotRight, plotH, volumeBottom, hoverX, hoverY, hoverAccent, hoverTime,
                      applet.currencySym + applet.formatNumber(hoverPrice, false),
                      hoverDetail, hoverAccent, hoverVolume);
        }

        if (timeAxisHeight > 0) {
            if (s) drawSessionTimeAxis(ctx, plotRight, volumeBottom, allTimes, xAt, s, nPre, nPost);
            else drawTimeAxis(ctx, plotRight, 0, volumeBottom, data, times);
        }
    }

    // Candlestick chart with an optional volume strip. The candles are already aggregated in
    // main.qml, so this function only maps them to pixels. The price scale on the right
    // and the time scale below are shared with the reference chart.
    function drawCandleChart(ctx, w, h, showPriceAxis, showTimeAxis) {
        var candles = applet.chartCandles;
        if (!candles || !Array.isArray(candles) || candles.length < 2) return;

        var minVal = Infinity;
        var maxVal = -Infinity;
        var maxVolume = 0;
        for (var i = 0; i < candles.length; i++) {
            if (candles[i].low < minVal) minVal = candles[i].low;
            if (candles[i].high > maxVal) maxVal = candles[i].high;
            if (candleHasVolume(candles[i]) && candles[i].volume > maxVolume)
                maxVolume = candles[i].volume;
        }
        if (!(maxVal > minVal)) maxVal = minVal + 1;
        var padding = (maxVal - minVal) * 0.06;
        minVal -= padding;
        maxVal += padding;
        var range = maxVal - minVal;

        var hasTimes = candles.length > 1 && candles[0].time > 0 && candles[candles.length - 1].time > 0;
        var timeAxisHeight = (showTimeAxis && hasTimes) ? 16 : 0;
        var volumeBottom = h - timeAxisHeight;
        var showVolume = applet.showChartVolume && !applet.chartPreSession && maxVolume > 0;
        var volumeHeight = showVolume ? Math.min(54, Math.max(26, h * 0.13)) : 0;
        var volumeTop = volumeBottom - volumeHeight;
        var markerSpace = host.analystMarkersShown ? 22 : 8;
        var plotBottom = volumeHeight > 0
                         ? volumeTop - markerSpace
                         : volumeBottom - (host.analystMarkersShown ? 18 : 0);
        if (plotBottom < 36) {
            showVolume = false;
            volumeHeight = 0;
            volumeTop = volumeBottom;
            plotBottom = volumeBottom - (host.analystMarkersShown ? 18 : 0);
        }
        function getY(val) { return plotBottom - ((val - minVal) / range * plotBottom); }

        var plotRight = showPriceAxis ? drawRightAxis(ctx, w, minVal, maxVal, getY, true) : w;
        if (plotRight < 24) plotRight = w;

        // Pre-market and after-hours candles are hatched like the line chart's zones.
        var nPre = 0, nPost = 0;
        for (var zi = 0; zi < candles.length; zi++) {
            if (candles[zi].zone === "pre") nPre++;
            else if (candles[zi].zone === "post") nPost++;
        }
        var nReg = candles.length - nPre - nPost;
        var xPreEnd = (nPre / candles.length) * plotRight;
        var xPostStart = ((nPre + nReg) / candles.length) * plotRight;
        if (applet.chartPreSession) {
            drawHatch(ctx, 0, plotRight, volumeBottom);
        } else {
            if (nPre > 0) drawHatch(ctx, 0, xPreEnd, volumeBottom);
            if (nPost > 0) drawHatch(ctx, xPostStart, plotRight, volumeBottom);
        }

        var candleW = Math.max(2, Math.min(6, (plotRight / candles.length) * 0.62));
        for (var c = 0; c < candles.length; c++) {
            var candle = candles[c];
            var x = ((c + 0.5) * plotRight) / candles.length;
            var up = candle.close >= candle.open;
            var color = up ? applet.positiveColor : applet.negativeColor;

            ctx.save();
            ctx.globalAlpha = 0.55;
            ctx.strokeStyle = color;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x, getY(candle.high));
            ctx.lineTo(x, getY(candle.low));
            ctx.stroke();
            ctx.restore();

            var top = Math.min(getY(candle.open), getY(candle.close));
            var bodyH = Math.max(1, Math.abs(getY(candle.close) - getY(candle.open)));
            ctx.save();
            ctx.globalAlpha = 0.9;
            ctx.fillStyle = color;
            ctx.fillRect(x - candleW / 2, top, candleW, bodyH);
            ctx.restore();
        }

        // Session boundaries and tags, matching the line chart.
        if (!applet.chartPreSession && (nPre > 0 || nPost > 0)) {
            var sec = applet.secondaryTextColor;
            ctx.save();
            ctx.strokeStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.5);
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 3]);
            ctx.beginPath();
            if (nPre > 0) { ctx.moveTo(Math.round(xPreEnd) + 0.5, 0); ctx.lineTo(Math.round(xPreEnd) + 0.5, plotBottom); }
            if (nPost > 0) { ctx.moveTo(Math.round(xPostStart) + 0.5, 0); ctx.lineTo(Math.round(xPostStart) + 0.5, plotBottom); }
            ctx.stroke();
            ctx.restore();
            ctx.save();
            ctx.font = "8px sans-serif";
            ctx.fillStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.8);
            ctx.textBaseline = "middle";
            if (nPre > 0) {
                ctx.textAlign = "left";
                ctx.fillText(applet.tagPreMarket, 4, 22);
            }
            if (nPost > 0) {
                ctx.textAlign = "right";
                ctx.fillText(applet.tagAfterHours, plotRight - 4, 22);
            }
            ctx.restore();
        }

        // Volume strip.
        if (volumeHeight > 0) {
            ctx.save();
            ctx.strokeStyle = applet.chartBaseColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, Math.round(volumeTop) + 0.5);
            ctx.lineTo(plotRight, Math.round(volumeTop) + 0.5);
            ctx.stroke();
            ctx.restore();

            if (maxVolume > 0) {
                for (var b = 0; b < candles.length; b++) {
                    if (!candleHasVolume(candles[b])) continue;
                    var bx = ((b + 0.5) * plotRight) / candles.length;
                    var bh = Math.max(1, (candles[b].volume / maxVolume) * (volumeHeight - 4));
                    ctx.save();
                    ctx.globalAlpha = 0.20;
                    ctx.fillStyle = candles[b].close >= candles[b].open ? applet.positiveColor : applet.negativeColor;
                    ctx.fillRect(bx - candleW / 2, volumeBottom - bh, candleW, bh);
                    ctx.restore();
                }
            }
        }

        // Last close marker.
        var last = candles[candles.length - 1];
        var lastUp = last.close >= last.open;
        drawEndDot(ctx, ((candles.length - 0.5) * plotRight) / candles.length, getY(last.close),
                   lastUp ? applet.positiveColor : applet.negativeColor);

        // Hover crosshair: snap to the nearest candle and show its OHLC and, when the
        // volume strip is on, the regular-session volume.
        if (host.chartHoverActive) {
            var hx = Math.max(0, Math.min(plotRight, host.chartHoverX));
            var index = Math.floor((hx / plotRight) * candles.length);
            index = Math.max(0, Math.min(candles.length - 1, index));
            var hoverCandle = candles[index];
            var hoverX = ((index + 0.5) * plotRight) / candles.length;
            var hoverY = getY(hoverCandle.close);
            var candleAccent = hoverCandle.close >= hoverCandle.open ? applet.positiveColor : applet.negativeColor;
            var hoverZone = hoverCandle.zone === "pre" ? " " + applet.tagPreMarket
                          : (hoverCandle.zone === "post" ? " " + applet.tagAfterHours : "");
            var hoverTime = hoverCandle.time ? hoverTimeLabel(hoverCandle.time) + hoverZone : "";
            var hoverOHL = "O " + applet.formatNumber(hoverCandle.open, false)
                         + "  H " + applet.formatNumber(hoverCandle.high, false)
                         + "  L " + applet.formatNumber(hoverCandle.low, false);
            var hoverVolume = showVolume && candleHasVolume(hoverCandle)
                              ? "Vol " + compactVolume(hoverCandle.volume) : "";
            drawHover(ctx, plotRight, plotBottom, volumeBottom, hoverX, hoverY, candleAccent,
                      hoverTime, applet.currencySym + applet.formatNumber(hoverCandle.close, false),
                      hoverOHL, applet.secondaryTextColor, hoverVolume);
        }

        if (timeAxisHeight > 0) {
            var closes = [];
            var ctimes = [];
            for (var t = 0; t < candles.length; t++) {
                closes.push(candles[t].close);
                ctimes.push(candles[t].time);
            }
            drawTimeAxis(ctx, plotRight, 0, volumeBottom, closes, ctimes);
        }
    }

    function drawChart(ctx, w, h, data, times, prevClose, isPos, drawBackground, showPriceAxis, showTimeAxis) {
        ctx.clearRect(0, 0, w, h);
        if (!data || !Array.isArray(data) || data.length < 2
                || !isFinite(w) || !isFinite(h) || w < 20 || h < 20) return;

        if (applet.chartStyle === 1 && Array.isArray(applet.chartCandles) && applet.chartCandles.length > 1)
            drawCandleChart(ctx, w, h, showPriceAxis, showTimeAxis);
        else
            drawReferenceChart(ctx, w, h, data, times, prevClose, showPriceAxis, showTimeAxis);
    }

}
