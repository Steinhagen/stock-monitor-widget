.pragma library
// Session decisions for a symbol, from the trading periods Yahoo returns in the quote
// metadata. Everything takes the session record and "now" as arguments, so the caller
// (which owns the clock and the per-symbol cache) stays responsible for reactivity.

// "open", "pre", "post" or "closed" for the exchange the symbol trades on. Crypto has
// no closing time.
function status(session, nowSec) {
    if (!session) return "";
    if (session.crypto) return "open";
    if (session.regular && nowSec >= session.regular.start && nowSec < session.regular.end) return "open";
    if (session.pre && nowSec >= session.pre.start && nowSec < session.pre.end) return "pre";
    if (session.post && nowSec >= session.post.start && nowSec < session.post.end) return "post";
    return "closed";
}

// True when the instrument's market is closed: outside every session, or in a pre/post
// window for an instrument that has no extended-hours trading at all (indices, for
// example). Unknown symbols are not marked closed.
function isClosed(session, statusValue) {
    if (!session) return false;
    if (statusValue === "closed") return true;
    return !session.hasPrePost && (statusValue === "pre" || statusValue === "post");
}

// True while the regular session has started but its first quote has not arrived.
// Yahoo keeps returning the previous close, with its old timestamp, until the first
// trade of the new session reaches the feed.
function awaitingFirstRegularQuote(session, nowSec) {
    if (!session || !session.regular) return false;
    if (nowSec < session.regular.start || nowSec >= session.regular.end) return false;
    return !(session.quoteTime > 0) || session.quoteTime < session.regular.start;
}
