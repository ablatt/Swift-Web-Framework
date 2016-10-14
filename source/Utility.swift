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

/**
    Convert hex string to Int
*/
//TODO: Add throws for error
func hexToInt(withHexString hexString:inout String) -> Int? {
    var ret = 0;
    hexString = hexString.uppercased();
    for hexChar in hexString.characters {
        if ret > Int.max/16 {
            return nil;
        }
        ret *= 16;
        
        switch hexChar {
        case "0":
            ret += 0;
        case "1":
            ret += 1;
        case "2":
            ret += 2;
        case "3":
            ret += 3;
        case "4":
            ret += 4;
        case "5":
            ret += 5;
        case "6":
            ret += 6;
        case "7":
            ret += 7;
        case "8":
            ret += 8;
        case "9":
            ret += 9;
        case "A":
            ret += 10;
        case "B":
            ret += 11;
        case "C":
            ret += 12;
        case "D":
            ret += 13;
        case "E":
            ret += 14;
        case "F":
            ret += 15;
        default:
            return nil;
        }
    }
    return ret;
}
