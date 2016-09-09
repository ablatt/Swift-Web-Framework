# Swift-Web-Framework
* Easy to use web framework written in Swift.  
* Unifies iOS app development and backend development under a single language, Swift  
* Can easily integrate Apple services (that expose a Swift API) into backend (Ads, subscriptions, etc...)   
* A work in progress. Open to those who want to contribute!
* Check out DesignDoc.md for a more detailed overview and how to get started!

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
