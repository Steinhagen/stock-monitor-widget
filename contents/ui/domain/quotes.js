.pragma library
// Yahoo chart API parameters for a display range. Kept pure so the mapping between the
// range buttons and the request can be tested without a network.

// Yahoo requires specific intervals for specific ranges to return usable data. The 1D
// range asks for two days so indices still carry a reliable previous close.
function apiParams(range, showExtendedHours) {
    switch (range) {
        case "1D":  return "range=2d&interval=2m" + (showExtendedHours ? "&includePrePost=true" : "");
        case "5D":  return "range=5d&interval=15m";
        case "1M":  return "range=1mo&interval=60m"; // '1mo' is Yahoo syntax
        case "6M":  return "range=6mo&interval=1d";
        case "YTD": return "range=ytd&interval=1d";
        case "1Y":  return "range=1y&interval=1d";
        case "5Y":  return "range=5y&interval=1wk";
        case "Max": return "range=max&interval=1mo";
        default:    return "range=1d&interval=2m";
    }
}
