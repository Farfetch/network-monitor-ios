//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public extension Sequence where Iterator.Element == NSRegularExpression {

    func containsMatches(in string: String,
                         options: NSRegularExpression.MatchingOptions = []) -> Bool {

        return self.contains { regularExpression -> Bool in

            return regularExpression.firstMatch(in: string,
                                                options: options,
                                                range: NSRange(location: 0, length: string.count)) != nil
        }
    }
}

public extension Sequence where Iterator.Element == String {

    func computedRegularExpressions() throws -> [NSRegularExpression] {

        return try self.compactMap { try NSRegularExpression(pattern: $0,
                                                             options: []) }
    }
}

public extension Sequence where Iterator.Element == FNMRequestNode {

    func node(for record: FNMHTTPRequestRecord) -> FNMRequestNode? {

        guard let absoluteURLString = record.request.url?.absoluteString else { return nil }

        return self.filter { $0.expressions.containsMatches(in: absoluteURLString) }.first
    }
}

public extension Sequence where Iterator.Element == [Any] {

    func allValuesHaveEqualCounts() -> Bool {

        return Set(self.map { $0.count }).count == 1
    }
}

public extension Array where Iterator.Element == Double {

    func medianValue() -> Double? {

        guard self.count != 0 else { return nil }
        return self.reduce(0.0, +) / Double(self.count)
    }
}

public extension NSData {

    convenience init?(inputStream: InputStream,
                      bufferSize: Int = 4096) {

        guard let data = NSMutableData(capacity: bufferSize) else { return nil }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        inputStream.open()

        while inputStream.hasBytesAvailable {

            let read = inputStream.read(buffer, maxLength: bufferSize)

            if read == 0 {

                break
            }

            data.append(buffer, length: read)
        }

        buffer.deallocate()

        inputStream.close()

        self.init(data: data as Data)
    }
}

public extension HTTPURLResponse {

    func isSuccessful() -> Bool {

        return 200...399 ~= self.statusCode
    }
}

public extension NSString {

    func rangesOfSubstring(_ substring: NSString) -> [NSRange] {

        var ranges = [NSRange]()

        var enclosingRange = NSRange(location: 0,
                                     length: self.length)

        while enclosingRange.location < self.length {

            enclosingRange.length = self.length - enclosingRange.location

            let foundRange = self.range(of: substring as String,
                                        options: [.caseInsensitive],
                                        range: enclosingRange)

            if foundRange.location != NSNotFound {

                enclosingRange.location = foundRange.location + foundRange.length

                ranges.append(foundRange)

            } else {

                // no more substring to find
                break
            }
        }

        return ranges
    }
}

extension String {
    
    var unescaped: String {
        
        let entities = ["\t": "\\t", "\n": "\\n", "\r": "\\r"]

        return entities.reduce(self) { string, entity in
            
            string.replacingOccurrences(of: entity.value, with: entity.key)
        }
    }
}

extension Dictionary where Key == String, Value == String {

    func contains(pair: (key: Key, value: Value)) -> Bool {

        return self.contains { return pair.key == $0.key && pair.value == $0.value }
    }

    func contains(otherDictionary: [Key: Value]) -> Bool {

        return otherDictionary.filter { (pair) -> Bool in return self.contains(pair: pair) == false }.count == 0
    }
}

public extension Decodable {

    static func decodedElements<T: Decodable>(from bundle: Bundle,
                                              filename: String) -> [T] {

        if let fileURL = bundle.url(forResource: filename,
                                    withExtension: "json") {

            do {

                let JSONData = try Data(contentsOf: fileURL) as Data

                let profiles = try JSONDecoder().decode([T].self,
                                                        from: JSONData)

                return profiles

            } catch {

                print("Failed To Decode Elements With Error: \(error)")
            }
        }

        return []
    }
}

extension Int {

    var byteString: String {

        return ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}

extension URLRequest {
    
    var contentLength: Int {

        return Int(self.allHTTPHeaderFields?["Content-Length"] ?? "") ?? 0
    }
}

extension URLResponse {

    var isImage: Bool {

        return self.mimeType?.hasPrefix("image") ?? false
    }
}

// Profile Matching
extension NSURLRequest {

    enum ProfileMatchingResult {

        case noDataSource
        case noAvailableProfiles
        case noMatchedProfiles(profileRequestMatchingResults: [FNMProfile.ProfileRequestMatchingResult])
        case noAvailableProfileResponse(profile: FNMProfile)
        case matchedProfileAndResponse(profile: FNMProfile, response: FNMProfileResponse)

        func prettyPrinted(for request: URLRequest) -> String {

            switch self {
            case .noDataSource: return "❌ No dataSource for \(String(describing: request.url?.absoluteString))"
            case .noAvailableProfiles: return "❌ No available profiles for \(String(describing: request.url?.absoluteString))"
            case .noMatchedProfiles(let results): return "❌ No matched profile: \(results.prettyPrinted(for: request))"
            case .noAvailableProfileResponse(let profile): return "❌ Matched profile but response was unavailable \(profile.request.urlPattern)"
            case .matchedProfileAndResponse(let profile, let response): return "✅ Matched profile and response for \(String(describing: request.url?.absoluteString)):\n\(profile) => \(profile.request.urlPattern)\n👇\n\(String(describing: response.jsonResponse()))"
            }
        }
    }

    func profileMatchingResult(dataSource: FNMNetworkMonitorURLProtocolDataSourceProfile?) -> ProfileMatchingResult {

        guard let dataSource = dataSource else {

            return .noDataSource
        }

        guard dataSource.availableProfiles().count > 0 else {

            return .noAvailableProfiles
        }

        let individualProfileRequestMatchingResults = dataSource.availableProfiles(sorted: true).map { profile -> FNMProfile.ProfileRequestMatchingResult in return profile.matches(self) }

        let firstAvailableProfile = individualProfileRequestMatchingResults.compactMap { (result) -> FNMProfile? in

            switch result {
            case .hit(let profile, _):
                return profile
            default:
                return nil
            }

            }.first

        guard let availableProfile = firstAvailableProfile else {

            return .noMatchedProfiles(profileRequestMatchingResults: individualProfileRequestMatchingResults)
        }

        let appropriateProfileResponse = availableProfile.appropriateResponse(allowable: dataSource.availableProfileResponseAllowable(),
                                                                              request: self)

        guard let availableProfileResponse = appropriateProfileResponse else {

            return .noAvailableProfileResponse(profile: availableProfile)
        }

        return .matchedProfileAndResponse(profile: availableProfile,
                                          response: availableProfileResponse)
    }
}
