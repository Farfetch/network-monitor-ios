//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

typealias Headers = [FNMTitleSubtitlePair]
typealias Body = FNMBody

struct FNMTitleSubtitlePair: Encodable {

    let title: String
    let subtitle: String
}

enum FNMContentType: Encodable {
    
    case text(data: String)
    case image(data: UIImage)
    
    enum CodingKeys: CodingKey {
        case type
        case value
    }
    
    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let data):

            try container.encode("text", forKey: .type)
            try container.encode(data, forKey: .value)
            
        case .image(_):
            
            try container.encode("image", forKey: .type)
            try container.encode("N/A", forKey: .value)
        }
    }
}

struct FNMBody: Encodable {

    let title: String
    let contentType: FNMContentType
}

final class FNMRecordDetailInfo: Encodable {

    enum Constants {

        static let requestBodyTitle = "Request Body"
        static let responseBodyTitle = "Response"
    }

    let record: FNMHTTPRequestRecord
    let requestHeaders: Headers
    let requestBody: Body
    let responseHeaders: Headers
    let responseBody: Body

    init(record: FNMHTTPRequestRecord) {

        self.record = record
        self.requestHeaders = type(of: self).requestHeaders(from: record)
        self.responseHeaders = type(of: self).responseHeaders(from: record)
        self.requestBody = type(of: self).requestBody(from: record)
        self.responseBody = type(of: self).responseBody(from: record)
    }

    static func requestHeaders(from record: FNMHTTPRequestRecord) -> Headers {

        return record.request.allHTTPHeaderFields?.compactMap { (pair) -> FNMTitleSubtitlePair? in FNMTitleSubtitlePair(title: pair.key, subtitle: pair.value) } ?? Headers()
    }

    static func responseHeaders(from record: FNMHTTPRequestRecord) -> Headers {

        if let conclusion = record.conclusion,
            case FNMHTTPRequestRecordConclusionType.completed(_, let response, _) = conclusion {

            return response?.allHeaderFields.compactMap { (pair) -> FNMTitleSubtitlePair? in

                guard let key = pair.key as? String,
                    let value = pair.value as? String else { return nil }

                return FNMTitleSubtitlePair(title: key, subtitle: value) } ?? Headers()
        }

        return Headers()
    }

    static func requestBody(from record: FNMHTTPRequestRecord) -> Body {

        let subtitle: String
        let bodyData: Data?

        if let httpBody = record.request.httpBody {

            bodyData = httpBody

        } else if let httpBody = URLProtocol.property(forKey: FNMNetworkMonitorURLProtocol.GeneralConstants.bodyKey,
                                                      in: record.request as URLRequest) as? Data {

            bodyData = httpBody

        } else if let httpBodyStream = record.request.httpBodyStream,
            let httpBodyStreamData = NSData(inputStream: httpBodyStream) as Data? {

            bodyData = httpBodyStreamData

        } else if let httpBodyStream = URLProtocol.property(forKey: FNMNetworkMonitorURLProtocol.GeneralConstants.bodyStreamKey,
                                                            in: record.request as URLRequest) as? InputStream,
            let httpBodyStreamData = NSData(inputStream: httpBodyStream) as Data? {

            bodyData = httpBodyStreamData

        } else {

            bodyData = nil
        }

        if let bodyData = bodyData,
            let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) {

            subtitle = String(describing: json)

        } else if let bodyData = bodyData,
            let description = String(data: bodyData, encoding: .utf8) {

            subtitle = description

        } else {

            subtitle = "N/A"
        }

        return Body(title: Constants.requestBodyTitle, contentType: .text(data: subtitle.unescaped))
    }

    static func responseBody(from record: FNMHTTPRequestRecord) -> Body {

        let subtitle: String
        let bodyData: Data?

        if let conclusion = record.conclusion,
            case FNMHTTPRequestRecordConclusionType.completed(_, _, let data) = conclusion,
            let unwrappedData = data {

            bodyData = unwrappedData

        } else {

            bodyData = nil
        }

        if let bodyData = bodyData,
            let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) {

            subtitle = String(describing: json)

        } else if let bodyData = bodyData,
            let description = String(data: bodyData, encoding: .utf8) {

            subtitle = description

        } else if let conclusion = record.conclusion,
            case FNMHTTPRequestRecordConclusionType.clientError(let error) = conclusion {

            subtitle = error.debugDescription

        } else if let bodyData = bodyData,
            let image = UIImage(data: bodyData) {

            return Body(title: Constants.responseBodyTitle, contentType: .image(data: image))

        } else {

            subtitle = "N/A"
        }

        return Body(title: Constants.responseBodyTitle, contentType: .text(data: subtitle))
    }
}

final class RecordHeaderDetailInfo {

    let record: FNMHTTPRequestRecord
    let requestHeaders: Headers
    let responseHeaders: Headers

    init(record: FNMHTTPRequestRecord,
         requestHeaders: Headers,
         responseHeaders: Headers) {

        self.record = record
        self.requestHeaders = requestHeaders
        self.responseHeaders = responseHeaders
    }
}

final class RecordBodyDetailInfo {

    let record: FNMHTTPRequestRecord
    let body: Body

    init(record: FNMHTTPRequestRecord,
         body: Body) {

        self.record = record
        self.body = body
    }
}
