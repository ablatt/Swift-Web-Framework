# Swift-Web-Framework
* Easy to use web framework written in Swift
* Unifies iOS app development and backend development under a single language, Swift 
* Can easily integrate Apple services (that expose a Swift API) into the backend (Ads, Subscriptions, Apple Pay, etc...)
* Promotes Swift as a primary developer language (since a lot of modern software engineering is really backend development)
* A work in progress. Open to those who want to contribute!
* Check out DesignDoc.md for a more detailed overview and how to get started!

# Current Status
SwiftWebFramework can serve HTTP/1.1 requests on both macOS and Linux. It is a combined HTTP webserver and webframework so there is no need to spin up a separate web server such as Apache (although CGI support is being considered in future versions). 

Support for HTTPS and HTTP/2.0 are the features that will be worked on next.

# Installation on Linux
1. Install Swift on Linux (https://swift.org/getting-started/)
2. Install Swift libdispatch (https://github.com/apple/swift-corelibs-libdispatch)
3. No other dependencies needed. Use the Swift package manager to build the SwiftWebFramework project

# Installation on Mac
Just launch the Xcode project and click the 'Run' button to start serving HTTP requests. This can also be done via the Swift Package manager. Routes and backend logic are added in main.swift. The source code can also be integrated into separate projects without need to carry over any Xcode project settings.

# Example usage
let h = HTTPServer();  

h.addGETRoute("/", callback: { (request: ClientObject) -> String in  
&nbsp;&nbsp;&nbsp;var page = "<html> Hello, world!</html>";  
&nbsp;&nbsp;&nbsp;return page;  
});  

h.addGETRoute("/test", callback: { (request: ClientObject) -> String in  
&nbsp;&nbsp;&nbsp;var page = "<html> Success in routing </html>";  
&nbsp;&nbsp;&nbsp;return page;  
});  

h.startServer(onPort: 9000);
