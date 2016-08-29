//
//  Utility.swift
//  SwiftWebFramework
//
//  Created by user on 8/21/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

let htons = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16 : { $0 }

/**
 Casts from sockaddr_in to sockaddr (&sockaddr_in needs to first be cast to UnsafeMutablePointer<Void> before it can cast to &sockaddr)
 */
func sockCast(p : UnsafeMutablePointer<Void>) ->UnsafeMutablePointer<sockaddr> {
    return UnsafeMutablePointer<sockaddr>(p);
}

/**
    Utility function to create a kevent for a kernel queue and file descriptor
 */
func createKernelEvent(withDescriptor socket:Int32) -> kevent {
    // set kernel to listen to socket events
    var kSocketEvent = kevent();
    kSocketEvent.ident = UInt(socket);
    kSocketEvent.filter = Int16(EVFILT_READ);
    kSocketEvent.flags = UInt16(EV_ADD);
    kSocketEvent.fflags = 0;
    kSocketEvent.data = 0;
    return kSocketEvent;
}