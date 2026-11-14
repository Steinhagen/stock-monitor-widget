.pragma library
// The pure parts of the portfolio page: parsing the stored lots, filtering them for
// the search field, sorting for the table and formatting amounts. Kept out of the
// page so the same code can be tested without a QML UI.

.import "../../domain/currencies.js" as Currency

// The stored value is a JSON array. A malformed value must not break the page.
function parse(dataStr) {
    if (!dataStr) return [];
    try {
        var parsed = JSON.parse(dataStr);
        return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
        console.error("Failed to parse portfolio data:", e);
        return [];
    }
}

// A price typed with either "." or "," as the decimal separator, regardless of the
// system locale (parseFloat alone would truncate a locale using ",").
function parseLocaleNumber(text) {
    if (!text) return NaN;
    var str = String(text).trim();
    var lastComma = str.lastIndexOf(",");
    var lastDot = str.lastIndexOf(".");
    if (lastComma !== -1 && lastDot !== -1) {
        // Both present: the last one is the decimal separator, the other groups thousands.
        if (lastComma > lastDot) str = str.replace(/\./g, "").replace(",", ".");
        else str = str.replace(/,/g, "");
    } else if (lastComma !== -1) {
        str = str.replace(",", ".");
    }
    return parseFloat(str);
}

// Filtered copies carry `_index` back into the original list, so Edit/Remove still
// address the lot the user sees when the list is sorted or searched.
function filterLots(lots, query) {
    var q = String(query || "").trim().toLowerCase();
    var result = [];
    for (var i = 0; i < lots.length; i++) {
        var lot = lots[i];
        if (q !== "") {
            var haystack = (String(lot.ticker || "") + " " + String(lot.details || "")
                            + " " + String(lot.currency || "")).toLowerCase();
            if (haystack.indexOf(q) < 0) continue;
        }
        var copy = Object.assign({}, lot);
        copy._index = i;
        result.push(copy);
    }
    return result;
}

// The comparable value for a sort key. Money columns need the live quote, so the
// caller passes its market-data lookup; null means "unknown" and sorts last.
function sortValue(lot, key, marketData) {
    if (key === "symbol") return String(lot.ticker || "").toLowerCase();
    if (key === "shares") return Number(lot.shares) || 0;
    if (key === "averageCost") return Number(lot.averageCost) || 0;
    if (key === "currency") return String(lot.currency || "USD");
    if (key === "date") {
        var time = Date.parse(String(lot.addedDate || ""));
        return isNaN(time) ? null : time;
    }
    var market = marketData ? marketData(lot) : null;
    if (!market) return null;
    return key === "value" ? market.value : market.gain;
}

function compareLots(a, b, key, ascending, marketData) {
    var av = sortValue(a, key, marketData);
    var bv = sortValue(b, key, marketData);
    if (av === null && bv === null) return 0;
    if (av === null) return 1;
    if (bv === null) return -1;
    var result = (typeof av === "string") ? av.localeCompare(bv) : av - bv;
    return ascending ? result : -result;
}

// 325183.75 -> "325,183.75" when the widget's thousands-grouping setting is on.
function formatNumber(amount, groupThousands) {
    var num = Number(amount);
    if (isNaN(num)) return String(amount);
    var formatted = Math.abs(num).toFixed(2);
    if (groupThousands) {
        var parts = formatted.split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        formatted = parts.join(".");
    }
    return (num < 0 ? "-" : "") + formatted;
}

// The sign stays in front of the currency symbol, like the widget's formatMoney.
function moneyText(currency, amount, groupThousands) {
    var num = Number(amount);
    if (isNaN(num)) return Currency.symbol(currency) + String(amount);
    return (num < 0 ? "-" : "") + Currency.symbol(currency)
           + formatNumber(Math.abs(num), groupThousands);
}
