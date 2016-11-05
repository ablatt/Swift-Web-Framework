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
    
    fileprivate func extractChunkSize(startingAtIndex offset:Int, withBuffer buff:Data) throws -> (offset:Int, chunkSize:Int) {
        // we find the next CRLF since offset increase per extraction of a chunk
        let searchRange = Range<Int> (offset..<buff.count);
        guard let crlfRange = buff.range(of: crlfDelimiter, in:searchRange) else {
            print("Invalid message body. Request is using chunked-encoding. Chunk size not formatted properly.");
            throw HTTPServerError.ChunkSizeExtractionError;
        }
        
        // extract chunk size line as data
        let lineRange = Range<Int> (offset...(crlfRange.lowerBound-1));
        let chunkSizeLine = buff.subdata(in: lineRange);
        
        // chunk size string
        var chunkSizeStr:String?;
        
        // extract chunk size range. meta data can exist at the end of the chunk size line
        // delimited by a semi-colon
        if let semiColonRange = chunkSizeLine.range(of: semiColonDelimiter) {
            let chunkSizeData = buff.subdata(in: Range<Int> (0...semiColonRange.lowerBound));
            guard chunkSizeData.count > 0 else {
                print("Failed to find chunk size in request message body with chunked encoding.");
                throw HTTPServerError.ChunkSizeExtractionError;
            }
            
            // convert chunk size data to string to convert to int
            chunkSizeStr = String(data: chunkSizeData, encoding:.utf8);
        } else {
            // convert chunk size data to string to convert to int
            chunkSizeStr = String(data: chunkSizeLine, encoding:.utf8);
        }
        
        guard chunkSizeStr != nil else {
            print("Failed to convert chunk size Data to type String.");
            throw HTTPServerError.ChunkSizeExtractionError;
        }
        
        // convert chunk size hex into Int
        guard let convertedChunk = hexToInt(withHexString: &chunkSizeStr!) else {
            print("Failed to convert chunk size hex string to Int.");
            throw HTTPServerError.ChunkSizeExtractionError;
        }
        
        let chunkSize = convertedChunk;
        
        
        // request body starts after end of CRLF
        let offset = crlfRange.upperBound;
        
        return (offset, chunkSize);
    }
    
    /**
     Special function for processing POST requests
     */
    //TODO: Need error handlers
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
        
        if buff == nil && (contentLength != nil || chunkedEncoding != nil) {
            return false;
        }
        
        // extract message body with content-length header specified
        if contentLength != nil {
            // strip white space and convert to int
            contentLength = contentLength!.replacingOccurrences(of: " ", with: "");
            guard let messageSize = Int(contentLength!) else {
                print("Content-Length header not found");
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
        //TODO: Need to handle meta data of chunked encoding
        // chunked-encoding
        else {
            var offset = 0;
            
            while offset < buff!.count {
                // extract chunk size if it was has not been extracted from the message body
                if client.expectedChunkSize < 0 {
                    do {
                        let chunkData = try extractChunkSize(startingAtIndex: offset, withBuffer: buff!);
                        client.expectedChunkSize = chunkData.chunkSize;
                        offset = chunkData.offset;
                    } catch {
                        //print("Can\'t proess request. Encountered invalid chunk size during message body extraction.");
                    }
                }

                // end of message body when chunk size is 0
                if client.expectedChunkSize == 0 {
                    print("--Received final chunk ---");
                    break;
                }
                
                // extract chunk up to expectedChunkSize
                let extractedData:Data;
                var dataRange:Range<Int>?;
                let bytesToExtract = client.expectedChunkSize - client.currChunkSize;
                let availableBytes = buff!.count - offset;
                
                // not enough bytes available to extract
                if bytesToExtract > availableBytes {
                    dataRange = Range<Int> (offset..<(offset + availableBytes));
                } else if bytesToExtract <= availableBytes && bytesToExtract > 0 {
                    dataRange = Range<Int> (offset..<bytesToExtract);
                }
                
                if dataRange != nil {
                    extractedData = buff!.subdata(in: dataRange!);
                    offset += extractedData.count;
                    client.requestBody.append(extractedData);
                    client.currChunkSize += extractedData.count;
                }
                
                // check if we full extracted chunkSize bytes
                if client.currChunkSize == client.expectedChunkSize {
                    client.currChunkSize = 0;
                    client.expectedChunkSize = -1;
                    
                    // increase by 2 to ignore the CRLF at the end of the chunk body
                    offset += 2;
                }
                

            } // iterate over buf
            
            // get footer
            //while offset < buff!.count {
            //
            //}
            
            // received last chunk when chunk size parsed is 0
            if client.expectedChunkSize == 0 {
                return true;
            } else {
                return false;
            }
        }
        return false;
    }
}
