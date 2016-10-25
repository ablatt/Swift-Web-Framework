//
//  ClientObject.swift
//  SwiftWebFramework
//
//  Created by user on 8/28/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

public class ClientObject {
    // request data
    internal var rawRequest:String = String()                        // holds raw request while receiving
    public var requestHeader = Dictionary<String, String>();          // dictionary of request header values
    internal var requestBody:[String]?                               // body of the request
    internal var currentBodyLength = 0;
    internal var hasCompleteHeader = false;                       // flag indicating if full header has been received
    
    // chunked-transfer encoding data
    public var chunkedFooter:Dictionary<String, String>?;
    internal var expectedChunkSize:Int = -1;
    internal var currChunkSize:Int = 0;
    
    // response data
    public var responseHeader = Dictionary<String, String>();         // dictionary of response header values
    public var response:String?                                    // response to send to client
    
    // TODO: Timestamp
    
    // private
    internal var fd:Int32 = -1;
    init () {

    }
}
