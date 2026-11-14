.pragma library
// Display helpers for a symbol: the company name, the ticker as shown in the widget,
// the exchange badge and the combined "Name (TICK)" label. Pure string work; the font
// metrics that shorten a label live in the QML view.

.import "exchanges.js" as Exchanges

// Yahoo returns some non-US short names from a fixed-width vendor field: the company
// name is padded with spaces and followed by a share-class letter, e.g.
// "DEUTSCHE LUFTHANSA AG         V". That padding is not part of the name, so use the
// long name for those quotes and collapse any whitespace that is left over.
function companyName(meta, fallback) {
    var m = meta || {};
    var shortName = m.shortName ? String(m.shortName).trim() : "";
    var longName = m.longName ? String(m.longName).trim() : "";
    var name = /\s{2,}/.test(shortName) && longName !== "" ? longName : (shortName || longName);
    return name.replace(/\s+/g, " ").trim() || fallback;
}

// What the widget shows for a ticker. The stored symbol always stays the full Yahoo
// one: it is the key for quote requests, portfolio lots and the selected row.
// mode: 0 = full symbol, 1 = base symbol, 2 = base symbol with an exchange badge.
function displayTicker(ticker, mode) {
    var clean = Exchanges.upper(ticker);
    return Number(mode) === 0 ? clean : Exchanges.baseSymbol(clean);
}

// Short exchange label for the badge, or "" when badges are off, the symbol has no
// exchange suffix, or no exchange is known. A plain US ticker has no suffix to
// replace, so it does not need a badge.
function exchangeBadge(ticker, exchange, mode) {
    if (Number(mode) !== 2 || !Exchanges.hasSuffix(ticker)) return "";
    var label = String(exchange === undefined || exchange === null ? "" : exchange).trim();
    return label !== "" ? label : Exchanges.shortLabel(ticker, "", "");
}

// Name and ticker together: "Company Name (TICK)", or "TICK (Company Name)" when the
// "swap names" preference is on. Falls back to just the ticker while the name is not
// known yet or when Yahoo only returned the ticker as the name.
function nameAndTicker(name, ticker, swap, loadingText) {
    var t = (ticker || "").trim().toUpperCase();
    if (!name || name === loadingText || name.trim().toUpperCase() === t) return t;
    return swap ? t + " (" + name + ")" : name + " (" + t + ")";
}
