.pragma library
// The portfolio's valuation math: one lot's market value/gain and the whole portfolio
// summary. Quotes and exchange rates are passed in, so the page keeps ownership of the
// network and of the Plasma configuration; this module only computes.

.import "../../domain/currencies.js" as Currency

// `rates` is the cached exchange-rate map (1 unit of the base = rate units).
function convert(amount, from, to, rates) {
    return Currency.convert(amount, from, to, rates || {});
}

// Current value and gain for one lot, in that lot's own currency. `quote` is the
// Yahoo chart meta for the ticker (price in major units, currency and previous close).
function lotMarketData(lot, quote, rates) {
    if (!quote || !(quote.price > 0)) return null;

    var lotCurrency = Currency.major(lot.currency) || "USD";
    var quoteCurrency = Currency.major(quote.currency);
    var price = quote.price * Currency.minorFactor(quote.currency);
    if (quoteCurrency !== "" && quoteCurrency !== lotCurrency) {
        price = convert(price, quoteCurrency, lotCurrency, rates);
        if (price === null) return null;
    }

    var shares = Number(lot.shares) || 0;
    var average = Number(lot.averageCost) || 0;
    var cost = average * shares;
    var value = price * shares;
    var gain = (price - average) * shares;

    var previousClose = Number(quote.previousClose) || 0;
    var previousPrice = previousClose > 0
                        ? previousClose * Currency.minorFactor(quote.currency) : null;
    if (previousPrice !== null && quoteCurrency !== "" && quoteCurrency !== lotCurrency)
        previousPrice = convert(previousPrice, quoteCurrency, lotCurrency, rates);
    var dayGain = (previousPrice !== null && previousPrice > 0)
                  ? (price - previousPrice) * shares : null;
    var dayPercent = (dayGain !== null && previousPrice > 0)
                     ? (dayGain / (previousPrice * shares)) * 100 : 0;

    return {
        price: price,
        value: value,
        gain: gain,
        percent: cost > 0 ? (gain / cost) * 100 : 0,
        perShare: price - average,
        dayGain: dayGain,
        dayPercent: dayPercent,
        currency: lotCurrency
    };
}

// Totals for the summary, in the configured portfolio currency. `quotes` is keyed by
// upper-case ticker (like the page's quote map).
function totals(lots, quotes, targetCurrency, rates) {
    var target = Currency.major(targetCurrency) || "USD";
    var result = {
        currency: target,
        cost: 0,
        value: 0,
        gain: 0,
        gainPercent: 0,
        day: 0,
        dayPercent: 0
    };
    if (!lots || lots.length === 0) return result;

    var cost = 0, value = 0, day = 0;
    var costKnown = true, valueKnown = true, dayKnown = true;
    for (var i = 0; i < lots.length; i++) {
        var lot = lots[i];
        var lotCurrency = Currency.major(lot.currency) || "USD";
        var shares = Number(lot.shares) || 0;
        var average = Number(lot.averageCost) || 0;

        var convertedCost = convert(average * shares, lotCurrency, target, rates);
        if (convertedCost === null) costKnown = false;
        else cost += convertedCost;

        var ticker = String(lot.ticker || "").trim().toUpperCase();
        var market = lotMarketData(lot, quotes ? quotes[ticker] : null, rates);
        if (!market) {
            valueKnown = false;
            dayKnown = false;
            continue;
        }

        var convertedValue = convert(market.value, market.currency, target, rates);
        if (convertedValue === null) valueKnown = false;
        else value += convertedValue;

        if (market.dayGain === null) {
            dayKnown = false;
        } else {
            var convertedDay = convert(market.dayGain, market.currency, target, rates);
            if (convertedDay === null) dayKnown = false;
            else day += convertedDay;
        }
    }

    result.cost = costKnown ? cost : null;
    result.value = valueKnown ? value : null;
    result.gain = (costKnown && valueKnown) ? value - cost : null;
    result.gainPercent = (result.gain !== null && cost > 0) ? ((value - cost) / cost) * 100 : 0;
    result.day = dayKnown ? day : null;
    result.dayPercent = (result.day !== null && valueKnown && (value - day) > 0)
                        ? (day / (value - day)) * 100 : 0;
    return result;
}
