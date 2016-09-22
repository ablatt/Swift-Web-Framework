//
//  Queue.swift
//  SwiftWebFramework
//
//  Created by user on 8/23/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

class QueueNode <T> {
    var val:T?
    var next:QueueNode<T>?
    
    init(_ val: T) {
        self.val = val;
        self.next = nil;
    }
}

/**
 Generic queue (Swift lib doesn't implement a queue)
 */
class Queue<T> {
    var head: QueueNode<T>!
    var tail: QueueNode<T>!
    var size:UInt32!
    
    init() {
        self.head = nil;
        self.tail = nil;
        self.size = 0;
    }
    
    func enqueue(_ entry: T) {
        let newNode = QueueNode<T>(entry);
        if head == nil {
            head = newNode;
            tail = head;
        } else {
            tail.next = newNode;
            tail = newNode;
        }
        size = size + 1;
    }
    
    func dequeue() -> T? {
        if size > 0 {
            let val = head.val;
            head = head.next;
            size = size - 1;
            
            // check if tail should be null
            if head == nil {
                tail = nil;
            }
            return val!;
        } else {
            return nil;
        }
    }
    
    func empty() -> Bool {
        return self.size == 0;
    }
}
