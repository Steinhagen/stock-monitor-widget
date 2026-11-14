.pragma library
// Yahoo's analyst price-target history. quoteSummary is crumb-protected: a successful
// call needs the cookie set by fc.yahoo.com and the crumb token from
// /v1/test/getcrumb. Both are kept for the session, and an expired crumb (HTTP 401) is
// refreshed once before the call is retried.
//
// done(items, summary, error) — items and summary are null on failure.

.import "../../core/Http.js" as Http
.import "../../domain/analysts.js" as Analyst

var crumb = "";
var loading = false;
var queue = [];

function fetch(symbol, done) {
    ensureCrumb(function(token) {
        fetchSummary(symbol, token, false, done);
    }, function(error) {
        done(null, null, error);
    });
}

// One crumb request at a time; callers wait until it succeeds or fails.
function ensureCrumb(onSuccess, onFailure) {
    if (crumb !== "") {
        onSuccess(crumb);
        return;
    }
    queue.push({ success: onSuccess, failure: onFailure });
    if (loading) return;
    loading = true;
    // Warm the cookie; the reply itself is not used.
    Http.getText("https://fc.yahoo.com", { timeout: 15000 }, function() {
        requestCrumb();
    });
}

function requestCrumb() {
    Http.getText("https://query1.finance.yahoo.com/v1/test/getcrumb", { timeout: 15000 },
        function(text, error) {
            var token = String(text === undefined || text === null ? "" : text).trim();
            if (!error && token !== "") {
                crumb = token;
                finishCrumb("");
                return;
            }
            finishCrumb(error ? "crumb request failed: " + error.message : "crumb request failed");
        });
}

function finishCrumb(error) {
    var pending = queue;
    queue = [];
    loading = false;
    for (var i = 0; i < pending.length; i++) {
        if (error === "") pending[i].success(crumb);
        else pending[i].failure(error);
    }
    if (error !== "") console.log("Analyst price targets: " + error);
}

function summaryUrl(symbol, token) {
    return "https://query1.finance.yahoo.com/v10/finance/quoteSummary/"
         + encodeURIComponent(symbol)
         + "?modules=upgradeDowngradeHistory,financialData&crumb="
         + encodeURIComponent(token);
}

function fetchSummary(symbol, token, retried, done) {
    Http.getJson(summaryUrl(symbol, token), { timeout: 20000 }, function(reply, error) {
        if (error && error.status === 401 && !retried) {
            // The crumb has expired (or was issued for another cookie). Get a new one
            // once and retry the same symbol.
            crumb = "";
            ensureCrumb(function(nextToken) {
                fetchSummary(symbol, nextToken, true, done);
            }, function(crumbError) {
                done(null, null, crumbError);
            });
            return;
        }
        if (error) {
            done(null, null, error.message);
            return;
        }
        var parsed;
        try {
            parsed = Analyst.parse(reply);
        } catch (e) {
            done(null, null, "could not parse the reply: " + e);
            return;
        }
        done(parsed.items, parsed.summary, "");
    });
}
