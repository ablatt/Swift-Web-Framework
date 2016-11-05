    //
//  HTTPServer.swift
//  SwiftWebFramework
//
//  Created by user on 8/21/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation
#if os(Linux)
import Glibc
import Dispatch
import CoreFoundation
import epoll
#else
import Darwin
#endif


// kqueue globals
internal let KQUEUE_TIMEOUT:Int = 100000;
internal let KQUEUE_MAX_EVENTS = 32;
    
// epoll globals
internal let EPOLL_TIMEOUT:Int32 = 0;
internal let EPOLL_MAX_EVENTS:Int32 = 32;

// other globals
internal let MAX_CONNECTIONS:Int32 = 1000
internal let POLL_TIME = 0.00005;
internal let DEFAULT_HOST_NAME = "localhost";
internal typealias URIDictionary = Dictionary<String, RouteClosure>;
    
open class HTTPServer : NSObject {
//MARK: Class variables
    // router to route URIs to callbacks
    internal let router = Router();
    
    // scheduler to create the response and send it
    internal let scheduler:Scheduler!;
    
    // dispatcher to create the response
    internal let dispatcher = Dispatcher();
    
    // request parser
    internal let requestParser = Parser();
    
    // other callbacks
    internal var middlewareList = Dictionary<String, Array<MiddlewareClosure>>();
    
    // queues to perform units of work
    fileprivate var workerThread = DispatchQueue(label: "http.worker.thread", attributes: DispatchQueue.Attributes.concurrent);       // concurrent queue for processing and work
    fileprivate let lockQueue = DispatchQueue(label: "httpserver.lock", attributes: []);
    
    // list of connected clients
    fileprivate var partialRequestList = Dictionary<Int32, ClientObject>();
    fileprivate var connectedClients = NSMutableSet()

    // socket variables
    #if os(Linux)
    fileprivate var ev:Int32 = -1;
    #else
    fileprivate var kq:Int32 = -1;                      // kernel queue descriptor
    #endif
    fileprivate var serverSock:Int32 = 0;               // server socket
    
    override init () {
        scheduler = Scheduler(clients: connectedClients);
    }
    
//MARK: Processing of the fully generated parsed request
    fileprivate func processCompleteRequest(forClient client:ClientObject) {
        // request fully received, remove from partial request list to receive next request for HTTP pipelining
        partialRequestList[client.fd] = nil;
        guard let callback = self.router.getRouteForClient(client) else {
            self.dispatcher.createStatusCodeResponse(withStatusCode: "404", forClient: client, withRouter: self.router);
            self.scheduleResponse(forClient: client);
            return;
        }
        self.dispatcher.createResponseForClient(client, withCallback: callback);
        self.scheduler.scheduleResponse(forClient: client);
    }
    
//MARK: Parsing and validation
    /**
        Validate HTTP header
     */
    fileprivate func validateRequestHeader(forClient client: ClientObject) -> Bool {
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
        
        // request must have a host per HTTP/1.1
        var host:String! = client.requestHeader["Host"];
        if host == nil {
            host = DEFAULT_HOST_NAME;
        }
        
        // pass request to user defined middleware
        if middlewareList[host] != nil  {
            for middleware in middlewareList[host]! {
                if middleware(client) == false {
                    return false;
                }
            }
        }
        
        // if HTTP 1.1, send 100 response for valid request header
        if client.requestHeader["VERSION"] == "HTTP/1.1" &&
            client.requestHeader["Expect"] == "100-continue" {
            let responseClient = ClientObject();
            responseClient.fd = client.fd;
            responseClient.response = dispatcher.addResponseHeader(forResponse: "", withStatusCode: "100");
            scheduler.scheduleResponse(forClient: responseClient);
        }
     
        // validation ok
        return true;
    }
    
  //MARK: Helpers for event network event loop
    /**
        Accept client
     */
    func acceptClient() -> Int32 {
        // accept incoming connection
        var clientFd:Int32 = -1;
        var clientInfo = sockaddr();
        var clientInfoSize = socklen_t(MemoryLayout<sockaddr>.size);
        clientFd = accept(self.serverSock, &clientInfo, &clientInfoSize);
        guard clientFd > 0 else {
            perror("accept");
            return -1;
        }
        
        return clientFd;
    }

    /**
        Function to read from client
     */
    func readFromClient(withFileDescriptor clientDesc:Int32) {
        var recvBuf = [CChar](repeating: 0, count: 10000);
        var numBytes = 0;
        
        // buffer size is count-1 since last element has to be null terminated if buffer is filled
        numBytes = recv(clientDesc, UnsafeMutableRawPointer(mutating: recvBuf), recvBuf.count-1, 0);
        guard numBytes >= 0 else {
            perror("recv");
            close(clientDesc);
            connectedClients.remove(clientDesc);
            partialRequestList[clientDesc] = nil;
            return;
        }

        // set last byte to null
        recvBuf[numBytes] = 0;
        print("Bytes received: \(numBytes)");
        
        // client has closed the request if numbytes is 0
        if numBytes == 0 {
            print("recv returned 0, closing socket \(clientDesc)");
            close(clientDesc);
            connectedClients.remove(clientDesc);
            partialRequestList[clientDesc] = nil;
            return;
        }
        
        // get client object from client list
        var client:ClientObject!;
        if self.partialRequestList[clientDesc] == nil {
            client = ClientObject();
            
            // add to clients list
            self.partialRequestList[clientDesc] = client;
            
            client.fd = clientDesc;
        } else {
            client = self.partialRequestList[clientDesc];
        }
        
        client.rawRequest.append(Data(bytes: recvBuf, count: numBytes));

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
            // if full body has been parsed, process the request
            if requestParser.parseMessageBody(forClient: client, withBuffer: client.rawRequest) {
                // begin processing the request
                processCompleteRequest(forClient: client);
            }
            
            // clear receive buffer
            client.rawRequest.removeAll();
        }
        // Case 2
        else if let crlfRange = client.rawRequest.range(of: headerDelimiter) {
            // get request header data
            let headerRange = Range<Int> (0...(crlfRange.lowerBound-1));
            let headerData = client.rawRequest.subdata(in: headerRange);
            guard let rawHeaderString = String(data:headerData, encoding:.utf8) else {
                assert(false, "Failed in converting request header (type Data) to String!");
            }
            
            // request body data
            let requestSize = client.rawRequest.count;
            var bodyData:Data? = nil;
            if crlfRange.upperBound < (requestSize - 1) {
                let bodyRange = Range<Int> (crlfRange.upperBound...(requestSize - 1));
                bodyData = client.rawRequest.subdata(in: bodyRange);
            }
            
            // attempt to parse and validate request header
            if requestParser.parseHeader(forClient: client, withRequest: rawHeaderString) &&
                validateRequestHeader(forClient: client) {
          
                client.hasCompleteHeader = true;

                // try to parse the request message body if it exists
                if requestParser.parseMessageBody(forClient: client, withBuffer: bodyData) {
                    processCompleteRequest(forClient: client);
                }
 
            } else {
                print("Invalid request header");
                dispatcher.createStatusCodeResponse(withStatusCode: "400", forClient: client, withRouter: router);
                scheduler.scheduleResponse(forClient: client);
            }
            
            // clear receive buffer since the received data has just been processed
            client.rawRequest.removeAll();
        }
        // Case 3
        else {
            print("***Received only partial request***");
        }
    }

    
//MARK: Event loop functions
#if !os(Linux)
    /**
     
     Event loop for FreeBSD (macOS)
     
     */
    @objc fileprivate func bsdEventLoop() {
        // create array to store returned kevents
        var kEventList = Array(repeating: kevent(), count: KQUEUE_MAX_EVENTS);
        
        // create timeout to get a kevent (in nanoseconds)
        var kTimeOut = timespec();
        kTimeOut.tv_nsec = KQUEUE_TIMEOUT;

        // lock critical section of reading and converting buff to string
        lockQueue.sync(execute: {
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
                // client attempting to connect
                if kEventList[i].ident == UInt(serverSock) {
                    let clientFd = acceptClient();
                    
                    // register new client socket with kqueue for reading events
                    var kEvent = createKernelEvent(withDescriptor: clientFd);
                    guard kevent(self.kq, &kEvent, 1, nil, 0, nil) != -1 else {
                        perror("kevent");
                        close(clientFd);
                        return;
                    }
                    
                    // add to connected clients set
                    connectedClients.add(clientFd);
                }
                // client sending data
                else if Int32(kEventList[i].filter) == EVFILT_READ {
                    let clientDesc = Int32(kEventList[i].ident);
                    readFromClient(withFileDescriptor: clientDesc);
                }
                // client closing connection
                else if Int32(kEventList[i].flags) == EV_EOF {
                    let clientDesc = Int32(kEventList[i].ident);
                    close(clientDesc);
                    connectedClients.remove(clientDesc);
                    print("closed file descriptor \(kEventList[i].ident)");
                }
                // default fall through
                else {
                    print("kernel event not recognized... skipping");
                }
            }
        });
    }
#else
    /**
        Event loop for Linux
     */
    fileprivate func linuxEventLoop() {
        // wait for I/O events
        var eEventList = Array(repeating: epoll_event(), count: Int(EPOLL_MAX_EVENTS));
    
        lockQueue.sync(execute: {
            // get I/O events
            let nfds = epoll_wait(ev, &eEventList, EPOLL_MAX_EVENTS, EPOLL_TIMEOUT);
            guard nfds >= 0 else {
                perror("epoll_wait");
                return;
            }
    
            if nfds == 0 {
                return;
            }
    
            print("epoll received IO events");
            // iterate through all the events
            for i in 0...Int(nfds-1) {
                let eEvent = eEventList[i];
    
                // client attempting to connect
                if eEvent.data.fd == self.serverSock {
                    print("epoll client accept");
                    let clientFd = acceptClient();
    
                    //TODO: Consider edge-triggered epoll
                    //setnonblocking(conn_sock);
                    var clientEvent = epoll_event();
                    clientEvent.events = EPOLLIN.rawValue;
                    clientEvent.data.fd = clientFd;
                    guard epoll_ctl(ev, EPOLL_CTL_ADD, clientFd, &clientEvent) >= 0 else {
                        perror("epoll_ctl:");
                        continue;
                    }
    
                    // add to connected clients set
                    connectedClients.add(clientFd);
                }
                // client sending data
                else if eEvent.events & unsafeBitCast(EPOLLIN, to: UInt32.self) != 0 {
                    let clientDesc = Int32(eEventList[i].data.fd);
                    readFromClient(withFileDescriptor: clientDesc);
                }
                // TODO: epoll close event
                //else if events[i].events ==
                else {
                    let clientDesc = Int32(eEvent.data.fd);
                    close(clientDesc);
                    connectedClients.remove(clientDesc);
                }
            }
        });
    }
#endif

//MARK: Methods exposed to user
    /**
        Starts the HTTP server
     */
    internal func beginListening(onPort port:in_port_t) {
        print("Setting up timers.");
        // create timer to poll for respones to send
        let timer1:Timer!;
        let timer2:Timer!;
        #if !os(Linux)
        timer1 = Timer(timeInterval: POLL_TIME, target: scheduler, selector: #selector(scheduler.sendResponse), userInfo: nil, repeats: true);
        timer2 = Timer(timeInterval: POLL_TIME, target: self, selector: #selector(bsdEventLoop), userInfo: nil, repeats: true);
        #else
        timer1 = Timer(timeInterval: POLL_TIME, repeats: true, block: { _ in
                self.scheduler.sendResponse();
            });
        timer2 = Timer(timeInterval: POLL_TIME, repeats: true, block: { _ in
                self.linuxEventLoop();
            });
        #endif
        RunLoop.current.add(timer1, forMode: RunLoopMode.defaultRunLoopMode);
        RunLoop.current.add(timer2, forMode: RunLoopMode.defaultRunLoopMode);
        
        print("Setting up sockets.");
        // create a tcp socket
        #if os(Linux)
        serverSock = socket(PF_INET, Int32(SOCK_STREAM.rawValue), 0);
        #else
        serverSock = socket(PF_INET, SOCK_STREAM, 0);
        #endif
        guard serverSock > 0 else {
            perror("socket");
            return;
        }
        print("Created the server socket");
        
        // setup server info
        var sin:sockaddr_in = sockaddr_in();
        sin.sin_family = sa_family_t(AF_INET);
        sin.sin_port = port.bigEndian;
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
        print("Binded server socket to port \(port)");
        
        // listen on the socket
        guard listen(serverSock, MAX_CONNECTIONS) == 0 else {
            perror("listen");
            return;
        }
        
        // setup network event multiplexing: kqueue for BSD systems and epoll for Linux systems
        #if os(Linux)
        ev = epoll_create1(0);
        guard ev > 0 else {
            perror("epoll_create1");
            return;
        }
            
        var eEvent = epoll_event();
        eEvent.events = EPOLLIN.rawValue;
        eEvent.data.fd = serverSock;
        if (epoll_ctl(ev, EPOLL_CTL_ADD, serverSock, &eEvent) == -1) {
            perror("epoll_ctl: listen_sock");
            exit(EXIT_FAILURE);
        }
        #else
        kq = kqueue();
        var kEvent = createKernelEvent(withDescriptor: serverSock);
        guard kevent(kq, &kEvent, 1, nil, 0, nil) != -1 else {
            perror("kevent");
            return;
        }
        #endif
        print("Now listening on port \(port).");

        // since it does not inherit NSApplication, we must manually start the runloop. the runloop will
        // allow the NSTimer to fire continuously and so the client thread can handle requests
        RunLoop.main.run();
    }
}
