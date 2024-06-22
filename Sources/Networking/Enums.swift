//
//  Enums.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

public enum HTTPMethod {
    case delete
    case get
    case patch
    case post
    case put
    case multipart(filename: String, data: Data, mimeType: String, formData: [String: String]?)
}

public enum HTTPScheme: String {
    case http
    case https
}

public enum HTTPHeaderField: String {
    case contentType = "Content-Type"
    case accept = "Accept"
    case authorization = "Authorization"
}
