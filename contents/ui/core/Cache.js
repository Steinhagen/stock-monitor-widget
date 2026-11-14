.pragma library
// The freshness rules the per-symbol caches in the controllers share: when a cached
// entry is old enough to reload, and when a failed attempt is still too recent to
// retry. The cache itself stays a QML property of the controller, so bindings update.

function key(symbol) {
    return String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
}

// A successful load younger than `ttlMs`.
function isFresh(entry, ttlMs, nowMs) {
    return !!entry && entry.loaded === true && entry.error !== true
           && nowMs - (Number(entry.time) || 0) < ttlMs;
}

// The last attempt is still inside the back-off window.
function isThrottled(entry, retryMs, nowMs) {
    return !!entry && Number(entry.attempt) > 0 && nowMs - Number(entry.attempt) < retryMs;
}
