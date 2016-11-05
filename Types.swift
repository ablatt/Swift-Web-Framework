//
//  Types.swift
//  swift-web-framework
//
//  Created by user on 10/28/16.
//
//

import Foundation

// Error types
enum HTTPServerError: Error {
    case BadRequest
    case StringTokenError
    case ChunkSizeExtractionError
}

// CRLF delimiters
let headerDelimiter = String("\r\n\r\n")!.data(using: .utf8)!;
let crlfDelimiter = String("\r\n")!.data(using: .utf8)!;
let semiColonDelimiter = String(";")!.data(using: .utf8)!;
