//
//  Dispatcher.swift
//  SwiftWebFramework
//
//  Created by user on 10/3/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

class Dispatcher : NSObject {
    
    /**
        Create the response header
     */
    //TODO: Add more HTTP headers
    func addResponseHeader(forResponse response:String, withStatusCode statusCode:String) -> String {
        // create HTTP-message
        var header = "HTTP/1.1 ";
        switch statusCode {
        case "100":
            header += statusCode + " Continue"
        case "200":
            header += statusCode + " OK";
        default:
            header += statusCode + " Bad Request";
        }
        header += "\r\n";
        
        // add Content-Length
        let numBytes = response.characters.count;
        header += "Content-Length: \(numBytes)\r\n";
        
        // add time header
        
        return header + "\r\n" + response + "\r\n";
    }
    
    /**
        Create error response
     */
    internal func createStatusCodeResponse(withStatusCode statusCode:String, forClient client:ClientObject, withRouter router:Router) {
        guard router.statusCodeHandler[statusCode] != nil else {
            client.response = "Error in request."
            return;
        }
        
        client.response = addResponseHeader(forResponse: router.statusCodeHandler["400"]!(client), withStatusCode: statusCode);
    }
    
    /**
        Create response for client
     */
    internal func createResponseForClient(_ client:ClientObject, withCallback callback:RouteClosure) {
        let response = callback(client);
        client.response = addResponseHeader(forResponse: response, withStatusCode: "400");
    }
}
