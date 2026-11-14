.pragma library
// Daily exchange rates for the portfolio conversion. The primary feed is
// open.er-api.com; jsDelivr's currency-api is the fallback when it cannot be reached.
// The caller stores the result in the configuration and decides when to refresh.

.import "../../core/Http.js" as Http

var PRIMARY = "https://open.er-api.com/v6/latest/USD";
var FALLBACK = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json";

// done(rates, error) with rates = { base, rates, updated, next } (unix seconds).
function fetch(done) {
    var finished = false;
    var finish = function(rates, error) {
        if (finished) return;
        finished = true;
        done(rates, error);
    };
    Http.getJson(PRIMARY, { timeout: 20000 }, function(data, error) {
        if (!error && data && data.result === "success" && data.rates) {
            var now = Math.floor(Date.now() / 1000);
            finish({
                base: data.base_code || "USD",
                rates: data.rates,
                updated: Number(data.time_last_update_unix) || now,
                next: Number(data.time_next_update_unix) || (now + 86400)
            });
            return;
        }
        fetchFallback(finish);
    });
}

function fetchFallback(finish) {
    Http.getJson(FALLBACK, { timeout: 20000 }, function(data, error) {
        var now = Math.floor(Date.now() / 1000);
        if (error || !data || !data.usd) {
            finish(null, "no exchange-rate feed available");
            return;
        }
        finish({ base: "USD", rates: data.usd, updated: now, next: now + 86400 });
    });
}
