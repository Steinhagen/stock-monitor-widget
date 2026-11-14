import QtQuick
import "../domain/currencies.js" as Currency
import "../providers/fx/rates.js" as FxRates

// The exchange-rate cache used by the portfolio: the daily rates, when they were
// fetched, and the fetch itself. The rates are stored in the applet configuration, so
// a restart does not need a download; `configuration` is injected for tests.
Item {
    id: fx
    property var configuration: null

    readonly property var exchangeRates: {
        try {
            var cached = JSON.parse(configuration ? (configuration.exchangeRates || "{}") : "{}");
            return (cached && cached.rates) ? cached.rates : ({});
        } catch (e) {
            return ({});
        }
    }
    readonly property double exchangeRatesUpdated: Number(configuration ? configuration.exchangeRatesUpdated : 0) || 0
    readonly property double exchangeRatesNext: Number(configuration ? configuration.exchangeRatesNext : 0) || 0
    property bool exchangeRatesFetching: false

    // Converts an amount through the cached daily rates. Returns null when a rate is not
    // known yet, so callers can tell "no rate" apart from a real zero.
    function convertMoney(amount, from, to) {
        return Currency.convert(amount, from, to, exchangeRates);
    }

    function exchangeRatesDue() {
        // A missing or unreadable cache is due even if its timestamp looks fresh.
        if (!exchangeRates || Object.keys(exchangeRates).length < 2) return true;
        if (exchangeRatesUpdated <= 0) return true;
        var now = Math.floor(Date.now() / 1000);
        if (exchangeRatesNext > 0) return now >= exchangeRatesNext;
        return now - exchangeRatesUpdated >= 24 * 60 * 60;
    }

    function finishExchangeRates(error) {
        exchangeRatesFetching = false;
        if (error) console.log("Exchange rates: " + error);
    }

    // Stores the feed's rates. `rates` maps a currency code to units of that currency
    // per one unit of `base`; the cross-rate conversion works with any base.
    function saveExchangeRates(base, rates, updated, next) {
        if (!rates || !configuration) return false;
        var clean = {};
        var count = 0;
        for (var code in rates) {
            var value = Number(rates[code]);
            if (!(value > 0)) continue;
            clean[String(code).toUpperCase()] = value;
            count++;
        }
        if (count < 2) return false;
        var b = String(base || "USD").toUpperCase();
        if (!(clean[b] > 0)) clean[b] = 1;
        try {
            configuration.exchangeRates = JSON.stringify({ base: b, rates: clean });
            configuration.exchangeRatesUpdated = String(updated);
            configuration.exchangeRatesNext = String(next);
        } catch (e) {
            console.log("Error saving exchange rates: " + e);
            return false;
        }
        exchangeRatesFetching = false;
        return true;
    }

    function fetchExchangeRates() {
        if (exchangeRatesFetching) return;
        exchangeRatesFetching = true;
        FxRates.fetch(function(rates, error) {
            if (error) {
                finishExchangeRates(error);
                return;
            }
            if (!saveExchangeRates(rates.base, rates.rates, rates.updated, rates.next))
                finishExchangeRates("no exchange-rate feed available");
        });
    }

    function maybeRefreshExchangeRates() {
        if (exchangeRatesFetching) return;
        if (exchangeRatesDue()) fetchExchangeRates();
    }

    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: fx.maybeRefreshExchangeRates()
    }
}
