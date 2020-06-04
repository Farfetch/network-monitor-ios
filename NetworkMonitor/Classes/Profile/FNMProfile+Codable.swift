//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

extension FNMProfileRequest: Codable {

    enum CodingKeys: String, CodingKey {

        case urlPattern
        case httpMethod
        case headers
        case body
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.urlPattern, forKey: .urlPattern)
        try container.encode(self.httpMethod, forKey: .httpMethod)
        try container.encodeIfPresent(self.headers, forKey: .headers)

        if let body = self.body {

            try container.encode(String(data: body,
                                        encoding: .utf8),
                                 forKey: .body)
        }
    }

    public convenience init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)

        do {

            try self.init(urlPattern: values.decode(FNMRequestURLPattern.self, forKey: .urlPattern),
                          httpMethod: values.decode(FNMHTTPMethod.self, forKey: .httpMethod),
                          headers: values.decodeIfPresent([String: String].self, forKey: .headers),
                          body: values.decodeIfPresent(String.self, forKey: .body)?.data(using: .utf8))
        }
    }
}

extension FNMRequestURLPattern: Codable {

    enum CodingKeys: String, CodingKey {

        case staticPattern
        case dynamicPattern
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .staticPattern(let url):
            try container.encode(url, forKey: .staticPattern)
        case .dynamicPattern(let expression):
            try container.encode(expression, forKey: .dynamicPattern)
        }
    }

    public init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? values.decode(String.self, forKey: .staticPattern) {

            self = .staticPattern(url: value)
            return
        }

        if let value = try? values.decode(String.self, forKey: .dynamicPattern) {

            self = .dynamicPattern(expression: value)
            return
        }

        throw DecodingError.valueNotFound(FNMRequestURLPattern.self,
                                          DecodingError.Context(codingPath: [], debugDescription: "Enum was not decoded"))
    }
}

extension FNMHTTPMethod: Codable {}

extension FNMProfileResponse: Codable {

    enum CodingKeys: String, CodingKey {

        case identifier
        case meta
        case response
        case repeatability
        case delay
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.meta, forKey: .meta)
        try container.encode(self.repeatability, forKey: .repeatability)
        try container.encodeIfPresent(self.delay, forKey: .delay)

        if let response = self.response {

            try container.encode(String(data: response,
                                        encoding: .utf8),
                                 forKey: .response)
        }
    }

    public convenience init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)

        do {

            try self.init(identifier: values.decode(String.self, forKey: .identifier),
                          meta: values.decode(FNMHTTPURLResponse.self, forKey: .meta),
                          response: values.decodeIfPresent(String.self, forKey: .response)?.data(using: .utf8),
                          repeatability: values.decode(FNMResponseRepeatability.self, forKey: .repeatability),
                          delay: values.decode(TimeInterval.self, forKey: .delay))
        }
    }
}

extension FNMHTTPURLResponse: Codable {

    enum CodingKeys: String, CodingKey {

        case url
        case statusCode
        case httpVersion
        case headerFields
    }

    enum Constants {

        static let httpVersion = "HTTP/1.1"
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.meta.url, forKey: .url)
        try container.encode(self.meta.statusCode, forKey: .statusCode)
        try container.encode(Constants.httpVersion, forKey: .httpVersion)

        if let headerFields = self.meta.allHeaderFields as? [String: String] {

            try container.encode(headerFields, forKey: .headerFields)
        }
    }

    convenience public init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)

        do {

            if let response = try HTTPURLResponse(url: values.decode(URL.self, forKey: .url),
                                                  statusCode: values.decode(Int.self, forKey: .statusCode),
                                                  httpVersion: values.decode(String.self, forKey: .httpVersion),
                                                  headerFields: values.decodeIfPresent([String: String].self, forKey: .headerFields)) {

                self.init(meta: response)

            } else {

                throw DecodingError.valueNotFound(URL.self,
                                                  DecodingError.Context(codingPath: [], debugDescription: "URLResponse was not decoded properly"))
            }
        }
    }
}

extension FNMResponseRepeatability: Codable {

    enum CodingKeys: String, CodingKey {

        case base
        case numberOfUsesTotal
    }

    enum Base: String, Codable {

        case unlimited
        case limited
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .unlimited:
            try container.encode(Base.unlimited, forKey: .base)
        case .limited(let numberOfUsesTotal):
            try container.encode(Base.limited, forKey: .base)
            try container.encode(numberOfUsesTotal, forKey: .numberOfUsesTotal)
        }
    }

    public init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)
        let base = try values.decode(Base.self, forKey: .base)

        switch base {
        case .unlimited:
            self = .unlimited
        case .limited:
            let numberOfUsesTotal = try values.decode(UInt.self, forKey: .numberOfUsesTotal)
            self = .limited(numberOfUsesTotal: numberOfUsesTotal)
        }
    }
}
