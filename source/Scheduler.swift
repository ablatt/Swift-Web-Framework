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
        guard var clientsList = timer.userInfo as? Dictionary<Int32, ClientObject> else {
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
                
                // if connection type is keep-alive, don't close the connection
                guard let keepAlive = clientsList[fd]?.requestHeader["Connection"] ,
                    keepAlive == "keep-alive" else {
                        print("keep-alive is not detected");
                        close(fd);
                        clientsList[fd] = nil;
                        return;
                }
            });
        }
    }
}
