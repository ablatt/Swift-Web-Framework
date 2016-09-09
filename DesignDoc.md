# Design Overview #

## I. High Level Overview
**ClientObject.swift** - Contains the client request headers, form data, response headers, and response body.  
**HTTPServer.swift** - This is the main file that starts the HTTP server and exposes public API (although we might want to separate this into a separate file to reduce code clutter). Currently only runs on localhost but can easily be changed.
**HTTPServerExtensions.swift** - Contains utility functions to the user of the framework such as opening a file.  
**Queue.swift** - Queue data structure since there's no STD in Swift with a Queue  
**Utility.swift** - Contains internal utility functions for HTTPServer.swift  
**main.swift** - Test program. This should really be separate with testing done using a test harness contained in another project.  

## II. HTTPServer.swift Design
The starting point of this framework is in the method **startSeverEventLoop**. This method uses BSD system calls to listen for incoming TCP client connections on the port the user passed into the method. From here, an event loop is dispatched via GCD on a separate queue, and this event loop uses kqueue to multiplex between accept and recv so that we are not blocked and can receive multiple client events.  
  
When a client connection is accepted, we register the client into kqueue and start receiving data from the client. HTTP data is extracted, the header validated (still not 100% HTTP 1.1 compliant), and the client header + message body sent to callback the user registered for the client route that was parsed from the received data (this might be changed later so that we have a queue of requests that are periodically processed using an NSTimer).  
  
The callback returns a string and the response is placed in a response queue. A NSTimer periodically checks the response queue to send responses back to the client.

### III. Contributing
There are currently many open issues in the issues list that need to be addressed and probably more in the future. To get started, it might be helpful to create some basic HTML files to serve via Safari or Chrome. The file **main.swift** register some basic POST and GET routes and serves some basic HTML files as a test example (in the future, the HTTP server will be a .framework file and we'll have a separate test app). The logic and flow of the design can be traced starting with the method **startSeverEventLoop**. From there, feel free to start working on an issue or file a new issue that should be addressed/fixed.
