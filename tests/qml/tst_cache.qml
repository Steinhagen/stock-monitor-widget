import QtQuick
import QtTest
import "../../contents/ui/core/Cache.js" as Cache

TestCase {
    name: "Cache"

    function test_key() {
        compare(Cache.key(" brd.ro "), "BRD.RO");
        compare(Cache.key(""), "");
        compare(Cache.key(null), "");
    }

    function test_isFresh() {
        var entry = { loaded: true, error: false, time: 100 };
        verify(Cache.isFresh(entry, 50, 120));
        verify(!Cache.isFresh(entry, 50, 200));
        verify(!Cache.isFresh({ loaded: false, error: false, time: 100 }, 50, 120));
        verify(!Cache.isFresh({ loaded: true, error: true, time: 100 }, 50, 120));
        verify(!Cache.isFresh(null, 50, 120));
    }

    function test_isThrottled() {
        verify(Cache.isThrottled({ attempt: 100 }, 60, 150));
        verify(!Cache.isThrottled({ attempt: 100 }, 60, 200));
        verify(!Cache.isThrottled({}, 60, 150));
        verify(!Cache.isThrottled(null, 60, 150));
    }
}
