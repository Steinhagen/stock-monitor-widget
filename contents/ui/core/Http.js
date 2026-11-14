.pragma library
// One implementation of the request rules the providers share: a timeout, a single
// completion callback, HTTP status handling and optional JSON parsing. Callers get
// data or an error object ({ code, message, status }), never a half-finished request.

function failure(code, message, status) {
    return { code: code, message: message, status: status || 0 };
}

function request(method, url, body, options, done) {
    var opts = options || {};
    var settled = false;
    var finish = function(data, error) {
        if (settled) return;
        settled = true;
        done(data, error);
    };

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status < 200 || xhr.status >= 300) {
            finish(null, failure("http", "request failed (HTTP " + xhr.status + ")", xhr.status));
            return;
        }
        var data = xhr.responseText;
        if (opts.parse === "json") {
            try {
                data = JSON.parse(data);
            } catch (e) {
                finish(null, failure("parse", "could not parse the reply: " + e));
                return;
            }
        }
        finish(data, null);
    };
    xhr.ontimeout = function() {
        finish(null, failure("timeout", "request timed out"));
    };
    xhr.onerror = function() {
        finish(null, failure("network", "request failed"));
    };

    var headers = opts.headers || {};
    xhr.open(method, url);
    for (var name in headers) {
        if (Object.prototype.hasOwnProperty.call(headers, name))
            xhr.setRequestHeader(name, headers[name]);
    }
    xhr.timeout = Number(opts.timeout) > 0 ? Number(opts.timeout) : 20000;
    xhr.send(body === undefined ? null : body);
}

function getText(url, options, done) {
    request("GET", url, null, options, done);
}

function getJson(url, options, done) {
    var opts = {};
    for (var key in options) {
        if (Object.prototype.hasOwnProperty.call(options, key)) opts[key] = options[key];
    }
    opts.parse = "json";
    request("GET", url, null, opts, done);
}

function postText(url, body, options, done) {
    request("POST", url, body, options, done);
}
