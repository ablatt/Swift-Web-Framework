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
    public var requestHeader:Dictionary<String, String>!;          // dictionary of request header values
    public var formData:Dictionary<String, String>?                // form data if POST request
    internal var requestBody:[String]?                               // body of the request
    internal var currentBodyLength = 0;
    internal var hasCompleteHeader = false;                       // flag indicating if full header has been received
    
    // chunked-transfer encoding data
    internal var usesChunkedEncoding = false;
    internal var chunkedFooter:Dictionary<String, String>?;
    internal var expectedChunkSize:Int = -1;
    internal var currChunkSize:Int = 0;
    
    // response data
    public var responseHeader:Dictionary<String, String>!;         // dictionary of response header values
    public var response:String?                                    // response to send to client
    
    // TODO: Timestamp
    
    // private
    internal var fd:Int32 = -1;
    init () {
        resetData();
    }
    
    // reset the data
    func resetData() {
        self.responseHeader = Dictionary<String, String>();
        self.requestHeader = Dictionary<String, String>();
        self.formData = nil;
        self.response = nil;
        self.requestBody = nil;
        self.currentBodyLength = 0;
    }
    
}
