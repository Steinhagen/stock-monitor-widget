.pragma library
// Headline list behaviour shared by the providers: merging the per-source lists into
// one newest-first list, and turning a timestamp into an age bucket. The caller keeps
// the per-symbol cache and decides when to re-fetch.

// Merge the lists of the providers, newest first. A link or title can appear in more
// than one feed (Yahoo and Google often carry the same report), so either key removes
// it; the first provider in the argument order keeps its copy.
function merge(yahoo, bvb, google) {
    var merged = [];
    var seen = {};
    var add = function(items) {
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var linkKey = String(item.link || "").trim().toLowerCase();
            var titleKey = String(item.title || "").trim().toLowerCase();
            var lk = linkKey === "" ? "" : "l:" + linkKey;
            var tk = titleKey === "" ? "" : "t:" + titleKey;
            if ((lk !== "" && seen[lk]) || (tk !== "" && seen[tk])) continue;
            if (lk !== "") seen[lk] = true;
            if (tk !== "") seen[tk] = true;
            merged.push(item);
        }
    };
    add(yahoo || []);
    add(bvb || []);
    add(google || []);
    merged.sort(function(a, b) { return (Number(b.time) || 0) - (Number(a.time) || 0); });
    return merged;
}

// Age bucket of a headline. The caller turns it into a translated string:
//   now  - under a minute (or a time in the future)
//   min  - n minutes, under an hour
//   h    - n hours, under a day
//   d    - n days, 1 to 7
//   date - older; show the date instead
function age(timeSec, nowMs) {
    var seconds = Math.floor(nowMs / 1000 - Number(timeSec));
    if (!(seconds >= 60)) return { unit: "now", n: 0 };
    if (seconds < 3600) return { unit: "min", n: Math.floor(seconds / 60) };
    if (seconds < 86400) return { unit: "h", n: Math.floor(seconds / 3600) };
    if (seconds < 8 * 86400) return { unit: "d", n: Math.floor(seconds / 86400) };
    return { unit: "date", n: 0 };
}
