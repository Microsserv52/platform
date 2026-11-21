function handler(event) {
    var request = event.request;
    var uri = request.uri;

    function toIndex(path) {
        if (path === "" || path === "/") {
            return "/index.html";
        }
        if (path.endsWith("/")) {
            return path + "index.html";
        }
        var last = path.substring(path.lastIndexOf("/") + 1);
        if (last.indexOf(".") === -1) {
            return path + "/index.html";
        }
        return path;
    }

    if (uri === "/store" || uri.indexOf("/store/") === 0) {
        request.uri = toIndex(uri.substring("/store".length));
    } else if (uri === "/admin" || uri.indexOf("/admin/") === 0) {
        request.uri = toIndex(uri.substring("/admin".length));
    } else if (uri === "/api" || uri.indexOf("/api/") === 0) {
        request.uri = uri.substring("/api".length) || "/";
    } else {
        request.uri = toIndex(uri);
    }

    return request;
}
