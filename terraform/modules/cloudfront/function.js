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
        request.headers["x-site"] = { value: "store" };
        request.uri = toIndex(uri.substring("/store".length));
    } else if (uri === "/admin" || uri.indexOf("/admin/") === 0) {
        request.headers["x-site"] = { value: "admin" };
        request.uri = toIndex(uri.substring("/admin".length));
    } else if (uri === "/api" || uri.indexOf("/api/") === 0) {
        request.uri = uri.substring("/api".length) || "/";
    } else if (uri === "/faro" || uri.indexOf("/faro/") === 0) {
        request.uri = uri.substring("/faro".length) || "/collect";
    } else {
        request.headers["x-site"] = { value: "landing" };
        request.uri = toIndex(uri);
    }

    return request;
}
