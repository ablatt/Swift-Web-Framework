//
//  Scheduler.swift
//  SwiftWebFramework
//
//  Created by user on 10/2/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

class Scheduler : NSObject {
    // queue of connected clients to send responses to
    fileprivate var responseQueue = Queue<ClientObject>();
    
    // lock
    fileprivate let lockQueue = DispatchQueue(label: "httpserver.lock", attributes: []);
    
    /**
        Schedule to send response to client
     */
    internal func scheduleResponse(forClient client:ClientObject) {
        responseQueue.enqueue(client);
    }

    /**
        Timed function that attempts to send responses dispatched in a serial queue
     */
    @objc internal func sendResponse(_ timer:Timer!) {
        guard let connectedClients = timer.userInfo as? NSMutableSet else {
            print("Failed to get clients list in scheduler");
            return;
        }
        
        while responseQueue.empty() == false {
            // lock since it's possible response object is large
            lockQueue.sync(execute: {
                guard let client = responseQueue.dequeue() else {
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
                
                // For HTTP 1.1, connections are considered persistent unless the Connection header is close
                // For HTTP 1.0, connections are assumed to be closed
                let connectionHeader = client.requestHeader["Connection"];
                if (connectionHeader != nil && connectionHeader == "close") ||
                    client.requestHeader["VERSION"] == "1.0" {
                        print("keep-alive is not detected");
                        close(fd);
                        connectedClients.remove(fd);
                        return;
                }
            });
        }
    }
}
