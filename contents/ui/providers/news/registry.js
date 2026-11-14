.pragma library
// The news sources the controller can use, in display/merge order. Adding a source is a
// descriptor plus one entry here; the controller does not know the providers.

.import "yahooSource.js" as Yahoo
.import "bvbSource.js" as Bvb
.import "googleSource.js" as Google

var SOURCES = [Yahoo, Bvb, Google];

// The sources enabled by the settings and able to serve this symbol (BVB only covers
// .RO listings).
function enabledSources(settings, symbol) {
    var sources = [];
    for (var i = 0; i < SOURCES.length; i++) {
        if (SOURCES[i].supports(settings, symbol)) sources.push(SOURCES[i]);
    }
    return sources;
}

function hasAny(settings, symbol) {
    return enabledSources(settings, symbol).length > 0;
}

function byId(id) {
    for (var i = 0; i < SOURCES.length; i++) {
        if (SOURCES[i].id === id) return SOURCES[i];
    }
    return null;
}
