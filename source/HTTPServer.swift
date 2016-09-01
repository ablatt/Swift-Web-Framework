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

//TODO: need signal handlers
class HTTPServer : NSObject {
    // dictionaries containing the routes and callbacks
    private var GETRoutes = Dictionary<String, RouteClosure>();
    private var POSTRoutes = Dictionary<String, RouteClosure>();
    private var statusCodeHandler = Dictionary<String, RouteClosure> ();
    private var middlewareList = Array<MiddlewareClosure>();
    
    // list of connected clients
    private var clients = Dictionary<Int32, ClientObject>();
    
    // queue of connected clients to send responses to
    private var responseQueue = Queue<Int32>();
    
    // queue that contains 
    
    
    // queues to perform units of work
    private var workerThread = dispatch_queue_create("http.worker.thread", DISPATCH_QUEUE_CONCURRENT);       // concurrent queue for processing and work
    private var clientThread = dispatch_queue_create("http.client.thread", DISPATCH_QUEUE_SERIAL);           // serial queue to handle client requests
    private let lockQueue = dispatch_queue_create("httpserver.lock", nil);

//MARK: Initializers
    override init () {
        // register default status code handlers
        statusCodeHandler["100"] = {(request: ClientObject) -> String in
            return "100 - Continue\n";
        };
        statusCodeHandler["101"] = {(request: ClientObject) -> String in
            return "101 - Switching Protocols\n";
        };
        statusCodeHandler["101"] = {(request: ClientObject) -> String in
            return "102 - Processing\n";
        };
        statusCodeHandler["200"] = {(request: ClientObject) -> String in
            return "200 - OK\n";
        };
        statusCodeHandler["201"] = {(request: ClientObject) -> String in
            return "201 - Created\n";
        };
        statusCodeHandler["202"] = {(request: ClientObject) -> String in
            return "202 - Accepted\n";
        };
        statusCodeHandler["203"] = {(request: ClientObject) -> String in
            return "203 - Non-authoritative Information\n";
        };
        statusCodeHandler["204"] = {(request: ClientObject) -> String in
            return "204 - No Content\n";
        };
        statusCodeHandler["205"] = {(request: ClientObject) -> String in
            return "205 - Reset Content\n";
        };
        statusCodeHandler["206"] = {(request: ClientObject) -> String in
            return "206 - Partial Content\n";
        };
        statusCodeHandler["207"] = {(request: ClientObject) -> String in
            return "207 - Multi-Status\n";
        };
        statusCodeHandler["208"] = {(request: ClientObject) -> String in
            return "208 - Already Reported\n";
        };
        statusCodeHandler["226"] = {(request: ClientObject) -> String in
            return "226 - IM Used\n";
        };
        statusCodeHandler["300"] = {(request: ClientObject) -> String in
            return "300 - Multiple Choices\n";
        };
        statusCodeHandler["301"] = {(request: ClientObject) -> String in
            return "301 - Moved Permanently\n";
        };
        statusCodeHandler["302"] = {(request: ClientObject) -> String in
            return "302 - Found\n";
        };
        statusCodeHandler["303"] = {(request: ClientObject) -> String in
            return "303 - See Other\n";
        };
        statusCodeHandler["304"] = {(request: ClientObject) -> String in
            return "304 - Not Modified\n";
        };
        statusCodeHandler["305"] = {(request: ClientObject) -> String in
            return "305 - Use Proxy\n";
        };
        statusCodeHandler["307"] = {(request: ClientObject) -> String in
            return "307 - Temporary Redirect\n";
        };
        statusCodeHandler["308"] = {(request: ClientObject) -> String in
            return "308 - Permanent Redirect\n";
        };
        statusCodeHandler["400"] = {(request: ClientObject) -> String in
            return "400 - Bad Request\n";
        };
        statusCodeHandler["401"] = {(request: ClientObject) -> String in
            return "401 - Unauthorized\n";
        };
        statusCodeHandler["402"] = {(request: ClientObject) -> String in
            return "402 - Payment Required\n";
        };
        statusCodeHandler["403"] = {(request: ClientObject) -> String in
            return "403 - Forbidden\n";
        };
        statusCodeHandler["404"] = {(request: ClientObject) -> String in
            return "404 - Not Found\n";
        };
        statusCodeHandler["405"] = {(request: ClientObject) -> String in
            return "405 - Method Not Allowed\n";
        };
        statusCodeHandler["406"] = {(request: ClientObject) -> String in
            return "406 - Not Acceptable\n";
        };
        statusCodeHandler["407"] = {(request: ClientObject) -> String in
            return "407 - Proxy Authentication Required\n";
        };
        statusCodeHandler["408"] = {(request: ClientObject) -> String in
            return "408 - Request Timeout\n";
        };
        statusCodeHandler["409"] = {(request: ClientObject) -> String in
            return "409 - Conflict\n";
        };
        statusCodeHandler["410"] = {(request: ClientObject) -> String in
            return "410 - Gone\n";
        };
        statusCodeHandler["411"] = {(request: ClientObject) -> String in
            return "411 - Length Required\n";
        };
        statusCodeHandler["412"] = {(request: ClientObject) -> String in
            return "412 - Precondition Failed\n";
        };
        statusCodeHandler["413"] = {(request: ClientObject) -> String in
            return "413 - Payload Too Large\n";
        };
        statusCodeHandler["414"] = {(request: ClientObject) -> String in
            return "414 - Request-URI Too Long\n";
        };
        statusCodeHandler["415"] = {(request: ClientObject) -> String in
            return "415 - Unsupported Media Type\n";
        };
        statusCodeHandler["416"] = {(request: ClientObject) -> String in
            return "416 - Requested Range Not Satisfiable\n";
        };
        statusCodeHandler["417"] = {(request: ClientObject) -> String in
            return "417 - Expectation Failed\n";
        };
        statusCodeHandler["418"] = {(request: ClientObject) -> String in
            return "418 - I'm a teapot\n";
        };
        statusCodeHandler["421"] = {(request: ClientObject) -> String in
            return "421 - Misdirected Request\n";
        };
        statusCodeHandler["422"] = {(request: ClientObject) -> String in
            return "422 - Unprocessable Entity\n";
        };
        statusCodeHandler["423"] = {(request: ClientObject) -> String in
            return "423 - Locked\n";
        };
        statusCodeHandler["424"] = {(request: ClientObject) -> String in
            return "424 - Failed Dependency\n";
        };
        statusCodeHandler["426"] = {(request: ClientObject) -> String in
            return "426 - Upgrade Required\n";
        };
        statusCodeHandler["428"] = {(request: ClientObject) -> String in
            return "428 - Precondition Required\n";
        };
        statusCodeHandler["429"] = {(request: ClientObject) -> String in
            return "429 - Too Many Requests\n";
        };
        statusCodeHandler["431"] = {(request: ClientObject) -> String in
            return "431 - Request Header Fields Too Large\n";
        };
        statusCodeHandler["444"] = {(request: ClientObject) -> String in
            return "444 - Connection Closed Without Response\n";
        };
        statusCodeHandler["451"] = {(request: ClientObject) -> String in
            return "451 - Unavailable For Legal Reasons\n";
        };
        statusCodeHandler["499"] = {(request: ClientObject) -> String in
            return "499 - Client Closed Request\n";
        };
        statusCodeHandler["500"] = {(request: ClientObject) -> String in
            return "500 - Internal Server Error\n";
        };
        statusCodeHandler["501"] = {(request: ClientObject) -> String in
            return "501 - Not Implemented\n";
        };
        statusCodeHandler["502"] = {(request: ClientObject) -> String in
            return "502 - Bad Gateway\n";
        };
        statusCodeHandler["503"] = {(request: ClientObject) -> String in
            return "503 - Service Unavailable\n";
        };
        statusCodeHandler["504"] = {(request: ClientObject) -> String in
            return "504 - Gateway Timeout\n";
        };
        statusCodeHandler["505"] = {(request: ClientObject) -> String in
            return "505 - HTTP Version Not Supported\n";
        };
        statusCodeHandler["506"] = {(request: ClientObject) -> String in
            return "506 - Variant Also Negotiates\n";
        };
        statusCodeHandler["507"] = {(request: ClientObject) -> String in
            return "507 - Insufficient Storage\n";
        };
        statusCodeHandler["508"] = {(request: ClientObject) -> String in
            return "508 - Loop Detected\n";
        };
        statusCodeHandler["510"] = {(request: ClientObject) -> String in
            return "510 - Not Extended\n";
        };
        statusCodeHandler["511"] = {(request: ClientObject) -> String in
            return "511 - Network Authentication Required\n";
        };
        statusCodeHandler["599"] = {(request: ClientObject) -> String in
            return "599 - Network Connect Timeout Error\n";
        };
    }

//MARK: Scheduling methods
    /**
        Schedule error response
     */
    private func scheduleStatusCodeResponse(withStatusCode statusCode:String, forClient clientDescriptor:Int32) {
        guard let client = clients[clientDescriptor] else {
            print("error: client wasn't stored in clients table.");
            return;
        }
        
        guard statusCodeHandler[statusCode] != nil else {
            client.response = "Error in request."
            self.responseQueue.enqueue(clientDescriptor);
            return;
        }
        
        client.response = statusCodeHandler["400"]!(client);
        self.responseQueue.enqueue(clientDescriptor);
    }
    
    /**
        Schedule the response
     */
    private func createResponse(withDescriptor clientDescriptor: Int32) {
        guard let client = clients[clientDescriptor] else {
            print("error: client wasn't stored in clients table.");
            return;
        }
        
        // should always return true since it was processed in validateRequestHeader method
        guard let URI = client.requestHeader["URI"] else {
            print("URI not detected");
            return;
        }
        
        // process each different HTTP method
        switch client.requestHeader["METHOD"]! {
        case "GET":
            guard let callback = GETRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: clientDescriptor);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            dispatch_async(workerThread, {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(clientDescriptor);
            });
        case "POST":
            guard let callback = POSTRoutes[URI] else {
                scheduleStatusCodeResponse(withStatusCode: "404", forClient: clientDescriptor);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            dispatch_async(workerThread, {
                client.response = self.addResponseHeader(callback(client), withStatusCode:"200");
                self.responseQueue.enqueue(clientDescriptor);
            });
        default: break
            //TODO: Add more HTTP method handlers
        }
        
    }
    
//MARK: Request and response processing
    /**
        Create the response header
     */
    func addResponseHeader(response:String, withStatusCode statusCode:String) -> String {
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

        return header + "\r\n" + response + "\r\n";
    }
    
    /**
        Validate HTTP header
     */
    private func validateRequestHeader(client: ClientObject) -> Bool {
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
    private func parseFormData(FromRequest request:[String], startingAtIndex index:Int) -> Dictionary<String, String> {
        var formData = Dictionary<String, String>();
        
        // iterate through all the lines containing form data and extract
        for i in index...(request.count - 1) {
            // different form data is delimited by &
            let postEntries = request[i].componentsSeparatedByString("&");
            for j in 0...(postEntries.count - 1) {
                let formPair = postEntries[j].componentsSeparatedByString("=");
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
    private func processBody(lines:[String], forClient clientDescriptor:Int32) -> Bool {
        guard let client = clients[clientDescriptor] else {
            print("client not found");
            return false;
        }
        
        guard var contentLength = client.requestHeader["Content-Length"] else {
            print("can't fetch content length");
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: clientDescriptor);
            return false;
        }
        
        // strip white space and convert to int
        contentLength = contentLength.stringByReplacingOccurrencesOfString("\r", withString: "");
        contentLength = contentLength.stringByReplacingOccurrencesOfString(" ", withString: "");
        guard let bodySize = Int(contentLength) else {
            print("Content-Length header not found");
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: clientDescriptor);
            return false;
        }
        
        // set body in client object
        for i in (0...lines.count-1) {
            client.bodyLength = client.bodyLength + lines[i].characters.count*sizeof(CChar);
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
    private func processRequest(request: String, onSocket clientDescriptor: Int32) {
        guard let client =  clients[clientDescriptor] else {
            print("not in clients table");
            return;
        }
        
        // create the request dictionary to hold HTTP header key and values
        client.requestHeader = Dictionary<String, String>();
        client.requestHeader["METHOD"] = nil;
        client.requestHeader["URI"] = nil;
        
        // initial line should contain URI & method
        let lines = request.componentsSeparatedByString("\n");
        var tokens = lines[0].componentsSeparatedByString(" ");
        guard tokens.count >= 2 else {
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: clientDescriptor);
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
            tokens = lines[i].componentsSeparatedByString(":");

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
                if processBody(bodyArr, forClient: clientDescriptor) || chunkedEncoding == true {
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
                tokens[1] = tokens[1].stringByReplacingOccurrencesOfString(" ", withString: "");
                tokens[1] = tokens[1].stringByReplacingOccurrencesOfString("\r", withString: "");
                client.requestHeader[tokens[0]] = tokens[1];
            }
        }
        
        // validate request header
        guard validateRequestHeader(client) else {
            print("Invalid request header");
            scheduleStatusCodeResponse(withStatusCode: "400", forClient: clientDescriptor);
            return;
        }
        
        // schedule request processing and response
        if sendFlag == true {
            createResponse(withDescriptor: clientDescriptor);
        }
    }
    
//MARK: Event loop functions
    /**
        Timed function that attempts to send responses dispatched in a serial queue
     */
    @objc private func sendResponse(timer:NSTimer!) {
        while self.responseQueue.empty() == false {
            guard let fd = self.responseQueue.dequeue() else {
                print("response not set for client");
                continue;
            }
            
            guard let client = clients[fd] else {
                print("failed to get client from client list");
                continue;
            }
            
            guard let response = client.response else {
                print("failed to get response for client \(fd)");
                continue;
            }
        
            // send response in dedicated send thread
            dispatch_sync(lockQueue, {
                let buff = response.cStringUsingEncoding(NSUTF8StringEncoding)!;
                let numBytes = buff.count;
                var bytesSent = 0;
                while bytesSent != numBytes {
                    let res = send(fd, buff, response.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), MSG_OOB);
                    guard res >= 0 else {
                        print("failed to send response")
                        return;
                    }
                    bytesSent += numBytes;
                    fsync(fd);
                }
                print("Bytes sent: \(bytesSent) / \(numBytes)");
                
                // if connection type is keep-alive, don't close the connection
                guard let keepAlive = self.clients[fd]?.requestHeader["Connection"] where
                        keepAlive == "keep-alive" else {
                    print("keep-alive is not detected");
                    close(fd);
                    self.clients[fd] = nil;
                    return;
                }
            });
        }
    }
    
    private func startSeverEventLoop(onServerSock serverSock:Int32) {
        // get descriptor to kernel queue
        let kq = kqueue();
        
        // set kernel to listen to socket events
        var kEvent = createKernelEvent(withDescriptor: serverSock);
        guard kevent(kq, &kEvent, 1, nil, 0, nil) != -1 else {
            perror("kevent");
            return;
        }
        
        // create timeout to get a kevent (in nanoseconds)
        var kTimeOut = timespec();
        kTimeOut.tv_nsec = KQUEUE_TIMEOUT;
        
        // create array to store returned kevents
        var kEventList = Array(count: KQUEUE_MAX_EVENTS, repeatedValue:kevent());
        
        // table to temporarily hold incoming requests
        var partialReqTable = Dictionary<Int32, String>();
        
        // begin accepting and receiving clients
        dispatch_async(clientThread, {
            repeat {
                // lock critical section of reading and converting buff to string
                dispatch_sync(self.lockQueue, {
                // get kernel events
                let numEvents = kevent(kq, nil, 0, &kEventList, Int32(KQUEUE_MAX_EVENTS), &kTimeOut);
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
                    if kEventList[i].ident == UInt(serverSock) {
                        // accept incoming connection
                        var clientSock:Int32 = -1;
                        var clientInfo = sockaddr();
                        var clientInfoSize = socklen_t(sizeof(sockaddr));
                        clientSock = accept(serverSock, &clientInfo, &clientInfoSize);
                        guard clientSock > 0 else {
                            perror("accept");
                            continue;
                        }
                        
                        // register new client socket with kqueue for reading
                        kEvent = createKernelEvent(withDescriptor: clientSock);
                        guard kevent(kq, &kEvent, 1, nil, 0, nil) != -1 else {
                            perror("kevent");
                            close(clientSock);
                            continue;
                        }
                    } else if Int32(kEventList[i].filter) == EVFILT_READ {  // read from client
                            let recvBuf = [UInt8](count: 512, repeatedValue: 0);
                            let clientDesc = Int32(kEventList[i].ident);
                            var numBytes = 0;
                            numBytes = recv(clientDesc, UnsafeMutablePointer<Void>(recvBuf), recvBuf.count, 0);
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
                                self.clients[clientDesc] = nil;
                                return;
                            }
                            
                            // get client object
                            var client:ClientObject!;
                            if self.clients[clientDesc] == nil {
                                client = ClientObject();
                                
                                // add to clients table
                                self.clients[clientDesc] = client;
                            } else {
                                client = self.clients[clientDesc];
                            }
                            


                            // convert from c-string to String type the
                            guard let request = String.fromCStringRepairingIllFormedUTF8(UnsafeMutablePointer<CChar>(recvBuf)).0 else {
                                print("failed to convert request to String");
                                self.scheduleStatusCodeResponse(withStatusCode: "400", forClient: clientDesc);
                                return;
                            }
                            
                            //TODO: DO we need to remove from kqueue? kevent keeps returning
                            // add to temporary request table
                            if partialReqTable[clientDesc] != nil {
                                partialReqTable[clientDesc]!.appendContentsOf(request);
                            } else {
                                partialReqTable[clientDesc] = request;
                            }
                        
                            // if in clients table, the header has already been processed and this recv returns a message body
                            if self.clients[clientDesc] != nil && self.clients[clientDesc]!.requestHeader["METHOD"] == "POST" {
                                let lines = request.componentsSeparatedByString("\n");
                                
                                // if full body has been set, schedule a response
                                if self.processBody(lines, forClient: clientDesc) {
                                    self.createResponse(withDescriptor: clientDesc);
                                }
                                
                                partialReqTable[clientDesc] = nil;
                            } else if partialReqTable[clientDesc]!.rangeOfString("\r\n\r\n") != nil { // end of header is signaled by "\r\n\r\n"
                                // process the request
                                self.processRequest(partialReqTable[clientDesc]!, onSocket: clientDesc);
                                
                                // remove request from temp table
                                partialReqTable[clientDesc] = nil;
                            } else {
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
            } while true;
        });

    }
    
//MARK: Methods exposed to user
    /**
        Starts the HTTP server
     */
    func startServer(onPort port:in_port_t) {
        // create timer to poll for respones to send
        let timer = NSTimer(timeInterval: 0.0005, target: self, selector: #selector(self.sendResponse), userInfo: nil, repeats: true);
        NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
        
        // create a tcp socket
        let serverSock:Int32 = socket(PF_INET, SOCK_STREAM, 0);
        guard serverSock > 0 else {
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
        guard setsockopt(serverSock, SOL_SOCKET, SO_REUSEADDR, &optVal, UInt32(sizeof(Int))) == 0 else {
            perror("setsockopt");
            return;
        }
        
        // bind socket to local address
        guard bind(serverSock, sockCast(&sin), socklen_t(sizeof(sockaddr_in))) >= 0 else {
            perror("bind");
            return;
        }
        
        // listen on the socket
        guard listen(serverSock, MAX_CONNECTIONS) == 0 else {
            perror("listen");
            return;
        }
        print("Now listening on port \(port).");
        
        // start event loop for IO multiplexing
        startSeverEventLoop(onServerSock: serverSock);
        
        // since it does not inherit NSApplication, we must manually start the runloop. the runloop will
        // allow the NSTimer to fire continuously and so the client thread can handle requests
        NSRunLoop.mainRunLoop().run();
    }

    /**
        Adds a HTTP 'GET' route and a function closure to handle a request that matches this route.
     */
    func addGETRoute(route:String, callback: RouteClosure) {
        GETRoutes[route] = callback;
    }
    
    /**
        Adds a HTTP 'POST' route and a function closure to handle a request that matches this route.
     */
    func addPOSTRoute(route:String, callback: RouteClosure) {
        POSTRoutes[route] = callback;
    }
    
    /**
        Adds user defined middleware to process and validate the client request.
     */
    func addMiddleware(middleware:MiddlewareClosure) {
        middlewareList.append(middleware);
    }
}
