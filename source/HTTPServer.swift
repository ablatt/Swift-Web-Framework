    //
//  HTTPServer.swift
//  SwiftWebFramework
//
//  Created by user on 8/21/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation
import Darwin

// globals
internal let MAX_CONNECTIONS:Int32 = 1000
internal let KQUEUE_TIMEOUT:Int = 100000;
internal let KQUEUE_MAX_EVENTS = 32;
internal let POLL_TIME = 0.00005;
internal let DEFAULT_HOST_NAME = "localhost";
internal typealias URIDictionary = Dictionary<String, RouteClosure>;
    
open class HTTPServer : NSObject {
    // router to route URIs to callbacks
    internal let router = Router();
    
    // scheduler to create the response and send it
    internal let scheduler = Scheduler();
    
    // dispatcher to create the response
    internal let dispatcher = Dispatcher();
    
    // other callbacks
    internal var middlewareList = Dictionary<String, Array<MiddlewareClosure>>();
    
    // queues to perform units of work
    fileprivate var workerThread = DispatchQueue(label: "http.worker.thread", attributes: DispatchQueue.Attributes.concurrent);       // concurrent queue for processing and work
    fileprivate var clientThread = DispatchQueue(label: "http.client.thread", attributes: []);           // serial queue to handle client requests
    fileprivate let lockQueue = DispatchQueue(label: "httpserver.lock", attributes: []);

    // list of connected clients
    fileprivate var tempRequestList = Dictionary<Int32, ClientObject>();
    fileprivate var connectedClients = NSMutableSet();
    
    // socket variables
    fileprivate var kq:Int32 = -1;                      // kernel queue descriptor
    fileprivate var serverSock:Int32 = 0;               // server socket
    
//MARK: Processing of the fully generated parsed request
    fileprivate func processRequest(forClient client:ClientObject) {
        // remove from temp request list since request was fully received
        // only remove from request list if the chunked encoding processing is complete
      //  if client.usesChunkedEncoding == false {
       //     tempRequestList[client.fd] = nil;
       // } else {
            client.rawRequest.removeAll();
        //}

        // generate response asynchronously
        workerThread.async(execute: {
            guard let callback = self.router.getRouteForClient(client) else {
                self.dispatcher.createStatusCodeResponse(withStatusCode: "404", forClient: client, withRouter: self.router);
                self.scheduleResponse(forClient: client);
                return;
            }
            self.dispatcher.createResponseForClient(client, withCallback: callback);
            self.scheduler.scheduleResponse(forClient: client);
        });
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
        
        // HTTP 1.1 requires HOST header in request
        if client.requestHeader["VERSION"] == "HTTP/1.1" {
            guard client.requestHeader["Host"] != nil else {
                dispatcher.createStatusCodeResponse(withStatusCode: "400", forClient: client, withRouter: router);
                scheduler.scheduleResponse(forClient: client);
                return false;
            }
        }

        var host:String! = client.requestHeader["Host"];
        if host == nil {
            host = DEFAULT_HOST_NAME;
        }
        
        // if no middleware is defined, just return true
        guard middlewareList[host] != nil else {
            return true;
        }
        
        // pass request to user defined closures
        for middleware in middlewareList[host]! {
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
        var contentLength = client.requestHeader["Content-Length"];
        let chunkedEncoding = client.requestHeader["Transfer-Encoding"];
        
        // TODO: Add more cases to consider for different URIs
        if contentLength == nil && chunkedEncoding == nil {
            // POST requests need to have a Content-Length or be chunked-encoded
            if client.requestHeader["METHOD"] == "POST" {
                print("content-length not found nor chunked-encoding. cannot proceed parsing message body");
                return false;
            } else if client.requestHeader["METHOD"] == "GET" {
                return true;
            }
        }
        
        // extract message body with content-length header specified
        if contentLength != nil {
            // strip white space and convert to int
            contentLength = contentLength!.replacingOccurrences(of: " ", with: "");
            guard let bodySize = Int(contentLength!) else {
                print("Content-Length header not found");
                dispatcher.createStatusCodeResponse(withStatusCode: "400", forClient: client, withRouter: router);
                scheduler.scheduleResponse(forClient: client);
                return false;
            }
                        
            // extract message body
            for i in (0...lines.count-1) {
                if lines[i] == "" {
                    continue;
                }
                client.currentBodyLength += lines[i].characters.count;
                if client.requestBody == nil {
                    client.requestBody = [String]();
                }
                client.requestBody!.append(lines[i]);
            }
            
            print("Expected: \(bodySize)");
            print("Curr: \(client.currentBodyLength)");
            
            // check if full body message was received
            if client.currentBodyLength == bodySize {
                return true;
            } else {
                return false;
            }
        }
        // chunked-encoding
        else {
            var footerIndex = 0;
            //print("Count: \(lines.count)");
            for i in (0...lines.count-1) {
                if lines[i] == "" {
                    continue;
                }
                
                var tokens = lines[i].components(separatedBy: ";");
                
                guard tokens.count > 0 else {
                    print("failed to get chunk size");
                    return false;
                }
                
                var chunkSize:Int!;
                
                // check if last chunk received was chunk size or not
                if client.expectedChunkSize < 0 {
                    chunkSize = hexToInt(withHexString:&tokens[0]);
                    guard chunkSize != nil else {
                        print("failed to convert hex chunk size to int");
                        return false;
                    }
                    
                    // if this is the last line, store the chunk size for next chunks received
                    client.expectedChunkSize = chunkSize;
                } else {
                    chunkSize = client.expectedChunkSize;
                    
                    // no more chunks but there are possible footers
                    if chunkSize != 0 {
                        // next line contains request body
                        if client.requestBody == nil {
                            client.requestBody = [String]();
                        }
                        
                        client.requestBody!.append(lines[i]);
                        client.currChunkSize += lines[i].characters.count;
                        
                        // check if we can get next chunk size
                        if client.currChunkSize == client.expectedChunkSize {
                            client.expectedChunkSize = -1;
                            client.currChunkSize = 0;
                        }
                    } else {
                        footerIndex = i + 1;
                        break;
                    }
                }
            }
            
            // extract foot
            while footerIndex < lines.count {
                // end of chunked data section
                if lines[footerIndex] == "" {
                    break;
                }
                
                let footerTokens =  lines[footerIndex].components(separatedBy: ":");
                if footerTokens.count < 2 {
                    footerIndex += 1;
                    continue;
                }
                if client.chunkedFooter == nil {
                    client.chunkedFooter = Dictionary<String, String>();
                }
                client.chunkedFooter![footerTokens[0]] = footerTokens[1];
                footerIndex += 1;
            }
            
            return true;
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
        let lines = client.rawRequest.components(separatedBy: "\r\n");
        var tokens = lines[0].components(separatedBy: " ");
        
        guard tokens.count >= 2 else {
            print("Initial request line is invalid");
            dispatcher.createStatusCodeResponse(withStatusCode: "400", forClient: client, withRouter:router);
            scheduler.scheduleResponse(forClient: client);
            return;
        }
        
        // set URI and HTTP methods parsed from request
        client.requestHeader["METHOD"] = tokens[0].removingPercentEncoding!.replacingOccurrences(of: " ", with: "");
        client.requestHeader["URI"] = tokens[1].removingPercentEncoding!.replacingOccurrences(of: " ", with: "");
        client.requestHeader["VERSION"] = tokens[2].removingPercentEncoding!.replacingOccurrences(of: " ", with: "");
                
        // flag indicating if complete request was received
        var processRequestFlag = true;
        
        // process the other HTTP header entries
        for i in 1...(lines.count - 1) {
            // full request header received. two empty separates header from body
            if lines[i] == "" {
                let bodyArr = Array(lines[(i+1)...(lines.count-1)]);
                
                // check if client is using chunked encoding
                if client.requestHeader["Transfer-Encoding"] != nil &&
                    client.requestHeader["Transfer-Encoding"] == "chunked" {
                    client.usesChunkedEncoding = true;
                }
                
                //TODO: Refactor this section
                // get request body if it exists. returns true if full body was received
                if parseMessageBody(bodyArr, forClient: client) {
                    if client.requestHeader["METHOD"] == "POST" {
                        client.formData = parseFormData(FromRequest: lines, startingAtIndex: i+1);
                    }
                    
                    // TODO: More processing of message body for different methods
                }
                // can only have partial message body if there is chunked encoding
                else if client.usesChunkedEncoding == false {
                    processRequestFlag = false;
                }
                
                // empty line is last thing after a header so just break
                break;
            } else {
                // header is in key:val format
                tokens = lines[i].components(separatedBy: ":");

                // header data has to be in key:value pair
                guard tokens.count >= 2 else {
                    client.requestHeader[tokens[0]] = "";
                    continue;
                }
                
                // strip white space from tokens
                tokens[0] = tokens[0].replacingOccurrences(of: " ", with: "");
                tokens[1] = tokens[1].replacingOccurrences(of: " ", with: "");

                client.requestHeader[tokens[0]] = tokens[1];
            }
        }
        
        // validate request header
        guard validateRequestHeader(client) else {
            print("Invalid request header");
            dispatcher.createStatusCodeResponse(withStatusCode: "400", forClient: client, withRouter: router);
            scheduler.scheduleResponse(forClient: client);
            return;
        }
        
        // if HTTP 1.1, send 100 response for valid request header
        if client.requestHeader["VERSION"] == "HTTP/1.1" &&
            client.requestHeader["Expect"] == "100-continue" {
            let responseClient = ClientObject();
            responseClient.fd = client.fd;
            responseClient.response = dispatcher.addResponseHeader(forResponse: "", withStatusCode: "100");
            scheduler.scheduleResponse(forClient: responseClient);
        }
        
        // schedule request processing and response
        if processRequestFlag == true {
            processRequest(forClient: client);
        }
    }
    
//MARK: Event loop functions
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
                if kEventList[i].ident == UInt(self.serverSock) {   // client attempting to connect
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
                    
                    // add to connected clients set
                    connectedClients.add(clientSock);
                } else if Int32(kEventList[i].filter) == EVFILT_READ {  // client sending data
                        let recvBuf = [UInt8](repeating: 0, count: 2048);
                        let clientDesc = Int32(kEventList[i].ident);
                        var numBytes = 0;
                    
                        // buffer size is count-1 since last element has to be null terminated
                        numBytes = recv(clientDesc, UnsafeMutableRawPointer(mutating: recvBuf), recvBuf.count-1, 0);
                        guard numBytes >= 0 else {
                            perror("recv");
                            close(clientDesc);
                            tempRequestList[clientDesc] = nil;
                            connectedClients.remove(clientDesc);
                            return;
                        }
                        print("Bytes received: \(numBytes)");
                        
                        // client has closed the request if numbytes is 0
                        if numBytes == 0 {
                            print("no bytes found, closing");
                            close(clientDesc);
                            tempRequestList[clientDesc] = nil;
                            connectedClients.remove(clientDesc);
                            return;
                        }
                    
                        // get client object from client list
                        var client:ClientObject!;
                        if self.tempRequestList[clientDesc] == nil {
                            client = ClientObject();
                            
                            // add to clients list
                            self.tempRequestList[clientDesc] = client;
                            
                            client.fd = clientDesc;
                        } else {
                            client = self.tempRequestList[clientDesc];
                        }

                        // append to raw request string
                        client.rawRequest.append(String.init(cString: recvBuf));
                    
                        /**
                            3 Cases for the Received Request:
                            Case 1: Client object has full request header. Client buffer is part of message body.
                 
                            Case 2: Client object does not have full request header. Client buffer contains "\r\n\r\n" so a full header 
                                    can be processed and the request method can be extracted.
                 
                            Case 3: Client object does not contain request method. Client buffer does not contain "\r\n\r\n" so we only received 
                                    a partial header. Continue to receive data from client until we get this end of header string.
                     
                        */
                        // Case 1
                        if client.hasCompleteHeader {
                            let lines = client.rawRequest.components(separatedBy: "\r\n");
                            
                            // if full body has been set, process the request
                            if parseMessageBody(lines, forClient: client) {
                                
                                // already routed if chunked-encoding in parseRequest
                                if client.usesChunkedEncoding == false {
                                    processRequest(forClient: client);
                                }
                            }
                            
                            // clear receive buffer
                            client.rawRequest.removeAll();
                        }
                        // Case 2
                        else if client.rawRequest.range(of: "\r\n\r\n") != nil {
                            client.hasCompleteHeader = true;
                            
                            // process the request
                            self.parseRequest(forClient: client);
                            
                            // clear receive buffer
                            client.rawRequest.removeAll();
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
        let timer1 = Timer(timeInterval: POLL_TIME, target: scheduler, selector: #selector(scheduler.sendResponse), userInfo: connectedClients, repeats: true);
        let timer2 = Timer(timeInterval: POLL_TIME, target: self, selector: #selector(self.serverEventLoop), userInfo: nil, repeats: true);
        RunLoop.current.add(timer1, forMode: RunLoopMode.defaultRunLoopMode)
        RunLoop.current.add(timer2, forMode: RunLoopMode.defaultRunLoopMode)
        
        // create a tcp socket
        serverSock = socket(PF_INET, SOCK_STREAM, 0);
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
        guard setsockopt(self.serverSock, SOL_SOCKET, SO_REUSEADDR, &optVal, UInt32(MemoryLayout<Int>.size)) == 0 else {
            perror("setsockopt");
            return;
        }
        
        // bind socket to local address. cast sockaddr_in to unsafe ptr, and then map ptr memory to sockaddr type
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
        guard listen(serverSock, MAX_CONNECTIONS) == 0 else {
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
}
