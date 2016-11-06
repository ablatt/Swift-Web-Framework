    //
//  Router.swift
//  SwiftWebFramework
//
//  Created by user on 10/2/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation
#if os(Linux)
import Dispatch
#endif

internal class Router: NSObject {
    // dictionaries containing the routes and callbacks
    internal var GETRoutes = Dictionary<String, URIDictionary>();
    internal var HEADRoutes = Dictionary<String, URIDictionary>();
    internal var POSTRoutes = Dictionary<String, URIDictionary>();
    internal var PUTRoutes = Dictionary<String, URIDictionary>();
    internal var DELETERoutes = Dictionary<String, URIDictionary>();
    internal var TRACERoutes = Dictionary<String, URIDictionary>();
    internal var OPTIONSRoutes = Dictionary<String, URIDictionary>();
    internal var CONNECTRoutes = Dictionary<String, URIDictionary>();
    internal var PATCHRoutes = Dictionary<String, URIDictionary>();
    internal var HOSTRoutes = Dictionary<String, URIDictionary>();
    
    // conveince status code handlers
    internal var statusCodeHandler = Dictionary<String, StatusCodeClosure>();
    
    //Initializers
    override init () {
        // setup default status code handlers
        for (statusCode, description) in httpStatusCodes {
            statusCodeHandler[statusCode] = {(request: ClientObject) -> String in
                return statusCode + " - " + description + "\n";
            }
        }
    }
    
    /**
        Return the route for the client request
     */
    internal func getRouteForClient(_ client: ClientObject) -> RouteClosure? {
        // should always return true since it was processed in validateRequestHeader method
        guard let URI = client.requestHeader["URI"] else {
            print("URI not detected");
            return nil;
        }
        
        var host:String! = client.requestHeader["Host"];
        if host == nil {
            host = DEFAULT_HOST_NAME;
        }
        
        // process each different HTTP method
        var callback:RouteClosure? = nil;
        switch client.requestHeader["METHOD"]! {
        case "GET":
            // host name is not specified, fallback to default host name
            if GETRoutes[host] == nil || GETRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard GETRoutes[host] != nil else {
                return nil;
            }
            callback = GETRoutes[host]![URI];
        case "HEAD":
            // host name is not specified, fallback to default host name
            if HEADRoutes[host] == nil || HEADRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard HEADRoutes[host] != nil else {
                return nil;
            }
            callback = HEADRoutes[host]![URI];
        case "POST":
            // host name is not specified, fallback to default host name
            if POSTRoutes[host] == nil || POSTRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard POSTRoutes[host] != nil else {
                return nil;
            }
            callback = POSTRoutes[host]![URI];
        case "PUT":
            // host name is not specified, fallback to default host name
            if PUTRoutes[host] == nil || PUTRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard PUTRoutes[host] != nil else {
                return nil;
            }
            callback = PUTRoutes[host]![URI];
        case "DELETE":
            // host name is not specified, fallback to default host name
            if DELETERoutes[host] == nil || DELETERoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard DELETERoutes[host] != nil else {
                return nil;
            }
            callback = DELETERoutes[host]![URI];
        case "TRACE":
            // host name is not specified, fallback to default host name
            if TRACERoutes[host] == nil || TRACERoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard TRACERoutes[host] != nil else {
                return nil;
            }
            callback = TRACERoutes[host]![URI];
        case "OPTIONS":
            // host name is not specified, fallback to default host name
            if OPTIONSRoutes[host] == nil || OPTIONSRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard OPTIONSRoutes[host] != nil else {
                return nil;
            }
            callback = OPTIONSRoutes[host]![URI];
        case "CONNECT":
            // host name is not specified, fallback to default host name
            if CONNECTRoutes[host] == nil || CONNECTRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard CONNECTRoutes[host] != nil else {
                return nil;
            }
            callback = CONNECTRoutes[host]![URI];
        case "PATCH":
            // host name is not specified, fallback to default host name
            if PATCHRoutes[host] == nil || PATCHRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard PATCHRoutes[host] != nil else {
                return nil;
            }
            callback = PATCHRoutes[host]![URI];
        case "HOST":
            // host name is not specified, fallback to default host name
            if HOSTRoutes[host] == nil || HOSTRoutes[host]![URI] == nil {
                host = DEFAULT_HOST_NAME;
            }
            
            // check if route has been registered for default host
            guard HOSTRoutes[host] != nil else {
                return nil;
            }
            callback = HOSTRoutes[host]![URI];
        default:
            return nil;
        }
        
        return callback;
    }
}
