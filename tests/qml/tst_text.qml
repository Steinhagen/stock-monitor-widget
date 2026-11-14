import QtQuick
import QtTest
import "../../contents/ui/core/Text.js" as Text

TestCase {
    name: "Text"

    function test_escapeHtml() {
        compare(Text.escapeHtml("A & B < C > D"), "A &amp; B &lt; C &gt; D");
        compare(Text.escapeHtml("plain"), "plain");
        compare(Text.escapeHtml(null), "");
        compare(Text.escapeHtml(undefined), "");
        compare(Text.escapeHtml(42), "42");
    }
}
