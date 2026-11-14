import QtQuick
import QtTest
import "../../contents/ui/domain/sessions.js" as Sessions

TestCase {
    name: "Sessions"

    function test_status() {
        var session = { regular: { start: 100, end: 200 } };
        compare(Sessions.status(session, 150), "open");
        compare(Sessions.status(session, 250), "closed");
        compare(Sessions.status({ pre: { start: 50, end: 100 } }, 75), "pre");
        compare(Sessions.status({ post: { start: 200, end: 300 } }, 250), "post");
        compare(Sessions.status({ crypto: true }, 1), "open");
        compare(Sessions.status(null, 150), "");
    }

    function test_isClosed() {
        compare(Sessions.isClosed({ hasPrePost: true }, "pre"), false);
        compare(Sessions.isClosed({ hasPrePost: false }, "pre"), true);
        compare(Sessions.isClosed({ hasPrePost: false }, "post"), true);
        compare(Sessions.isClosed({ hasPrePost: true }, "closed"), true);
        compare(Sessions.isClosed(null, "closed"), false);
    }

    function test_awaitingFirstRegularQuote() {
        var session = { regular: { start: 100, end: 200 }, quoteTime: 50 };
        compare(Sessions.awaitingFirstRegularQuote(session, 150), true);
        compare(Sessions.awaitingFirstRegularQuote(session, 250), false);
        compare(Sessions.awaitingFirstRegularQuote({ regular: { start: 100, end: 200 },
                                                     quoteTime: 120 }, 150), false);
        compare(Sessions.awaitingFirstRegularQuote({ quoteTime: 120 }, 150), false);
        compare(Sessions.awaitingFirstRegularQuote(null, 150), false);
    }
}
