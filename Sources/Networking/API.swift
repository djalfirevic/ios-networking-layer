//
//  API.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

/// The API protocol allows us to separate the task of constructing a URL,
/// its parameters, and HTTP method from the act of executing the URL request
/// and parsing the response.
public protocol API {
    var scheme: HTTPScheme { get }
    var baseURL: String { get }
    var path: String { get }
    var parameters: [URLQueryItem] { get }
    var method: HTTPMethod { get }
    var headerTypes: [HTTPHeaderField: String] { get }
    var body: Data? { get }
}
