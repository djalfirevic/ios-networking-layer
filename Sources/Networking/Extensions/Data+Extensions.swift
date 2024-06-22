//
//  Data+Extensions.swift
//  Networking
//
//  Created by Djuro on 6/22/24.
//

import Foundation

extension Data {

    // MARK: - Initialization

    public init?(
        multipartFilename filename: String,
        data fileData: Data,
        fileContentType: String,
        formData: [String: String] = [:],
        boundary: String
    ) {
        self.init()

        var formFields = formData
        formFields["content-type"] = fileContentType
        formFields.forEach { key, value in
            append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            append("\(value)".data(using: .utf8)!)
        }

        append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(fileContentType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)

        append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    }
}
