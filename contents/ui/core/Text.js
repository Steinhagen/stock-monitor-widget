.pragma library
// Text helpers shared by the views. The tooltip and the watchlist build rich-text
// labels, so values coming from a feed (and translated captions) are escaped before
// they are embedded in HTML.

function escapeHtml(value) {
    return String(value === undefined || value === null ? "" : value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}
