//
//  main.swift
//  SwiftWebFramework
//
//  Created by user on 8/22/16.
//  Copyright © 2016 user. All rights reserved.
//

import Foundation

let h = HTTPServer();
h.addGETRoute("/", withCallback: { (request: ClientObject) -> String in
    var page = "<html> Hello, world!</html>";
    return page;
});

h.addGETRoute("/get_test_1", withCallback: { (request: ClientObject) -> String in
    var page = "<html> Success in routing </html>";
    return page;
});


h.addGETRoute("/host_test_1", forHost: "localhost") { (request: ClientObject) -> String in
    var page = "<html> Success in testing host header support </html>";
    return page;
}

h.addGETRoute("/post_test_1", withCallback: { (request: ClientObject) -> String in
    let page =  " <html>" +
                " <form action=\"after_post\" method=\"post\">" +
                "   First name:<br> " +
                "   <input type=\"text\" name=\"firstname\" value=\"\"><br>" +
                "   Last name:<br>" +
                "   <input type=\"text\" name=\"lastname\" value=\"\"><br><br>" +
                "   <input type=\"submit\" value=\"Submit\">" +
                " </form> "
                " </html>";
    return page;
});

h.addPOSTRoute("/after_post", withCallback: { (request: ClientObject) -> String in
    var page =  "success in serving POST request\n"
                    ;
    guard request.formData != nil else {
        return "no form detected";
    }
    
    for entries in request.formData! {
        print(entries);
        page += entries.0 + ": " + entries.1 + "\n";
    }
    return page;
});

h.startServer(onPort: 9002);
