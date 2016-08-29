//
//  HTTPServerExtension.swift
//  SwiftWebFramework
//
//  Created by user on 8/23/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

typealias RouteClosure = (ClientObject) -> String;
typealias MiddlewareClosure = (ClientObject) -> Bool;

/**
    Utility functions provided by the HTTP server
 */
protocol HTTPServerExtension {
    func readFile(fileName:String) throws -> [String];
}

extension HTTPServer: HTTPServerExtension {
    func readFile(fileName:String) throws -> [String] {
        do {
            let contents = try NSFileManager.defaultManager().contentsOfDirectoryAtPath("sdf");
            return contents;
        } catch {
            throw error;
        }
    }

    //TODO: Add utility to convert JSON to response. https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSJSONSerialization_Class/

}

