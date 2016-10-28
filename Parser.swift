//
//  Parser.swift
//  swift-web-framework
//
//  Created by user on 10/26/16.
//
//

import Foundation

class Parser {
    /**
     Parse request header from client
     */
    internal func parseHeader(forClient client: ClientObject, withRequest rawRequest:String) -> Bool{
        // create the request dictionary to hold HTTP header key and values
        client.requestHeader = Dictionary<String, String>();
        client.requestHeader["METHOD"] = nil;
        client.requestHeader["URI"] = nil;
        
        // initial line should contain URI & method
        let lines = rawRequest.components(separatedBy: "\r\n");
        var tokens = lines[0].components(separatedBy: " ");
        
        guard tokens.count >= 2 else {
            print("Initial request line is invalid");
            return false;
        }
        
        // set URI and HTTP methods parsed from request
        client.requestHeader["METHOD"] = tokens[0].removingPercentEncoding!.replacingOccurrences(of: " ", with: "");
        client.requestHeader["URI"] = tokens[1].removingPercentEncoding!.replacingOccurrences(of: " ", with: "");
        client.requestHeader["VERSION"] = tokens[2].removingPercentEncoding!.replacingOccurrences(of: " ", with: "");
        
        // check if URL is absolute URL
        if client.requestHeader["URI"] != nil,
            client.requestHeader["URI"]!.contains("http://") {
            // separate tokens by "//"
            let urlTokens = client.requestHeader["URI"]!.components(separatedBy: "//");
            guard urlTokens.count >= 2 else {
                print("Initial request line is invalid");
                return false;
            }
            
            // separate tokens by '/' to grab to path
            let pathTokens = urlTokens[1].components(separatedBy: "/");
            guard pathTokens.count >= 2 else {
                print("Initial request line is invalid");
                return false;
            }
            client.requestHeader["URI"] = pathTokens[1];
        }
        
        // process the other HTTP header entries
        for i in 1...(lines.count - 1) {
            // header is in key:val format
            tokens = lines[i].components(separatedBy: ":");
            
            // header data has to be in key:value pair
            guard tokens.count >= 2 else {
                client.requestHeader[tokens[0]] = "";
                continue;
            }
            
            // strip white space from tokens
            tokens[0] = tokens[0].replacingOccurrences(of: " ", with: "");
            tokens[1] = tokens[1].replacingOccurrences(of: " ", with: "");
            
            client.requestHeader[tokens[0]] = tokens[1];
        }
        
        // schedule request processing and response
        return true;
    }
    
    /**
     Special function for processing POST requests
     */
    internal func parseMessageBody(forClient client:ClientObject, withBuffer buff:Data? = nil) -> Bool {
        var contentLength = client.requestHeader["Content-Length"];
        let chunkedEncoding = client.requestHeader["Transfer-Encoding"];
        
        // TODO: Add more cases to consider for different URIs
        if contentLength == nil && chunkedEncoding == nil {
            // POST requests need to have a Content-Length or be chunked-encoded
            if client.requestHeader["METHOD"] == "POST" {
                print("content-length not found nor chunked-encoding. cannot proceed parsing message body");
                return false;
            } else if client.requestHeader["METHOD"] == "GET" {
                return true;
            }
        }
        
        // extract message body with content-length header specified
        if contentLength != nil {
            // strip white space and convert to int
            contentLength = contentLength!.replacingOccurrences(of: " ", with: "");
            guard let messageSize = Int(contentLength!) else {
                print("Content-Length header not found");
                //dispatcher.createStatusCodeResponse(withStatusCode: "400", forClient: client, withRouter: router);
                //scheduler.scheduleResponse(forClient: client);
                return false;
            }
            
            // append to request message body and get current length of message body
            if buff != nil {
                client.currentBodyLength += buff!.count;
                client.requestBody.append(buff!);
            }
            
            print("Expected: \(messageSize)");
            print("Curr: \(client.currentBodyLength)");
            
            // check if full body message was received
            if client.currentBodyLength == messageSize {
                return true;
            } else {
                return false;
            }
        }
        /*
         //TODO: Need to handle meta data of chunked encoding
         // chunked-encoding
         else {
         var footerIndex = 0;
         //print("Count: \(lines.count)");
         for i in (0...lines.count-1) {
         if lines[i] == "" {
         continue;
         }
         
         var tokens = lines[i].components(separatedBy: ";");
         
         guard tokens.count > 0 else {
         print("failed to get chunk size");
         return false;
         }
         
         var chunkSize:Int!;
         
         // check if last chunk received was chunk size or not
         if client.expectedChunkSize < 0 {
         chunkSize = hexToInt(withHexString:&tokens[0]);
         guard chunkSize != nil else {
         print("failed to convert hex chunk size to int");
         return false;
         }
         
         // if this is the last line, store the chunk size for next chunks received
         client.expectedChunkSize = chunkSize;
         } else {
         chunkSize = client.expectedChunkSize;
         
         // no more chunks but there are possible footers
         if chunkSize != 0 {
         // next line contains request body
         if client.requestBody == nil {
         client.requestBody = [String]();
         }
         
         client.requestBody!.append(lines[i]);
         client.currChunkSize += lines[i].characters.count;
         
         // check if we can get next chunk size
         if client.currChunkSize == client.expectedChunkSize {
         client.expectedChunkSize = -1;
         client.currChunkSize = 0;
         }
         } else {
         footerIndex = i + 1;
         break;
         }
         }
         }
         
         // extract foot
         while footerIndex < lines.count {
         // end of chunked data section
         if lines[footerIndex] == "" {
         break;
         }
         
         let footerTokens =  lines[footerIndex].components(separatedBy: ":");
         if footerTokens.count < 2 {
         footerIndex += 1;
         continue;
         }
         if client.chunkedFooter == nil {
         client.chunkedFooter = Dictionary<String, String>();
         }
         client.chunkedFooter![footerTokens[0]] = footerTokens[1];
         footerIndex += 1;
         }
         
         return true;
         }
         */
        return false;
    }
}
