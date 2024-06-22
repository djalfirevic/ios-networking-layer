//
//  ResponseStatus.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

public enum ResponseStatus {
    case informational
    case success
    case redirect
    case clientError
    case serverError
    case systemError
    case unauthorized

    // MARK: - Initialization

    public init(statusCode: Int) {
        switch statusCode {
        case 100...199: self = .informational
        case 200...299: self = .success
        case 300...399: self = .redirect
        case 400...499:
            if statusCode == 401 {
                self = .unauthorized
            } else {
                self = .clientError
            }
        case 500...599: self = .serverError
        default: self = .systemError
        }
    }
}
