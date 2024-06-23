//
//  NetworkManager.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Combine
import Foundation
import Network

final public class NetworkManager {

    private enum Constants {
        static let timeoutInterval: TimeInterval = 60
        static let memoryCacheSizeMB = 25 * 1024 * 1024
        static let diskCacheSizeMB = 250 * 1024 * 1024
    }

    // MARK: - Properties

    public static let shared = NetworkManager()
    private static let cache = URLCache(
        memoryCapacity: Constants.memoryCacheSizeMB,
        diskCapacity: Constants.diskCacheSizeMB,
        diskPath: String(describing: NetworkManager.self)
    )
    private static let sessionConfiguration: URLSessionConfiguration = {
        var configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.urlCache = cache
        return configuration
    }()
    private var session = URLSession(configuration: sessionConfiguration)
    public var serverURL = ""

    // MARK: - Public API

    /// Executes the web call and will decode the JSON response into the Codable object provided.
    /// - Parameters:
    ///   - endpoint: the endpoint to make the HTTP request against
    public func request<T: Decodable>(endpoint: API) -> AnyPublisher<T, APIError> {
        guard Reachability.isConnectedToNetwork() else {
            return AnyPublisher(Fail<T, APIError>(error: APIError.error(reason: "Please provide Internet connection")))
        }

        guard let url = buildURL(endpoint: endpoint).url else {
            return AnyPublisher(Fail<T, APIError>(error: APIError.invalidURL))
        }

        let urlRequest = createRequest(url: url, endpoint: endpoint)

        return session.dataTaskPublisher(for: urlRequest)
            .retry(1)
            .receive(on: DispatchQueue.main)
            .tryMap { data, response in
                self.logDataResponse(data: data, response: response, request: urlRequest)
                try self.handleResponse(response: response)
                return try self.decode(data: data, to: T.self)
            }
            .mapError { error in
                return self.mapError(error)
            }
            .eraseToAnyPublisher()
    }

    /// Executes the web call and will decode the JSON response into the Codable object provided.
    /// - Parameters:
    ///   - endpoint: the endpoint to make the HTTP request against
    ///   - completion: completion handler
    public func request<T: Decodable>(endpoint: API, _ completion: @escaping (Result<T, APIError>) -> Void) {
        guard Reachability.isConnectedToNetwork() else {
            completion(.failure(APIError.error(reason: "Please provide Internet connection")))
            return
        }

        guard let url = buildURL(endpoint: endpoint).url else {
            completion(.failure(APIError.invalidURL))
            return
        }

        let urlRequest = createRequest(url: url, endpoint: endpoint)

        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self else { return }

            DispatchQueue.main.async {
                self.logDataResponse(data: data, response: response, request: urlRequest)

                if let error = error {
                    completion(.failure(APIError.error(reason: error.localizedDescription)))
                    return
                }

                do {
                    try self.handleResponse(response: response)
                    if let data = data {
                        let decodedObject = try self.decode(data: data, to: T.self)
                        completion(.success(decodedObject))
                    } else {
                        completion(.failure(APIError.error(reason: "No data received")))
                    }
                } catch {
                    completion(.failure(APIError.error(reason: error.localizedDescription)))
                }
            }
        }.resume()
    }

    /// Executes the web call and will decode the JSON response into the Codable object provided using `async`.
    /// - Parameters:
    ///   - endpoint: the endpoint to make the HTTP request against
    public func request<T: Decodable>(endpoint: API) async throws -> T {
        guard Reachability.isConnectedToNetwork() else {
            throw APIError.error(reason: "Please provide Internet connection")
        }

        guard let url = buildURL(endpoint: endpoint).url else {
            throw APIError.invalidURL
        }

        let urlRequest = createRequest(url: url, endpoint: endpoint)
        let (data, response) = try await session.data(for: urlRequest)

        logDataResponse(data: data, response: response, request: urlRequest)
        try handleResponse(response: response)

        return try decode(data: data, to: T.self)
    }

    // MARK: - Private API

    private func logDataResponse(data: Data?, response: URLResponse?, request: URLRequest) {
        let dataResponse = DataResponse<Bool>(
            request: request,
            response: response as? HTTPURLResponse,
            result: .success(true),
            data: data
        )

        APILogger.logDataResponse(dataResponse)
    }

    private func decode<T: Decodable>(data: Data, to type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return try decoder.decode(T.self, from: data)
    }

    private func handleResponse(response: URLResponse?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.error(reason: "Invalid response")
        }

        let responseStatus = ResponseStatus(statusCode: httpResponse.statusCode)
        switch responseStatus {
        case .unauthorized:
            throw APIError.unauthorized
        case .clientError, .serverError:
            throw APIError.error(reason: "Server error")
        default:
            break
        }
    }

    private func mapError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        } else {
            return APIError.error(reason: error.localizedDescription)
        }
    }

    private func createRequest(url: URL, endpoint: API) -> URLRequest {
        var urlRequest = URLRequest(url: url)

        for (key, value) in endpoint.headerTypes {
            urlRequest.setValue(value, forHTTPHeaderField: key.rawValue)
        }

        switch endpoint.method {
        case .get:
            urlRequest.httpMethod = "GET"
        case .post:
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = endpoint.body
        case .put:
            urlRequest.httpMethod = "PUT"
            urlRequest.httpBody = endpoint.body
        case .patch:
            urlRequest.httpMethod = "PATCH"
            urlRequest.httpBody = endpoint.body
        case .delete:
            urlRequest.httpMethod = "DELETE"
        case .multipart(let filename, let data, let mimeType, let formData):
            let boundary = String(format: "Boundary+%08X%08X", arc4random(), arc4random())
            let multipartData = Data(multipartFilename: filename, data: data, fileContentType: mimeType, formData: formData ?? [:], boundary: boundary)
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = multipartData
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        }

        return urlRequest
    }

    /// Builds the relevant URL components from the values specified in the API.
    private func buildURL(endpoint: API) -> URLComponents {
        var components = URLComponents()
        components.scheme = endpoint.scheme.rawValue
        components.host = endpoint.baseURL
        components.path = endpoint.path
        components.queryItems = endpoint.parameters
        return components
    }
}
