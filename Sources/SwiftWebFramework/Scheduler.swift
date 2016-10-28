//
//  Scheduler.swift
//  SwiftWebFramework
//
//  Created by user on 10/2/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation
#if os(Linux)
import Dispatch
#endif

class Scheduler : NSObject {
    // queue of connected clients to send responses to
    fileprivate var responseQueue = Queue<ClientObject>();
    
    // lock
    fileprivate let lockQueue = DispatchQueue(label: "httpserver.lock", attributes: []);
    
    // serial queue for
    fileprivate var sendQueue = DispatchQueue(label: "swiftwebframework.sendqueue", attributes: []);

    
    // connected clients list
    internal var connectedClients = NSMutableSet();
    
    init (clients: NSMutableSet) {
        self.connectedClients = clients;
    }

    
    /**
        Schedule to send response to client
     */
    internal func scheduleResponse(forClient client:ClientObject) {
        responseQueue.enqueue(client);
    }
    
    /**
        Timed function that attempts to send responses dispatched in a serial queue
     */
    #if !os(Linux)
    @objc internal func sendResponseBSD(_ timer:Timer!) {
        sendResponse();
    }
    #endif
    
    internal func sendResponse() {
        sendQueue.async {
            while self.responseQueue.empty() == false {
                // lock since it's possible response object is large
                self.lockQueue.sync(execute: {
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
                        let res = send(fd, buff, response.lengthOfBytes(using: String.Encoding.utf8), Int32(MSG_OOB));
                        guard res >= 0 else {
                            print("failed to send response")
                            return;
                        }
                        bytesSent += numBytes;
                       // fsync(fd);
                    }
                    print("Bytes sent: \(bytesSent) / \(numBytes)");
                    
                    // For HTTP 1.1, connections are considered persistent unless the Connection header is close
                    // For HTTP 1.0, connections are assumed to be closed
                    let connectionHeader = client.requestHeader["Connection"];
                    if (connectionHeader != nil && connectionHeader == "close") ||
                        client.requestHeader["VERSION"] == "HTTP/1.0" {
                            print("keep-alive is not detected");
                            close(fd);
                            self.connectedClients.remove(client.fd);
                            return;
                    }                    
                });
            }
        }
    }
}
