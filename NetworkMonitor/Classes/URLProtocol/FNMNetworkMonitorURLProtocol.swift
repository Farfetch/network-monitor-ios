//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public enum FNMNetworkMonitorURLProtocolLoadState {

    case unloaded
    case network(dataTask: URLSessionDataTask)
    case profile(profile: FNMProfile, responseUsed: FNMProfileResponse)
}

@objc
final class FNMNetworkMonitorURLProtocol: URLProtocol {

    static var active = false
    static var recordMediaPayload = true
    
    static weak var dataSource: FNMNetworkMonitorURLProtocolDataSource?

    // The load state that represents the current request
    private var loadState = FNMNetworkMonitorURLProtocolLoadState.unloaded

    // Convenience getter for the current record
    var requestRecord: FNMHTTPRequestRecord?

    // Convenience getter for the current record
    var dataDownloaded: Data?

    // Session used to run the tasks
    lazy var session: URLSession = {

        let config = URLSessionConfiguration.default

        // Our own swizzling just added our own class to the protocol classes of this session, so remove it to avoid duplication
        config.protocolClasses = config.protocolClasses?.filter { (URLProtocol) -> Bool in

            return URLProtocol != FNMNetworkMonitorURLProtocol.self
        }

        return URLSession(configuration: config,
                          delegate: self,
                          delegateQueue: nil)
    }()

    public static func activate(dataSource: FNMNetworkMonitorURLProtocolDataSource?) {

        self.dataSource = dataSource
        self.active = true
    }

    public static func deactivate() {

        self.active = false
    }
}

extension FNMNetworkMonitorURLProtocol {

    override public static func canonicalRequest(for request: URLRequest) -> URLRequest {

        return request
    }

    override public static func canInit(with request: URLRequest) -> Bool {

        return self.canMonitorRequest(request)
    }

    override public static func canInit(with task: URLSessionTask) -> Bool {

        guard let request = task.currentRequest else { return false }
        return self.canMonitorRequest(request)
    }

    override public func startLoading() {

        // Tag the request
        guard let taggedRequest = FNMNetworkMonitorURLProtocol.taggedNormalized(self.request as NSURLRequest) else {

            assertionFailure()
            return
        }

        // Create a record and a key
        self.requestRecord = FNMNetworkMonitorURLProtocol.requestRecord(for: ProcessInfo.processInfo.globallyUniqueString,
                                                                        request: taggedRequest)

        guard let requestRecord = self.requestRecord else {

            assertionFailure()
            return
        }

        self.requestRecord?.requestSize = self.request.contentLength

        // Save
        FNMNetworkMonitorURLProtocol.dataSource?.setRequestRecord(requestRecord: requestRecord,
                                                                  completion: { })

        FNMLogger.log(message: "Starting Request '\(taggedRequest.url?.absoluteString ?? "")'",
                      scope: .urlProtocol)

        // See whether we should use a profile or send this request to the network

        let profileMatchingResult = taggedRequest.profileMatchingResult(dataSource: FNMNetworkMonitorURLProtocol.dataSource)

        FNMLogger.log(message: "Request Matching Resulted In '\(profileMatchingResult.prettyPrinted(for: self.request))'",
                      scope: .profile)

        if case let NSURLRequest.ProfileMatchingResult.matchedProfileAndResponse(profile, response) = profileMatchingResult {

            // Profile available

            FNMLogger.log(message: "Loading Request From Profile '\(taggedRequest.url?.absoluteString ?? "")'",
                          scope: .profile)

            let normalizedMeta = response.meta.hydratedMeta(with: taggedRequest.url) ?? response.meta.meta

            // Track this usage
            FNMNetworkMonitorURLProtocol.dataSource?.bumpUses(for: response.identifier)

            self.loadState = .profile(profile: profile,
                                      responseUsed: response)

            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, response.delay)) {

                self.handleDataTaskInitialResponse(request: taggedRequest as URLRequest,
                                                   response: normalizedMeta,
                                                   completionHandler: { _ in })

                if let responseData = profile.appropriateData(from: response,
                                                              request: taggedRequest) {

                    self.handleDataArrival(data: responseData)
                }

                if let redirectionURL = response.redirectionURL {

                    self.handleRedirection(newRequest: URLRequest(url: redirectionURL),
                                           response: normalizedMeta) { _ in }

                } else {

                    self.handleDataTaskCompletion(response: normalizedMeta,
                                                  error: nil)
                }
            }

        } else {

            // No profile available for this request, dispatch the task

            FNMLogger.log(message: "Loading Request From Network '\(taggedRequest.url?.absoluteString ?? "")'",
                          scope: .urlProtocol)

            let monitoredTask = self.session.dataTask(with: taggedRequest as URLRequest)
            monitoredTask.resume()

            self.loadState = .network(dataTask: monitoredTask)
        }
    }

    override public func stopLoading() {

        if self.requestRecord?.conclusion == nil,
            case let .network(dataTask) = self.loadState {

            dataTask.cancel()

            FNMLogger.log(message: "Cancelled Request '\(dataTask.currentRequest?.url?.absoluteString ?? "")'",
                          scope: .urlProtocol)
        }
    }
}

extension FNMNetworkMonitorURLProtocol: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {

        self.handleRedirection(newRequest: request,
                               response: response,
                               completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        self.handleDataTaskInitialResponse(request: dataTask.originalRequest,
                                           response: response,
                                           completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive data: Data) {

        self.handleDataArrival(data: data)
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {

        self.handleDataTaskCompletion(response: task.response,
                                      error: error)

        session.finishTasksAndInvalidate()
    }
}

// Network Handling
extension FNMNetworkMonitorURLProtocol {

    func handleRedirection(newRequest: URLRequest,
                           response: HTTPURLResponse,
                           completionHandler: @escaping (URLRequest?) -> Void) {

        // Untag the request
        guard let requestRecord = self.requestRecord,
            let untaggedRequest = FNMNetworkMonitorURLProtocol.untagged(newRequest as NSURLRequest,
                                                                        redirectRecordKey: requestRecord.key) else {

               assertionFailure()
               return
        }

        // Conclude the record now
        self.concludeRecordIfNeeded(conclusion: .redirected(newRequest: newRequest as NSURLRequest))

        // Allow the client to redirect
        self.client?.urlProtocol(self, wasRedirectedTo: untaggedRequest as URLRequest, redirectResponse: response)

        if case let .network(dataTask) = self.loadState {

            dataTask.cancel()
        }

        self.client?.urlProtocol(self, didFailWithError: NSError(domain: NSCocoaErrorDomain,
                                                                 code: NSUserCancelledError,
                                                                 userInfo: nil))

        completionHandler(newRequest)

        FNMLogger.log(message: "Handled Redirection From Request '\(requestRecord.request.url?.absoluteString ?? "")'\nto Request '\(newRequest.url?.absoluteString ?? "")'",
                      scope: .urlProtocol)
    }

    func handleDataTaskInitialResponse(request: URLRequest?,
                                       response: URLResponse,
                                       completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        let cacheStoragePolicy: URLCache.StoragePolicy

        if let httpResponse = response as? HTTPURLResponse,
            let request = request {

            cacheStoragePolicy = FNMNetworkMonitorURLProtocol.inferredCachePolicy(from: request,
                                                                                  and: httpResponse)

        } else {

            cacheStoragePolicy = .notAllowed
        }

        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: cacheStoragePolicy)

        completionHandler(.allow)

        FNMLogger.log(message: "Handled Initial Response From Request '\(request?.url?.absoluteString ?? "")'",
                      scope: .urlProtocol)
    }

    func handleDataArrival(data: Data) {

        if self.dataDownloaded != nil {

            self.dataDownloaded?.append(data)

        } else {

            self.dataDownloaded = data
        }

        self.client?.urlProtocol(self,
                                 didLoad: data)

        FNMLogger.log(message: "Handled Data Arrival From Request '\(self.requestRecord?.request.url?.absoluteString ?? "")'",
                      scope: .urlProtocol)
    }

    func handleDataTaskCompletion(response: URLResponse?,
                                  error: Error?) {

        if let error = error as NSError? {

            self.concludeRecordIfNeeded(conclusion: .clientError(error: error))

            if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {

                // Do nothing.  This happens in two cases:
                // o during a redirect, in which case the redirect code has already told the client about
                //   the failure
                // o if the request is cancelled by a call to -stopLoading, in which case the client doesn't
                //   want to know about the failure

            } else {

                self.client?.urlProtocol(self, didFailWithError: error)

                FNMLogger.log(message: "Handled Error For Request '\(self.requestRecord?.request.url?.absoluteString ?? "")'",
                              scope: .urlProtocol)
            }

        } else {

            self.requestRecord?.responseSize = self.dataDownloaded?.count ?? 0

            let shouldSkipData = Self.recordMediaPayload == false && response?.isImage == true

            self.concludeRecordIfNeeded(conclusion: .completed(URLProtocolLoadState: self.loadState,
                                                               response: response as? HTTPURLResponse,
                                                               data: shouldSkipData ? nil : self.dataDownloaded))

            self.client?.urlProtocolDidFinishLoading(self)

            FNMLogger.log(message: "Handled Conclusion \((response as? HTTPURLResponse)?.statusCode ?? 0) For Request '\(self.requestRecord?.request.url?.absoluteString ?? ""))'",
                          scope: .urlProtocol)
        }
    }
}

// Generic
extension FNMNetworkMonitorURLProtocol {

    enum GeneralConstants {

        static let tagKey = "com.farfetch.NetworkMonitor.tag"
        static let bodyKey = "com.farfetch.NetworkMonitor.body"
        static let bodyStreamKey = "com.farfetch.NetworkMonitor.bodyStream"
        static let http = "http"
        static let https = "https"
        static let cacheControlKey = "Cache-Control"
        static let cacheControlValueNoStore = "no-store"
        static let cacheControlValueNoCache = "no-cache"
    }
}

// Request tagging
private extension FNMNetworkMonitorURLProtocol {

    private enum AllowedURLScheme {

        static func allAllowedSchemes() -> [String] { return [ GeneralConstants.http, GeneralConstants.https ] }

        static func isSchemeAllowed(urlScheme: String?) -> Bool {

            if let urlScheme = urlScheme {

                return self.allAllowedSchemes().contains(urlScheme)

            } else {

                return false
            }
        }
    }

    class func canMonitorRequest(_ request: URLRequest) -> Bool {

        // Check for our internal state
        guard self.active == true else { return false }

        // Check for bogus urls
        guard let url = request.url else { return false }

        // Check for a valid scheme
        guard let rawScheme = url.scheme,
            AllowedURLScheme.isSchemeAllowed(urlScheme: rawScheme) else { return false }

        // Avoid monitoring already monitored requests
        guard URLProtocol.property(forKey: GeneralConstants.tagKey, in: request) == nil else { return false }

        return true
    }

    class func taggedNormalized(_ request: NSURLRequest) -> NSURLRequest? {

        if let mutableRequest = request.mutableCopy() as? NSMutableURLRequest {

            // Add a tag to this request
            URLProtocol.setProperty(true,
                                    forKey: GeneralConstants.tagKey,
                                    in: mutableRequest)

            // The http body might be nilled after the request finishes, so save it here
            if let httpBody = mutableRequest.httpBody {

                URLProtocol.setProperty(httpBody,
                                        forKey: GeneralConstants.bodyKey,
                                        in: mutableRequest)
            }

            // The http body stream might be nilled after the request finishes, so save it here
            if let httpBodyStream = mutableRequest.httpBodyStream {

                URLProtocol.setProperty(httpBodyStream,
                                        forKey: GeneralConstants.bodyStreamKey,
                                        in: mutableRequest)
            }

            return mutableRequest.copy() as? NSURLRequest
        }

        return nil
    }

    class func untagged(_ originalRequest: NSURLRequest,
                        redirectRecordKey: HTTPRequestRecordKey) -> NSURLRequest? {

        if let mutableRequest = originalRequest.mutableCopy() as? NSMutableURLRequest {

            // Remove the tags from the request copy
            URLProtocol.removeProperty(forKey: GeneralConstants.tagKey,
                                       in: mutableRequest)

            URLProtocol.removeProperty(forKey: GeneralConstants.bodyKey,
                                       in: mutableRequest)

            URLProtocol.removeProperty(forKey: GeneralConstants.bodyStreamKey,
                                       in: mutableRequest)

            return mutableRequest.copy() as? NSURLRequest
        }

        return nil
    }
}

// Cache Policy
private extension FNMNetworkMonitorURLProtocol {

    private enum CacheableHttpStatusCode {

        static func allCacheableHttpStatusCodes() -> [Int] { return [   200,
                                                                        203,
                                                                        206,
                                                                        301,
                                                                        304,
                                                                        404,
                                                                        410] }

        static func isHttpStatusCodeCacheable(httpStatusCode: Int?) -> Bool {

            if let httpStatusCode = httpStatusCode {

                return self.allCacheableHttpStatusCodes().contains(httpStatusCode)
            }

            return false
        }
    }

    class func inferredCachePolicy(from originalRequest: URLRequest,
                                   and response: HTTPURLResponse) -> URLCache.StoragePolicy {

        let cachePolicy: URLCache.StoragePolicy

        // Check whether the status code allows further cache
        var cacheable = CacheableHttpStatusCode.isHttpStatusCodeCacheable(httpStatusCode: response.statusCode)

        // Check if the original request forbade cache, if needed
        if cacheable,
            let cacheControlValue = response.allHeaderFields[GeneralConstants.cacheControlKey] as? String {

            cacheable = cacheControlValue.lowercased().contains(GeneralConstants.cacheControlValueNoStore) == false
        }

        // Check if the response forbids cache, if needed
        if cacheable,
            let cacheControlValue = originalRequest.allHTTPHeaderFields?[GeneralConstants.cacheControlKey] {

            cacheable = (cacheControlValue.lowercased().contains(GeneralConstants.cacheControlValueNoStore) == false
                && cacheControlValue.lowercased().contains(GeneralConstants.cacheControlValueNoCache) == false)
        }

        if cacheable, originalRequest.url?.scheme?.lowercased() == GeneralConstants.https {

            cachePolicy = .allowedInMemoryOnly

        } else if cacheable {

            cachePolicy = .allowed

        } else {

            cachePolicy = .notAllowed
        }

        return cachePolicy
    }
}

// Request Record
extension FNMNetworkMonitorURLProtocol {

    class func requestRecord(for key: String,
                             request: NSURLRequest) -> FNMHTTPRequestRecord {

        return FNMHTTPRequestRecord(key: key,
                                    request: request,
                                    startTimestamp: Date())
    }

    func concludeRecordIfNeeded(conclusion: FNMHTTPRequestRecordConclusionType) {

        if let requestRecord = self.requestRecord,
            requestRecord.conclusion == nil {

            requestRecord.endTimestamp = Date()
            requestRecord.conclusion = conclusion

            FNMNetworkMonitorURLProtocol.dataSource?.setRequestRecord(requestRecord: requestRecord,
                                                                      completion: { })
        }
    }
}
