//
//  HTTPServerExtension.swift
//  SwiftWebFramework
//
//  Created by user on 8/23/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

typealias StatusCodeClosure = (ClientObject) -> String;
typealias RouteClosure = (ClientObject) -> String;
typealias MiddlewareClosure = (ClientObject) -> Bool;

/**
    Utility functions provided by the HTTP server
 */
protocol HTTPServerUtility {
    func readFile(_ fileName:String) throws -> [String];
}

extension HTTPServer: HTTPServerUtility {
    func readFile(_ fileName:String) throws -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: "sdf");
            return contents;
        } catch {
            throw error;
        }
    }

    //TODO: Add utility to convert JSON to response. https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSJSONSerialization_Class/

}

