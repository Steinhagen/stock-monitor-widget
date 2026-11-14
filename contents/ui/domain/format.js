.pragma library
// Number and money formatting. The options are passed in instead of read from the
// configuration, so the same helpers work in the settings pages and in tests.

.import "currencies.js" as Currency

// Two decimals unless decimals are hidden (they are kept for a change, where the
// decimals carry the meaning), with thousands separators when formatting is on.
// `amount` is returned unchanged when it is not a number.
function number(amount, isChange, hideDecimals, formatPrices) {
    var num = parseFloat(amount);
    if (isNaN(num)) return amount;

    var isPositive = num >= 0;
    var absNum = Math.abs(num);

    var hideDecs = hideDecimals && !isChange;
    var formatted = hideDecs ? Math.round(absNum).toString() : absNum.toFixed(2);

    if (formatPrices) {
        var parts = formatted.split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        formatted = parts.join(".");
    }

    var sign = "";
    if (isChange && isPositive && num > 0) sign = "+";
    else if (!isPositive) sign = "-";

    return sign + formatted;
}

// The symbol in front of a value. Yahoo occasionally reports the literal text "null"
// for a missing currency.
function currencySymbol(code) {
    if (!code || code === "null") return "";
    return Currency.symbol(code);
}

// "-$1,234.50", or "+$1,234.50" when `signed` and the amount is positive.
function money(symbol, value, signed, hideDecimals, formatPrices) {
    var sign = value < 0 ? "-" : (signed && value > 0 ? "+" : "");
    return sign + symbol + number(Math.abs(value), false, hideDecimals, formatPrices);
}
