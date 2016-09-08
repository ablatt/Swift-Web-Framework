# Design Overview #

## I. High Level Overview
**ClientObject.swift** - Contains the client request headers, form data, response headers, and response body.  
**HTTPServer.swift** - This is the main file that starts the HTTP server and exposes public API (although we might want to separate this into an extension)  
**HTTPServerExtensions.swift** - Contains utility functions to the user of the framework such as opening a file.  
**Queue.swift** - Queue data structure since there's no STD in Swift with a Queue  
**Utility.swift** - Contains internal utility functions for HTTPServer.swift  
**main.swift** - Test program. This should really be separate with testing done using a test harness contained in another project.  
