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
