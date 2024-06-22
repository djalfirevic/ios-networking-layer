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
        if !Reachability.isConnectedToNetwork() {
            return AnyPublisher(Fail<T, APIError>(error: APIError.error(reason: "Please provide Internet connection")))
        }

        let components = buildURL(endpoint: endpoint)
        guard let url = components.url else {
            return AnyPublisher(Fail<T, APIError>(error: APIError.invalidURL))
        }

        let urlRequest = createRequest(url: url, endpoint: endpoint)

        return session.dataTaskPublisher(for: urlRequest)
            .retry(1)
            .receive(on: DispatchQueue.main)
            .tryMap { data, response in
                let dataResponse = DataResponse<Bool>(
                    request: urlRequest,
                    response: response as? HTTPURLResponse,
                    result: .success(true),
                    data: data
                )
                APILogger.logDataResponse(dataResponse)

                let decoder = JSONDecoder()

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-mm-dd"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)

                if let httpResponse = response as? HTTPURLResponse {
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

                return try decoder.decode(T.self, from: data)
            }
            .mapError { error in
                if let error = error as? APIError {
                    return error
                } else {
                    return APIError.error(reason: error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }

    /// Executes the web call and will decode the JSON response into the Codable object provided.
    /// - Parameters:
    ///   - endpoint: the endpoint to make the HTTP request against
    ///   - completion: completion handler
    public func request<T: Decodable>(endpoint: API, _ completion: @escaping (Result<T, APIError>) -> Void) {
        if !Reachability.isConnectedToNetwork() {
            completion(.failure(APIError.error(reason: "Please provide Internet connection")))
            return
        }

        let components = buildURL(endpoint: endpoint)
        guard let url = components.url else {
            completion(.failure(APIError.invalidURL))
            return
        }

        // Create URLRequest.
        let urlRequest = createRequest(url: url, endpoint: endpoint)

        session.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                let dataResponse = DataResponse<Bool>(
                    request: urlRequest,
                    response: response as? HTTPURLResponse,
                    result: .success(true),
                    data: data
                )
                APILogger.logDataResponse(dataResponse)

                if let httpResponse = response as? HTTPURLResponse {
                    let responseStatus = ResponseStatus(statusCode: httpResponse.statusCode)
                    switch responseStatus {
                    case .unauthorized:
                        completion(.failure(APIError.unauthorized))
                    case .clientError, .serverError:
                        completion(.failure(APIError.error(reason: "Server error")))
                    default:
                        break
                    }
                }

                if let error {
                    completion(.failure(APIError.error(reason: error.localizedDescription)))
                    return
                }

                if let data {
                    let decoder = JSONDecoder()

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-mm-dd"
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)

                    do {
                        let object = try decoder.decode(T.self, from: data)
                        completion(.success(object))
                    } catch {
                        completion(.failure(APIError.error(reason: error.localizedDescription)))
                    }
                }
            }
        }.resume()
    }

    /// Executes the web call and will decode the JSON response into the Codable object provided using `async`.
    /// - Parameters:
    ///   - endpoint: the endpoint to make the HTTP request against
    public func request<T: Decodable>(endpoint: API) async throws -> T {
        if !Reachability.isConnectedToNetwork() {
            throw APIError.error(reason: "Please provide Internet connection")
        }

        let components = buildURL(endpoint: endpoint)
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let urlRequest = createRequest(url: url, endpoint: endpoint)

        let (data, response) = try await session.data(for: urlRequest)

        let dataResponse = DataResponse<Bool>(
            request: urlRequest,
            response: response as? HTTPURLResponse,
            result: .success(true),
            data: data
        )
        APILogger.logDataResponse(dataResponse)

        // Handle responses with success (200, 201, ...)
        if data.isEmpty, let response = response as? HTTPURLResponse {
            let responseStatus = ResponseStatus(statusCode: response.statusCode)
            let value = responseStatus == .success
            return value as! T
        }

        let decoder = JSONDecoder()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-mm-dd"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        if let httpResponse = response as? HTTPURLResponse {
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

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw error
        }
    }

    // MARK: - Private API

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
