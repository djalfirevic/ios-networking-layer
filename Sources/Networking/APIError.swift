//
//  APIError.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case unknown
    case unauthorized
    case network(Error)
    case error(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unknown:
            return "Unknown error"
        case .unauthorized:
            return "Unauthorized"
        case let .network(error):
            return error.localizedDescription
        case let .error(reason):
            return reason
        }
    }
}
