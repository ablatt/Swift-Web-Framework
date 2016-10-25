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
    // Main API
    func addGETRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addHEADRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addPOSTRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addPUTRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addDELETERoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addTRACERoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addOPTIONSRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addCONNECTRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addPATCHRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addHOSTRoute(_ route:String, forHost host:String, withCallback callback: @escaping RouteClosure);
    func addMiddleware(forHost host:String, withMiddlewareHandler middleware:@escaping MiddlewareClosure);
    func addStatusCodeHandler(_ handler:@escaping StatusCodeClosure, forStatusCode statusCode:String);
    func startServer(onPort port:in_port_t);

    // Utility API
    func readFile(_ file:String) throws -> [String];
    func getFormData(forClient client:ClientObject) -> Dictionary<String, String>?;
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
    public func addGETRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.GETRoutes[host] == nil {
            router.GETRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.GETRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified HEAD route
     */
    public func addHEADRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.HEADRoutes[host] == nil {
            router.HEADRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.HEADRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified POST route
     */
    public func addPOSTRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.POSTRoutes[host] == nil {
            router.POSTRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.POSTRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified PUT route
     */
    public func addPUTRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.PUTRoutes[host] == nil {
            router.PUTRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.PUTRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified DELETE route
     */
    public func addDELETERoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.DELETERoutes[host] == nil {
            router.DELETERoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.DELETERoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified TRACE route
     */
    public func addTRACERoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.TRACERoutes[host] == nil {
            router.TRACERoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.TRACERoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified OPTIONS route
     */
    public func addOPTIONSRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.OPTIONSRoutes[host] == nil {
           router.OPTIONSRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.OPTIONSRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified CONNECT route
     */
    public func addCONNECTRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.CONNECTRoutes[host] == nil {
            router.CONNECTRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.CONNECTRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified PATCH route
     */
    public func addPATCHRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.PATCHRoutes[host] == nil {
            router.PATCHRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.PATCHRoutes[host]![route] = callback;
    }
    
    /**
     Adds a callback to handle the specified HOST route
     */
    public func addHOSTRoute(_ route:String, forHost host:String = DEFAULT_HOST_NAME, withCallback callback: @escaping RouteClosure) {
        if router.HOSTRoutes[host] == nil {
            router.HOSTRoutes[host] = Dictionary<String, RouteClosure>();
        }
        router.HOSTRoutes[host]![route] = callback;
    }
    
    /**
     Adds user defined middleware to process and validate the client request
     */
    public func addMiddleware(forHost host:String = DEFAULT_HOST_NAME, withMiddlewareHandler middleware:@escaping MiddlewareClosure) {
        if middlewareList[host] == nil {
            middlewareList[host] = Array<MiddlewareClosure>();
        }
        middlewareList[host]!.append(middleware);
    }
    
    /**
     Adds handlers for HTTP status codes
     */
    public func addStatusCodeHandler(_ handler:@escaping StatusCodeClosure, forStatusCode statusCode:String) {
        router.statusCodeHandler[statusCode] = handler;
    }
    
    /**
     Api to schedule response to client outside of callback. Parameter is a single response string
     */
    public func scheduleResponse(forClient client:ClientObject) {
        guard client.fd != -1 else {
            return;
        }
        self.scheduler.scheduleResponse(forClient: client)
    }
    
    /**
        API to parse form data from message body
     */
    /*
    public func getFormData(FromRequest request:[String], startingAtIndex index:Int) -> Dictionary<String, String> {
        var formData = Dictionary<String, String>();
        
        // iterate through all the lines containing form data and extract
        for i in index...(request.count - 1) {
            // different form data is delimited by &
            let postEntries = request[i].components(separatedBy: "&");
            for j in 0...(postEntries.count - 1) {
                let formPair = postEntries[j].components(separatedBy: "=");
                guard formPair.count == 2 else {
                    formData[formPair[0]] = "";
                    continue;
                }
                formData[formPair[0]] = formPair[1];
            }
        }
        return formData;
    }
    */
    func getFormData(forClient client:ClientObject) -> Dictionary<String, String>? {
        var formData:Dictionary<String, String>?;
    
        guard client.requestBody != nil else {
            print("No request body, can't get form.");
            return formData;
        }
        formData = Dictionary<String, String>();
    
        // iterate through all the lines containing form data and extract
        for line in client.requestBody! {
            let postEntries = line.components(separatedBy: "&");
            for j in 0...(postEntries.count - 1) {
                let formPair = postEntries[j].components(separatedBy: "=");
                guard formPair.count == 2 else {
                    formData![formPair[0]] = "";
                    continue;
                }
                formData![formPair[0]] = formPair[1];
            }
        }
        return formData;
    }
    
    /**
        API to start HTTP server on user defined port
     */
    public func startServer(onPort usersPort:in_port_t) {
        beginListening(onPort: usersPort);
    }

}

