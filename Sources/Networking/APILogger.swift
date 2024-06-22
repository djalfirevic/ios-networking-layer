//
//  APILogger.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

public struct APILogger {

    // MARK: - Public API

    public static var isLoggingEnabled = true

    public static func logDataResponse<T>(_ response: DataResponse<T>) {
        guard Self.isLoggingEnabled else { return }
        
        var console = ""

        if let url = response.request?.url?.absoluteString.removingPercentEncoding, let method = response.request?.httpMethod {
            var requestURL = url
            if requestURL.last == "?" {
                requestURL.removeLast()
            }
            console.append("🚀 \(method) \(requestURL)")
        }

        if let headers = response.request?.allHTTPHeaderFields, headers.count > 0 {
            // let headers = headers.map({ "\($0.key): \($0.value)" }).joined(separator: "\n   ")
            let headers = headers
                .map { item in
                    if item.value.hasPrefix("Bearer") {
                        return "\(item.key): \(item.value.prefix(15))..."
                    }

                    return "\(item.key): \(item.value)"
                }
                .joined(separator: "\n   ")
            console.append("\n🤯 \(headers)")
        }

        if let body = response.request?.httpBody, let body = String(data: body, encoding: String.Encoding.utf8), body.count > 0 {
            console.append("\n📤 \(body)")
        }

        if let response = response.response {
            switch response.statusCode {
            case 200 ..< 300:
                console.append("\n✅ \(response.statusCode)")
            default:
                console.append("\n❌ \(response.statusCode)")
            }
        }

        if let data = response.data, let payload = String(data: data, encoding: String.Encoding.utf8), payload.count > 0 {
            console.append("\n📦 \(payload)")
        }

        if let error = response.error as NSError? {
            console.append("\n‼️ [\(error.domain) \(error.code)] \(error.localizedDescription)")
        } else if let error = response.error {
            console.append("\n‼️ \(error.localizedDescription)")
        }

        print(console)
    }
}
