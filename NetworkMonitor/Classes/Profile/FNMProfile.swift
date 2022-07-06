//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public typealias FNMProfileResponseAllowable = (FNMProfileResponse) -> Bool

open class FNMProfile: NSObject, Codable {

    let request: FNMProfileRequest
    let responses: [FNMProfileResponse]

    /// Priority is used as a tiebreaker when we have several possible profiles for the request made.
    /// The profile with the highest priority (Uint.min [aka 0] being the highest value and UInt.max the lowest value) will be used.
    let priority: UInt

    public required init(request: FNMProfileRequest,
                         responses: [FNMProfileResponse],
                         priority: UInt = UInt.min) {

        self.request = request
        self.responses = responses
        self.priority = priority
    }

    convenience init?(record: FNMHTTPRequestRecord) {

        // Must have a valid URL
        guard let url = record.request.url?.absoluteString else { return nil }

        // Must have a valid method
        guard let requestHTTPMethod = record.request.httpMethod,
            let requestMethod = FNMHTTPMethod(rawValue: requestHTTPMethod.uppercased()) else { return nil }

        // Must have a valid conclusion with meta
        guard let conclusion = record.conclusion,
            case .completed(let loadState, let meta, let response) = conclusion,
            case .network(_) = loadState,
            let unwrappedMeta = meta else { return nil }

        let profileRequest = FNMProfileRequest(urlPattern: .staticPattern(url: url),
                                               httpMethod: requestMethod,
                                               headers: record.request.allHTTPHeaderFields,
                                               body: record.request.httpBody)

        let responses = [FNMProfileResponse(identifier: ProcessInfo.processInfo.globallyUniqueString,
                                            meta: FNMHTTPURLResponse(meta: unwrappedMeta),
                                            response: response,
                                            repeatability: .unlimited,
                                            delay: 0.0)]

        self.init(request: profileRequest,
                  responses: responses)
    }

    open func appropriateResponse(allowable: FNMProfileResponseAllowable,
                                  request: NSURLRequest) -> FNMProfileResponse? {

        return self.firstUsableResponse(allowable: allowable)
    }

    open func appropriateData(from response: FNMProfileResponse,
                              request: NSURLRequest) -> Data? {

        return response.response
    }

    // Codable Conformance
    // Needs to be here because of non final class
    enum CodingKeys: String, CodingKey {

        case request
        case responses
        case priority
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.request, forKey: .request)
        try container.encode(self.responses, forKey: .responses)
        try container.encode(self.priority, forKey: .priority)
    }

    public convenience required init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)

        do {

            let priority = try values.decodeIfPresent(UInt.self, forKey: .priority) ?? UInt.min

            try self.init(request: values.decode(FNMProfileRequest.self, forKey: .request),
                          responses: values.decode([FNMProfileResponse].self, forKey: .responses),
                          priority: priority)
        }
    }
}

extension FNMProfile {

    enum ProfileRequestMatchingResult {

        enum ProfileRequestMatchingResultMissReason {

            case url(prospectRequestURLString: String?, profileUrlPattern: FNMRequestURLPattern)
            case method(prospectRequestHttpMethod: String?, profileHttpMethod: FNMHTTPMethod)
            case headers(prospectHeaders: [String: String]?, profileHeaders: [String: String])
            case body(prospectBody: Data?, profileBody: Data)

            func prettyPrinted() -> String {

                switch self {
                case .url(let prospectPattern, let currentPattern): return "❗️ URL \(String(describing: prospectPattern)) failed to match \(currentPattern)"
                case .method(let prospectMethod, let currentMethod): return "❗️ Method \(String(describing: prospectMethod)) failed to match \(currentMethod)"
                case .headers(let prospectHeaders, let currentHeaders): return "❗️ Headers \(String(describing: prospectHeaders)) failed to match \(currentHeaders)"
                case .body(let prospectBody, let currentBody): return "❗️ Body \(String(describing: prospectBody?.count)) failed to match \(currentBody.count)"
                }
            }
        }

        case hit(profile: FNMProfile, request: NSURLRequest)
        case miss(profile: FNMProfile, request: NSURLRequest, reason: ProfileRequestMatchingResultMissReason)
    }

    func matches(_ prospectRequest: NSURLRequest) -> ProfileRequestMatchingResult {

        // Prospect Matches URL
        guard let prospectRequestURLString = prospectRequest.url?.absoluteString,
            self.request.urlPattern.matches(urlString: prospectRequestURLString) == true
            else { return .miss(profile: self,
                                request: prospectRequest,
                                reason: .url(prospectRequestURLString: prospectRequest.url?.absoluteString,
                                             profileUrlPattern: self.request.urlPattern)) }

        // Prospect Matches Method
        guard let prospectRequestHttpMethod = prospectRequest.httpMethod,
            self.request.httpMethod.matches(httpMethodString: prospectRequestHttpMethod) == true
            else { return .miss(profile: self,
                                request: prospectRequest,
                                reason: .method(prospectRequestHttpMethod: prospectRequest.httpMethod,
                                                profileHttpMethod: self.request.httpMethod)) }

        // Prospect Includes Headers, if they exist
        if let headers = self.request.headers,
            headers.count != 0 {

            guard let prospectHeaders = prospectRequest.allHTTPHeaderFields,
                prospectHeaders.contains(otherDictionary: headers)
                else { return .miss(profile: self,
                                    request: prospectRequest,
                                    reason: .headers(prospectHeaders: prospectRequest.allHTTPHeaderFields,
                                                     profileHeaders: headers)) }
        }

        // Prospect Includes Body, if it exists
        if let body = self.request.body {

            guard let prospectBody = prospectRequest.httpBody,
                prospectBody.range(of: body) != nil
                else { return .miss(profile: self,
                                    request: prospectRequest,
                                    reason: .body(prospectBody: prospectRequest.httpBody,
                                                  profileBody: body)) }
        }

        return .hit(profile: self,
                    request: prospectRequest)
    }

    func firstUsableResponse(allowable: FNMProfileResponseAllowable) -> FNMProfileResponse? {

        let usableResponses = self.responses.filter {

            switch $0.repeatability {
            case .unlimited:
                return true
            case .limited:
                return allowable($0)
            }
        }

        return usableResponses.first
    }
}

extension Sequence where Iterator.Element == FNMProfile.ProfileRequestMatchingResult {

    func prettyPrinted(for request: URLRequest) -> String {

        var prettyPrint = "● \(String(describing: request.url?.absoluteString)) ● \n"

        self.forEach { result in

            switch result {
            case .hit(let profile, let request): prettyPrint.append("Hit between \(profile) and \(request)")
            case .miss(let profile, _, let reason): prettyPrint.append("Miss for \(profile) because \(reason.prettyPrinted())")
            }

            prettyPrint.append("\n")
        }

        prettyPrint.append("\n●")

        return prettyPrint
    }
}

public final class FNMProfileRequest: NSObject {

    let urlPattern: FNMRequestURLPattern
    let httpMethod: FNMHTTPMethod
    let headers: [String: String]?
    let body: Data?

    public init(urlPattern: FNMRequestURLPattern,
                httpMethod: FNMHTTPMethod = .get,
                headers: [String: String]? = nil,
                body: Data? = nil) {

        self.urlPattern = urlPattern
        self.httpMethod = httpMethod
        self.headers = headers
        self.body = body
    }
}

public enum FNMRequestURLPattern {

    case staticPattern(url: String)
    case dynamicPattern(expression: String)

    private var patternRepresentation: String {

        switch self {

        case .staticPattern(let url):
                return url

        case .dynamicPattern(let expression):
                return expression
        }
    }

    var representation: URL? {

        guard let representation = URL(string: self.patternRepresentation) else {

            return URL(string: "https://www.unable.to.create.proper.url.from.pattern")
        }

        return representation
    }

    func matches(urlString: String) -> Bool {

        switch self {
        case .staticPattern(let urlStringPattern):
            return urlString == urlStringPattern
        case .dynamicPattern(let expressionString):

            do {

                let expression = try NSRegularExpression(pattern: expressionString,
                                                         options: [])

                return expression.firstMatch(in: urlString,
                                             options: [],
                                             range: NSRange(location: 0, length: urlString.count)) != nil

            } catch {

                print("Could not create the regular expression for '\(expressionString)'")
            }

            return false
        }
    }
}

extension FNMRequestURLPattern: Equatable {

    public static func == (lhs: FNMRequestURLPattern, rhs: FNMRequestURLPattern) -> Bool {

        switch (lhs, rhs) {

        case let (.staticPattern(urlStringPatternLHS), .staticPattern(urlStringPatternRHS)):
            return urlStringPatternLHS == urlStringPatternRHS
        case let (.dynamicPattern(expressionStringLHS), .dynamicPattern(expressionStringRHS)):
            return expressionStringLHS == expressionStringRHS
        default:
            return false
        }
    }
}

public enum FNMHTTPMethod: String {

    case delete = "DELETE"
    case get = "GET"
    case head = "HEAD"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"

    func matches(httpMethodString: String) -> Bool {

        return self.rawValue == httpMethodString.uppercased()
    }
}

public enum FNMResponseRepeatability {

    case unlimited
    case limited(numberOfUsesTotal: UInt)
}

extension FNMResponseRepeatability: Equatable {

    public static func == (lhs: FNMResponseRepeatability, rhs: FNMResponseRepeatability) -> Bool {

        switch (lhs, rhs) {

        case (.unlimited, .unlimited):
            return true
        case let (.limited(usesLHS), .limited(usesRHS)):
            return usesLHS == usesRHS
        default:
            return false
        }
    }
}

public final class FNMProfileResponse: NSObject {

    let identifier: String

    let meta: FNMHTTPURLResponse
    let response: Data?
    let redirectionURL: URL?

    var repeatability: FNMResponseRepeatability
    let delay: TimeInterval

    public init(identifier: String,
                meta: FNMHTTPURLResponse,
                response: Data? = nil,
                redirectionURL: URL? = nil,
                repeatability: FNMResponseRepeatability,
                delay: TimeInterval) {

        self.identifier = identifier
        self.meta = meta
        self.response = response
        self.redirectionURL = redirectionURL
        self.repeatability = repeatability
        self.delay = delay
    }
}

public extension FNMProfileRequest {

    private enum Constants {

        static let jsonType = "json"
    }

    enum ResponseHolder {

        case keyValue(value: [String: Any])
        case values(values: [[String: Any]])
        case json(filename: String, bundle: Bundle)
        case raw(value: Data)

        var innerValue: Data? {

            switch self {
            case .keyValue(let value): return try? JSONSerialization.data(withJSONObject: value,
                                                                          options: .prettyPrinted)
            case .values(let values): return try? JSONSerialization.data(withJSONObject: values,
                                                                         options: .prettyPrinted)
            case .json(let filename, let bundle):
                guard let path = bundle.path(forResource: filename,
                                             ofType: Constants.jsonType) else { return nil }
                return try? Data(contentsOf: URL(fileURLWithPath: path))
            case .raw(let value): return value
            }
        }
    }

    func response(identifier: String = ProcessInfo.processInfo.globallyUniqueString,
                  statusCode: Int = 200,
                  headers: [String: String] = [:],
                  responseHolder: ResponseHolder? = nil,
                  redirectionURL: URL? = nil,
                  repeatability: FNMResponseRepeatability = .unlimited,
                  delay: TimeInterval = 0.0) -> FNMProfileResponse {

        guard let url = self.urlPattern.representation,
            let meta = HTTPURLResponse(url: url,
                                       statusCode: statusCode,
                                       httpVersion: FNMHTTPURLResponse.Constants.httpVersion,
                                       headerFields: headers) else {

            preconditionFailure("Meta object couldnt be created for unknown reasons, please advise")
        }

        return FNMProfileResponse(identifier: identifier,
                                  meta: FNMHTTPURLResponse(meta: meta),
                                  response: responseHolder?.innerValue,
                                  redirectionURL: redirectionURL,
                                  repeatability: repeatability,
                                  delay: delay)
    }
}

public extension FNMProfileResponse {

    func jsonResponse() -> String? {

        guard let response = self.response else { return nil }

        return String(data: response,
                      encoding: .utf8)
    }

    func patchedResponse(unpatchedString: String,
                         patchedString: String) -> Data? {

        return self.jsonResponse()?.replacingOccurrences(of: unpatchedString,
                                                         with: patchedString).data(using: .utf8)
    }
}

public final class FNMHTTPURLResponse: NSObject {

    let meta: HTTPURLResponse

    init(meta: HTTPURLResponse) {

        self.meta = meta
    }

    func hydratedMeta(with url: URL?) -> HTTPURLResponse? {

        guard let url = url,
            let headers = self.meta.allHeaderFields as? [String: String] else { return nil }

        return HTTPURLResponse(url: url,
                               statusCode: self.meta.statusCode,
                               httpVersion: FNMHTTPURLResponse.Constants.httpVersion,
                               headerFields: headers)
    }
}
