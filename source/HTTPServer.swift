    //
//  HTTPServer.swift
//  SwiftWebFramework
//
//  Created by user on 8/21/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation
import Darwin

// global constants
let MAX_CONNECTIONS:Int32 = 1000
let KQUEUE_TIMEOUT:Int = 100000;
let KQUEUE_MAX_EVENTS = 32;
let POLL_TIME = 0.00005;
    
//TODO: need signal handlers
open class HTTPServer : NSObject {
    // dictionaries containing the routes and callbacks
    fileprivate var GETRoutes = Dictionary<String, RouteClosure>();
    fileprivate var HEADRoutes = Dictionary<String, RouteClosure>();
    fileprivate var POSTRoutes = Dictionary<String, RouteClosure>();
    fileprivate var PUTRoutes = Dictionary<String, RouteClosure>();
    fileprivate var DELETERoutes = Dictionary<String, RouteClosure>();
    fileprivate var TRACERoutes = Dictionary<String, RouteClosure>();
    fileprivate var OPTIONSRoutes = Dictionary<String, RouteClosure>();
    fileprivate var CONNECTRoutes = Dictionary<String, RouteClosure>();
    fileprivate var PATCHRoutes = Dictionary<String, RouteClosure>();
    fileprivate var HOSTRoutes = Dictionary<String, RouteClosure>();
    
    // other callbacks
    fileprivate var statusCodeHandler = Dictionary<String, StatusCodeClosure> ();
    fileprivate var middlewareList = Array<MiddlewareClosure>();
    
    // queues to perform units of work
    fileprivate var workerThread = DispatchQueue(label: "http.worker.thread", attributes: DispatchQueue.Attributes.concurrent);       // concurrent queue for processing and work
    fileprivate var clientThread = DispatchQueue(label: "http.client.thread", attributes: []);           // serial queue to handle client requests
    fileprivate let lockQueue = DispatchQueue(label: "httpserver.lock", attributes: []);

    // list of connected clients
    fileprivate var clientsList = Dictionary<Int32, ClientObject>();
    
    // queue of connected clients to send responses to
    fileprivate var responseQueue = Queue<ClientObject>();
    
    // socket variables
    var kq:Int32 = -1;                  // kernel queue descriptor
    var serverSock:Int32 = 0;             // server socket

//MARK: Initializers
    override init () {
        // setup default status code handlers
        for (statusCode, description) in httpStatusCodes {
            statusCodeHandler[statusCode] = {(request: ClientObject) -> String in
                return statusCode + " - " + description + "\n";
            }
        }
    }

//MARK: Scheduling methods
    /**
        Schedule error response
     */
    fileprivate func scheduleStatusCodeResponse(withStatusCode statusCode:String, forClient client:ClientObject) {
        guard statusCodeHandler[statusCode] != nil else {
            client.response = "Error in request."
            self.responseQueue.enqueue(client);
            return;
        }
        
        client.response = addResponseHeader(statusCodeHandler["400"]!(client), withStatusCode: statusCode);
        self.responseQueue.enqueue(client);
    }

//MARK: Methods to create the response body and header
    /**
        Schedule the response
     */
    fileprivate func routeRequest(forClient client: ClientObject) {
        // should always return true since it was processed in validateRequestHeader method
        guard let URI = client.requestHeader["URI"] else {
            print("URI not detected");
            return;
        }
        
        // process each different HTTP method
        switch client.requestHeader["METHOD"]! {
        case "GET":
             guard let callback = GETRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "HEAD":
            guard let callback = HEADRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "POST":
            guard let callback = POSTRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "PUT":
            guard let callback = PUTRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "DELETE":
            guard let callback = DELETERoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "TRACE":
            guard let callback = TRACERoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "OPTIONS":
            guard let callback = OPTIONSRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "CONNECT":
            guard let callback = CONNECTRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "PATCH":
            guard let callback = PATCHRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        case "HOST":
            guard let callback = HOSTRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            workerThread.async(execute: {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(client);
            });
        default:
            // defaults to 404 if method not found
            scheduleStatusCodeResponse(withStatusCode: "404", forClient: client);
        }
    }
    
    /**
        Create the response header
     */
    //TODO: Add more HTTP headers
    func addResponseHeader(_ response:String, withStatusCode statusCode:String) -> String {
        // create HTTP-message
        var header = "HTTP/1.1 ";
        switch statusCode {
        case "200":
            header += statusCode + " OK";
        default:
            header += statusCode + " Bad Request";
        }
        header += "\r\n";
        
        // add Content-Length
        let numBytes = response.characters.count;
        header += "Content-Length: \(numBytes)\r\n";
        
        // add time header
        
        return header + "\r\n" + response + "\r\n";
    }
    
//MARK: Parsing and validation
    /**
        Validate HTTP header
     */
    fileprivate func validateRequestHeader(_ client: ClientObject) -> Bool {
        // validate HTTP method
        guard client.requestHeader["METHOD"] != nil else {
            return false;
        }
        
        // validate HTTP URI
        guard client.requestHeader["URI"] != nil else {
            return false;
        }
        
        // pass request to user defined closures
        for middleware in middlewareList {
            if middleware(client) == false {
                return false;
            }
        }
        
        // validation ok
        return true;
    }
    
    /**
        Parses out form data from the HTTP POST request
    */
    fileprivate func parseFormData(FromRequest request:[String], startingAtIndex index:Int) -> Dictionary<String, String> {
        var formData = Dictionary<String, String>();
        
        // iterate through all the lines containing form data and extract
        for i in index...(request.count - 1) {
            // different form data is delimited by &
            let postEntries = request[i].components(separatedBy: "&");
            for j in 0...(postEntries.count - 1) {
                let formPair = postEntries[j].components(separatedBy: "=");
                guard formPair.count == 2 else {
                    formData[formPair[0]] = "";
                    continue;
                }
                formData[formPair[0]] = formPair[1];
            }
        }
        return formData;
    }
    
    /**
        Special function for processing POST requests
     */
    fileprivate func parseMessageBody(_ lines:[String], forClient client:ClientObject) -> Bool {
        guard var contentLength = client.requestHeader["Content-Length"] else {
            print("can't fetch content length");
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: client);
            return false;
        }
        
        // strip white space and convert to int
        contentLength = contentLength.replacingOccurrences(of: "\r", with: "");
        contentLength = contentLength.replacingOccurrences(of: " ", with: "");
        guard let bodySize = Int(contentLength) else {
            print("Content-Length header not found");
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: client);
            return false;
        }
        
        // set body in client object
        for i in (0...lines.count-1) {
            client.bodyLength += lines[i].characters.count*MemoryLayout<CChar>.size;
            if client.requestBody == nil {
                client.requestBody = [String]();
            }
            client.requestBody!.append(lines[i]);
        }
        
        // check if full body message was received
        if client.bodyLength == bodySize {
            return true;
        } else {
            return false;
        }
    }
    
    /**
        Process request header from client
     */
    fileprivate func parseRequest(forClient client: ClientObject) {
        // create the request dictionary to hold HTTP header key and values
        client.requestHeader = Dictionary<String, String>();
        client.requestHeader["METHOD"] = nil;
        client.requestHeader["URI"] = nil;
        
        // initial line should contain URI & method
        let lines = client.rawRequest.components(separatedBy: "\n");
        var tokens = lines[0].components(separatedBy: " ");
        guard tokens.count >= 2 else {
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: client);
            return;
        }
        
        // set URI and HTTP methods parsed from request
        client.requestHeader["METHOD"] = tokens[0];
        client.requestHeader["URI"] = tokens[1];
        
        // send flag
        var sendFlag = true;
        
        // process the other HTTP header entries
        for i in 1...(lines.count - 1) {
            // header is in key:val format
            tokens = lines[i].components(separatedBy: ":");

            // message body might already exist after head so extract the partial body
            if client.requestHeader["METHOD"] == "POST" && lines[i] == "\r"{
                let bodyArr = Array(lines[(i+1)...(lines.count-1)]);
                
                // we can start sending a response of the transfer encoding is chunked-encoding
                var chunkedEncoding = false;
                if client.requestHeader["Transfer-Encoding"] != nil &&
                    client.requestHeader["Transfer-Encoding"] == "chunked" {
                    chunkedEncoding = true;
                }
                
                // extract form data if the full body is in the request object
                if parseMessageBody(bodyArr, forClient: client) || chunkedEncoding == true {
                    client.formData = parseFormData(FromRequest: lines, startingAtIndex: i+1);
                } else {
                    sendFlag = false;
                }
                
                // POST data should be last thing in header so break
                break;
            } else {
                // header data has to be in key:value pair
                guard tokens.count >= 2 else {
                    client.requestHeader[tokens[0]] = "";
                    continue;
                }
                
                // clean tokens and set to request dictionary in client object
                tokens[1] = tokens[1].replacingOccurrences(of: " ", with: "");
                tokens[1] = tokens[1].replacingOccurrences(of: "\r", with: "");
                client.requestHeader[tokens[0]] = tokens[1];
            }
        }
        
        // validate request header
        guard validateRequestHeader(client) else {
            print("Invalid request header");
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: client);
            return;
        }
        
        // schedule request processing and response
        if sendFlag == true {
            routeRequest(forClient: client);
        }
    }
    
//MARK: Event loop functions
    /**
        Timed function that attempts to send responses dispatched in a serial queue
     */
    @objc fileprivate func sendResponse(_ timer:Timer!) {
        while self.responseQueue.empty() == false {
            // lock since it's possible response object is large
            lockQueue.sync(execute: {
                guard let client = self.responseQueue.dequeue() else {
                    print("failed to get client from response queue");
                    return;
                }
                
                let fd = client.fd;
                guard let response = client.response else {
                    print("failed to get response for client \(fd)");
                    return;
                }
                
                let buff = response.cString(using: String.Encoding.utf8)!;
                let numBytes = buff.count;
                var bytesSent = 0;
                while bytesSent != numBytes {
                    let res = send(fd, buff, response.lengthOfBytes(using: String.Encoding.utf8), MSG_OOB);
                    guard res >= 0 else {
                        print("failed to send response")
                        return;
                    }
                    bytesSent += numBytes;
                    fsync(fd);
                }
                print("Bytes sent: \(bytesSent) / \(numBytes)");
                
                // if connection type is keep-alive, don't close the connection
                guard let keepAlive = self.clientsList[fd]?.requestHeader["Connection"] ,
                        keepAlive == "keep-alive" else {
                    print("keep-alive is not detected");
                    close(fd);
                    self.clientsList[fd] = nil;
                    return;
                }
            });
        }
    }
    
    @objc fileprivate func serverEventLoop(onServerSock serverSock:Int32) {
        // create array to store returned kevents
        var kEventList = Array(repeating: kevent(), count: KQUEUE_MAX_EVENTS);
        
        // create timeout to get a kevent (in nanoseconds)
        var kTimeOut = timespec();
        kTimeOut.tv_nsec = KQUEUE_TIMEOUT;

        // lock critical section of reading and converting buff to string
        self.lockQueue.sync(execute: {
            // get kernel events
            let numEvents = kevent(self.kq, nil, 0, &kEventList, Int32(KQUEUE_MAX_EVENTS), &kTimeOut);
            guard numEvents != -1 else {
                perror("kevent");
                return;
            }
            
            if numEvents == 0 {
                return;
            }
            
            // iterate through all returned kernel events
            for i in 0...Int(numEvents - 1) {
                // check if kevent is on socket fd
                if kEventList[i].ident == UInt(self.serverSock) {
                    // accept incoming connection
                    var clientSock:Int32 = -1;
                    var clientInfo = sockaddr();
                    var clientInfoSize = socklen_t(MemoryLayout<sockaddr>.size);
                    clientSock = accept(self.serverSock, &clientInfo, &clientInfoSize);
                    guard clientSock > 0 else {
                        perror("accept");
                        continue;
                    }
                    
                    // register new client socket with kqueue for reading
                    var kEvent = createKernelEvent(withDescriptor: clientSock);
                    guard kevent(self.kq, &kEvent, 1, nil, 0, nil) != -1 else {
                        perror("kevent");
                        close(clientSock);
                        continue;
                    }
                } else if Int32(kEventList[i].filter) == EVFILT_READ {  // read from client
                        var recvBuf = [CChar](repeating: 0, count: 512);
                        let clientDesc = Int32(kEventList[i].ident);
                        var numBytes = 0;
                        numBytes = recv(clientDesc, UnsafeMutableRawPointer(mutating: recvBuf), recvBuf.count, 0);
                        //recvBuf[recvBuf.count-1] = 0;
                        guard numBytes >= 0 else {
                            perror("recv");
                            return;
                        }
                        print("Bytes received: \(numBytes)");
                        
                        // client has closed the request of numbytes is 0
                        if numBytes == 0 {
                            print("no bytes found, closing");
                            close(clientDesc);
                            self.clientsList[clientDesc] = nil;
                            return;
                        }
                    
                        // get client object
                        var client:ClientObject!;
                        if self.clientsList[clientDesc] == nil {
                            client = ClientObject();
                            
                            // add to clients table
                            self.clientsList[clientDesc] = client;
                            
                            client.fd = clientDesc;
                        } else {
                            client = self.clientsList[clientDesc];
                        }

                        // append to raw request string
                        client.rawRequest.append(String.init(cString: &recvBuf));
  
                        /**
                            3 Cases for the Received Request:
                            Case 1: Client object contains request method so header has been processed. Client buffer is part of message body.
                 
                            Case 2: Client object does not contain request method. Client buffer contains "\r\n\r\n" so a full header can be processed 
                                    and the request method can be extracted.
                 
                            Case 3: Client object does not contain request method. Client buffer does not contain "\r\n\r\n" so we only received 
                                    a partial header. Continue to receive data from client until we get this end of header string.
                     
                        */
                        // Case 1
                        if client.requestHeader["METHOD"] != nil {
                            let lines = client.rawRequest.components(separatedBy: "\n");
                            
                            // if full body has been set, schedule a response
                            if self.parseMessageBody(lines, forClient: client) {
                                self.routeRequest(forClient: client);
                            }
                        }
                        // Case 2
                        else if client.rawRequest.range(of: "\r\n\r\n") != nil {
                            // process the request
                            self.parseRequest(forClient: client);
                        }
                        // Case 3
                        else {
                            print("***Received only partial request***");
                        }
                } else if Int32(kEventList[i].flags) == EV_EOF {
                    close(Int32(kEventList[i].ident));
                    print("closed file descriptor \(kEventList[i].ident)");
                } else {
                    print("kernel event not recognized... skipping");
                }
            }
        });
    }
    
//MARK: Methods exposed to user
    /**
        Starts the HTTP server
     */
    func startServer(onPort port:in_port_t) {
        // create timer to poll for respones to send
        let timer1 = Timer(timeInterval: POLL_TIME, target: self, selector: #selector(self.sendResponse), userInfo: nil, repeats: true);
        let timer2 = Timer(timeInterval: POLL_TIME, target: self, selector: #selector(self.serverEventLoop), userInfo: nil, repeats: true);
        RunLoop.current.add(timer1, forMode: RunLoopMode.defaultRunLoopMode)
        RunLoop.current.add(timer2, forMode: RunLoopMode.defaultRunLoopMode)
        
        // create a tcp socket
        self.serverSock = socket(PF_INET, SOCK_STREAM, 0);
        guard self.serverSock > 0 else {
            perror("socket");
            return;
        }
        
        // setup server info
        var sin:sockaddr_in = sockaddr_in();
        sin.sin_family = sa_family_t(AF_INET);
        sin.sin_port = htons(port);
        sin.sin_addr.s_addr = 0;
        
        // set socket options
        var optVal:Int = 1;
        guard setsockopt(self.serverSock, SOL_SOCKET, SO_REUSEADDR, &optVal, UInt32(MemoryLayout<Int>.size)) == 0 else {
            perror("setsockopt");
            return;
        }
        
        // bind socket to local address. must now cast to unsafe pointer and then rebind memory to sockaddr type
        guard (withUnsafePointer(to: &sin) {
            // Temporarily bind the memory at &addr to a single instance of type sockaddr.
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(self.serverSock, $0, socklen_t(MemoryLayout<sockaddr_in>.stride));
            }
        }) >= 0 else {
            perror("bind");
            return;
        }
        
        // listen on the socket
        guard listen(self.serverSock, MAX_CONNECTIONS) == 0 else {
            perror("listen");
            return;
        }
        
        // start event loop for IO multiplexing
        self.kq = kqueue();
        var kEvent = createKernelEvent(withDescriptor: serverSock);
        guard kevent(kq, &kEvent, 1, nil, 0, nil) != -1 else {
            perror("kevent");
            return;
        }
        print("Now listening on port \(port).");

        // since it does not inherit NSApplication, we must manually start the runloop. the runloop will
        // allow the NSTimer to fire continuously and so the client thread can handle requests
        RunLoop.main.run();
    }

    /**
        Adds a callback to handle the specified GET route
     */
    func addGETRoute(_ route:String, callback: @escaping RouteClosure) {
        GETRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified HEAD route
     */
    func addHEADRoute(_ route:String, callback: @escaping RouteClosure) {
        HEADRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified POST route
     */
    func addPOSTRoute(_ route:String, callback: @escaping RouteClosure) {
        POSTRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified PUT route
     */
    func addPUTRoute(_ route:String, callback: @escaping RouteClosure) {
        PUTRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified DELETE route
     */
    func addDELETERoute(_ route:String, callback: @escaping RouteClosure) {
        DELETERoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified TRACE route
     */
    func addTRACERoute(_ route:String, callback: @escaping RouteClosure) {
        TRACERoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified OPTIONS route
     */
    func addOPTIONSRoute(_ route:String, callback: @escaping RouteClosure) {
        OPTIONSRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified CONNECT route
     */
    func addCONNECTRoute(_ route:String, callback: @escaping RouteClosure) {
        CONNECTRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified PATCH route
     */
    func addPATCHRoute(_ route:String, callback: @escaping RouteClosure) {
        PATCHRoutes[route] = callback;
    }
    
    /**
        Adds a callback to handle the specified HOST route
     */
    func addHOSTRoute(_ route:String, callback: @escaping RouteClosure) {
        HOSTRoutes[route] = callback;
    }
    
    /**
        Adds user defined middleware to process and validate the client request
     */
    func addMiddleware(_ middleware:@escaping MiddlewareClosure) {
        middlewareList.append(middleware);
    }
    
    /**
        Adds handlers for HTTP status codes
     */
    func addStatusCodeHandler(_ handler:@escaping StatusCodeClosure, forStatusCode statusCode:String) {
        statusCodeHandler[statusCode] = handler;
    }
    
    /**
        Adds handler for Hosts request header
     */
    func addHostHandler(forHost host:String, callback:@escaping RouteClosure) {
        HOSTRoutes[host] = callback;
    }
    
    /**
        
     */
    func scheduleResponse(_ response:String, to client:ClientObject) {
        self.responseQueue.enqueue(client);
    }
}
