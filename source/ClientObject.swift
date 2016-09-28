//
//  ClientObject.swift
//  SwiftWebFramework
//
//  Created by user on 8/28/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

public class ClientObject {
    var requestHeader:Dictionary<String, String>!;          // dictionary of request header values
    var responseHeader:Dictionary<String, String>!;         // dictionary of response header values
    var formData:Dictionary<String, String>?                // form data if POST request
    var response:String?                                    // response to send to client
    var rawRequest:String = String()                        // holds raw request while receiving
    
    // body information
    var bodyStartingIndex = -1;
    var requestBody:[String]?                               // body of the request
    var bodyLength = 0;
    // TODO: Timestamp
    
    // private
    var fd:Int32 = -1;
    init () {
        resetData();
    }
    
    // reset the data
    func resetData() {
        self.responseHeader = Dictionary<String, String>();
        self.requestHeader = Dictionary<String, String>();
        self.formData = nil;
        self.response = nil;
        self.bodyStartingIndex = -1;
        self.requestBody = nil;
        self.bodyLength = 0;
    }
    
}
