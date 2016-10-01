//
//  HTTPServerExtension.swift
//  SwiftWebFramework
//
//  Created by user on 8/23/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

public typealias StatusCodeClosure = (ClientObject) -> String;
public typealias RouteClosure = (ClientObject) -> String;
public typealias MiddlewareClosure = (ClientObject) -> Bool;

/**
    Protocol defining the public API
 */
protocol HTTPServerAPI {
    func readFile(_ file:String) throws -> [String];
    func addGETRoute(_ route:String, callback: @escaping RouteClosure);
    func addHEADRoute(_ route:String, callback: @escaping RouteClosure);
    func addPOSTRoute(_ route:String, callback: @escaping RouteClosure);
    func addPUTRoute(_ route:String, callback: @escaping RouteClosure);
    func addDELETERoute(_ route:String, callback: @escaping RouteClosure);
    func addTRACERoute(_ route:String, callback: @escaping RouteClosure);
    func addOPTIONSRoute(_ route:String, callback: @escaping RouteClosure);
    func addCONNECTRoute(_ route:String, callback: @escaping RouteClosure);
    func addPATCHRoute(_ route:String, callback: @escaping RouteClosure);
    func addHOSTRoute(_ route:String, callback: @escaping RouteClosure);
    func addMiddleware(_ middleware:@escaping MiddlewareClosure);
    func addStatusCodeHandler(_ handler:@escaping StatusCodeClosure, forStatusCode statusCode:String);
    func scheduleResponse(_ response:String, to client:ClientObject);
    func scheduleResponse(_ response:[String], to client:ClientObject);

}

/**
    API is implemented via an extension to the main HTTPServer class
 */
extension HTTPServer: HTTPServerAPI {
    public func readFile(_ file:String) throws -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: file);
            return contents;
        } catch {
            throw error;
        }
    }
    
    /**
     Adds a callback to handle the specified GET route
     */
    public func addGETRoute(_ route:String, callback: @escaping RouteClosure) {
        GETRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified HEAD route
     */
    public func addHEADRoute(_ route:String, callback: @escaping RouteClosure) {
        HEADRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified POST route
     */
    public func addPOSTRoute(_ route:String, callback: @escaping RouteClosure) {
        POSTRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified PUT route
     */
    public func addPUTRoute(_ route:String, callback: @escaping RouteClosure) {
        PUTRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified DELETE route
     */
    public func addDELETERoute(_ route:String, callback: @escaping RouteClosure) {
        DELETERoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified TRACE route
     */
    public func addTRACERoute(_ route:String, callback: @escaping RouteClosure) {
        TRACERoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified OPTIONS route
     */
    public func addOPTIONSRoute(_ route:String, callback: @escaping RouteClosure) {
        OPTIONSRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified CONNECT route
     */
    public func addCONNECTRoute(_ route:String, callback: @escaping RouteClosure) {
        CONNECTRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified PATCH route
     */
    public func addPATCHRoute(_ route:String, callback: @escaping RouteClosure) {
        PATCHRoutes[route] = callback;
    }
    
    /**
     Adds a callback to handle the specified HOST route
     */
    public func addHOSTRoute(_ route:String, callback: @escaping RouteClosure) {
        HOSTRoutes[route] = callback;
    }
    
    /**
     Adds user defined middleware to process and validate the client request
     */
    public func addMiddleware(_ middleware:@escaping MiddlewareClosure) {
        middlewareList.append(middleware);
    }
    
    /**
     Adds handlers for HTTP status codes
     */
    public func addStatusCodeHandler(_ handler:@escaping StatusCodeClosure, forStatusCode statusCode:String) {
        statusCodeHandler[statusCode] = handler;
    }
    
    /**
     Api to schedule response to client outside of callback. Parameter is a single response string
     */
    public func scheduleResponse(_ response:String, to client:ClientObject) {
        guard client.fd != -1 else {
            return;
        }
        self.responseQueue.enqueue(client);
    }
    
    /**
     Api to schedule response to client outside of callback. Parameter is an array of response strings
     */
    public func scheduleResponse(_ response:[String], to client:ClientObject) {
        guard client.fd != -1 else {
            return;
        }
        self.responseQueue.enqueue(client);
    }
}

