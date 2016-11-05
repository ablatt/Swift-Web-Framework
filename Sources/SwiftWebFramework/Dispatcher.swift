//
//  Dispatcher.swift
//  SwiftWebFramework
//
//  Created by user on 10/3/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

internal class Dispatcher : NSObject {
    let dateFormatter:DateFormatter!;

    override init() {
        // dateformatter should be cached per the Data Formatting Guide
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX");
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz";
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT");
    }
    
    /**
        Create the response header
     */
    //TODO: Use client response header since users will be able to customize the response headers in the future
    func addResponseHeader(forResponse response:String, withStatusCode statusCode:String) -> String {
        // create status-line
        var header = "HTTP/1.1 ";
        header += statusCode + " ";
        if let description = httpStatusCodes[statusCode] {
            header += description;
        }
        header += "\r\n";
        
        // add 'Content-Length' if response is non-zero
        if statusCode != "100" && response.utf8.count > 0 {
            let numBytes = response.utf8.count;
            header += "Content-Length:\(numBytes)\r\n";
        }
        
        // add 'Date' header (required for HTTP/1.1)
        if statusCode != "100" {
            let date = Date()
            header += "Date: \(dateFormatter.string(from: date))\r\n";
        }
        
        if statusCode != "100" {
            // add CRLF between header and at the bottom of the body
            return header + "\r\n" + response + "\r\n";
        } else {
            return header;
        }
    }
    
    /**
        Create error response
     */
    internal func createStatusCodeResponse(withStatusCode statusCode:String, forClient client:ClientObject, withRouter router:Router) {
        guard router.statusCodeHandler[statusCode] != nil else {
            client.response = "Error in request."
            return;
        }
        
        client.response = addResponseHeader(forResponse: router.statusCodeHandler[statusCode]!(client), withStatusCode: statusCode);
    }
    
    /**
        Create response for client
     */
    internal func createResponseForClient(_ client:ClientObject, withCallback callback:RouteClosure) {
        let response = callback(client);
        client.response = addResponseHeader(forResponse: response, withStatusCode: "200");
    }
}
