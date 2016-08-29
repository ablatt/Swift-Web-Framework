//
//  ClientObject.swift
//  SwiftWebFramework
//
//  Created by user on 8/28/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

class ClientObject {
    var requestHeader = Dictionary<String, String>();       // dictionary of header values
    var requestBody:String?                                 // body of the request
    var formData:Dictionary<String, String>?                // form data if POST request
    var response:String?                             // response to send to client
    
    init () {
        self.requestBody = nil;
        self.formData = nil;
    }
}