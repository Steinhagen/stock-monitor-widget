import QtQuick
import QtTest
import "../../contents/ui/domain/news.js" as NewsModel

TestCase {
    name: "NewsModel"

    function test_mergeDedupesAndSorts() {
        var yahoo = [
            { title: "Same story", link: "https://a", source: "Yahoo", time: 10 },
            { title: "Older", link: "https://b", source: "Yahoo", time: 5 }
        ];
        var bvb = [
            { title: "Same story", link: "https://c", source: "BVB", time: 20 }
        ];
        var google = [
            { title: "Newest", link: "https://d", source: "Google", time: 30 },
            { title: "Older", link: "https://e", source: "Google", time: 1 }
        ];
        var merged = NewsModel.merge(yahoo, bvb, google);
        compare(merged.length, 3);
        compare(merged[0].title, "Newest");
        compare(merged[1].title, "Same story");
        compare(merged[1].source, "Yahoo");
        compare(merged[2].title, "Older");
    }

    function test_mergeEmpty() {
        compare(NewsModel.merge().length, 0);
        compare(NewsModel.merge(null, undefined, []).length, 0);
    }

    function test_age() {
        var now = 1794000000000; // ms
        var t = now / 1000;
        compare(NewsModel.age(t, now).unit, "now");
        compare(NewsModel.age(t - 60, now).unit, "min");
        compare(NewsModel.age(t - 3600, now).unit, "h");
        compare(NewsModel.age(t - 86400, now).unit, "d");
        compare(NewsModel.age(t - 9 * 86400, now).unit, "date");
    }
}
