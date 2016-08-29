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
    private var middlewareList = Array<MiddlewareClosure>();
    
    // list of connected clients
    private var clients = Dictionary<Int32, ClientObject>();
    
    // table to temporarily hold incoming requests
    private var tempReqTable = Dictionary<Int32, String>();
    
    // queue of clients to send responses to
    private var responseQueue = Queue<Int32>();
    
    // queues to perform units of work
    private var workerThread = dispatch_queue_create("http.worker.thread", DISPATCH_QUEUE_CONCURRENT);       // concurrent queue for processing and work
    private var clientThread = dispatch_queue_create("http.client.thread", DISPATCH_QUEUE_SERIAL);           // serial queue to handle client requests
    private var sendThread = dispatch_queue_create("http.response.thread", DISPATCH_QUEUE_CONCURRENT);       // serial queue to send response to clients

//MARK: Request and response processing
    /**
        Validate HTTP header
     */
    private func validateRequestHeader(client: ClientObject) -> Bool {
        // validate HTTP method
        guard client.requestHeader["METHOD"] != nil else {
            print("invalid method");
            return false;
        }
        
        // validate HTTP URI
        guard client.requestHeader["URI"] != nil else {
            print("invalid URI");
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
        Schedule the response
     */
    private func scheduleResponse(withDescriptor clientDescriptor: Int32) {
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
                print("URI " + URI + " not found");
                client.response = "<html> 404 </html>\n";
                self.responseQueue.enqueue(clientDescriptor);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            dispatch_async(workerThread, {
                client.response = callback(client);
                self.responseQueue.enqueue(clientDescriptor);
                //self.sendResponse(nil);
            });
        case "POST":
            guard let callback = POSTRoutes[URI] else {
                print("URI " + URI + " not found");
                client.response = "<html> 404 </html>";
                self.responseQueue.enqueue(clientDescriptor);
                return;
            }
            
            // generate response asynchronously on worker queue and queue the response on scheduler queue
            dispatch_async(workerThread, {
                client.response = callback(client);
                self.responseQueue.enqueue(clientDescriptor);
            });
        default: break
           //TODO: Add more HTTP method handlers
        }

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
        Process request header from client
     */
    private func processRequest(request: String, onSocket clientDescriptor: Int32) {
        let client = ClientObject();

        // create the request dictionary to hold HTTP header key and values
        var header = Dictionary<String, String>();
        header["METHOD"] = nil;
        header["URI"] = nil;
        
        // initial line should contain URI & method
        let lines = request.componentsSeparatedByString("\n");
        var tokens = lines[0].componentsSeparatedByString(" ");
        guard tokens.count >= 2 else {
            // send 400 response invalid HTTP header
            return;
        }
        
        // set URI and HTTP methods parsed from request
        header["METHOD"] = tokens[0];
        header["URI"] = tokens[1];
        
        // process the other HTTP header entries
        for i in 1...(lines.count - 1) {
            // header is in key:val format
            tokens = lines[i].componentsSeparatedByString(":");

            // POST request contains message body after a new line
            if header["METHOD"] == "POST" && lines[i].lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 1 {
                client.formData = parseFormData(FromRequest: lines, startingAtIndex: i+1);
                
                // POST data should be last thing in header so break
                break;
            }
            
            // header data has to be in key:value pair
            guard tokens.count >= 2 else {
                header[tokens[0]] = "";
                // send 404
                //close(clientDescriptor);
                continue;
            }
            
            header[tokens[0]] = tokens[1];
        }
        
        // set the request headers for the request object
        client.requestHeader = header;
        
        // validate request header
        guard validateRequestHeader(client) else {
            print("Invalid request header");
            // send 404
            return;
        }
        
        // valid HTTP header, add to client table
        clients[clientDescriptor] = client;
        
        // schedule request processing and response
        scheduleResponse(withDescriptor: clientDescriptor);
    }
    
//MARK: Event loop functions
    /**
        Timed function that attempts to send responses dispatched in a serial queue
     */
    func sendResponse(timer:NSTimer!) {
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
            dispatch_async(sendThread, {
                guard send(fd, response.cStringUsingEncoding(NSUTF8StringEncoding)!, response.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), 0) > 0 else {
                    print("failed to send response")
                    return;
                }
                
                // if connection type is keep-alive, don't close the connection
                close(fd);
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
        
        // begin accepting and receiving clients
        dispatch_async(clientThread, {
            repeat {
                // get kernel events
                let numEvents = kevent(kq, nil, 0, &kEventList, Int32(KQUEUE_MAX_EVENTS), &kTimeOut);
                guard numEvents != -1 else {
                    perror("kevent");
                    continue;
                }
                
                if numEvents == 0 {
                    continue;
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
                        // TODO: Must handle cases where not all packets of header are received in one go
                        let recvBuf = [UInt8](count: 512, repeatedValue: 0);
                        let clientDesc = Int32(kEventList[i].ident);
                        var numBytes = 0;
                        numBytes = recv(clientDesc, UnsafeMutablePointer<Void>(recvBuf), recvBuf.count, 0);
                        guard numBytes >= 0 else {
                            perror("recv");
                            continue;
                        }
                        
                        // convert from c-string to String type the
                        guard let request =  String.fromCString(UnsafeMutablePointer<CChar>(recvBuf))
                            else {
                                print("failed to convert request to String");
                                return;
                        }
                        
                        // add to temporary request table
                        if self.tempReqTable[clientDesc] != nil {
                            self.tempReqTable[clientDesc]!.appendContentsOf(request);
                        } else {
                            self.tempReqTable[clientDesc] = request;
                        }
                        
                        // check if received request contains '\r\n' for end of header
                        if self.tempReqTable[clientDesc]!.rangeOfString("\r\n\r\n") != nil {
                            let range = self.tempReqTable[clientDesc]!.rangeOfString("\r\n\r\n");
                            
                            //TODO: If POST request, should check if chunked-encoding or content-length is specified

                            // process the request
                            self.processRequest(self.tempReqTable[clientDesc]!, onSocket: clientDesc);
                            
                            // remove request from temp table
                            self.tempReqTable[clientDesc] = nil;
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
