//
//  DataResponse.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

public struct DataResponse<T: Any> {

    // MARK: - Properties

    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public var result: Result<T, APIError>
    public let data: Data?
    public var value: T? {
        switch result {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    public var error: Error? {
        switch result {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    public var statusCode: Int? { response?.statusCode }

    // MARK: - Initialization

    public init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        result: Result<T, APIError>,
        data: Data?
    ) {
        self.request = request
        self.response = response
        self.result = result
        self.data = data
    }
}
