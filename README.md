# Swift-Web-Framework
An easy to use web framework written in Swift. A work in progress...

# Example usage
'''
let h = HTTPServer();

h.addGETRoute("/", callback: { (request: ClientObject) -> String in
    var page = "<html> Hello, world!</html>";
    return page;
});

h.addGETRoute("/test", callback: { (request: ClientObject) -> String in
    var page = "<html> Success in routing </html>";
    return page;
});

h.startServer(onPort: 9000);
'''