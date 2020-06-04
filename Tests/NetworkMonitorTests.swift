//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import XCTest
@testable import FNMNetworkMonitor

class NetworkMonitorUnitTests: XCTestCase {

    var networkMonitor: FNMNetworkMonitor!

    override func setUp() {

        super.setUp()

        self.networkMonitor = FNMNetworkMonitor.shared
        FNMNetworkMonitor.shared.startMonitoring()
    }

    override func tearDown() {

        super.tearDown()

        self.networkMonitor.clear(completion: { } )
        self.networkMonitor.resetProfiles()
        self.networkMonitor.stopMonitoring()
    }

    static var testBundle: Bundle {

        return Bundle(for: NetworkMonitorUnitTests.self as AnyClass)
    }

    func reachVariousSitesConcurrently(expectation: XCTestExpectation) {

        let group = DispatchGroup()
        group.enter()
        defer { group.leave() }

        Constants.Sites.allCases.forEach { site in

            group.enter()

            let delay = Double.random(in: 1 ... 200) / 1000.0

            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {

                self.reachSite(site: site) { group.leave() }
            }
        }

        group.notify(queue: .main) {

            expectation.fulfill()
        }
    }

    func reachSitesSequencially(sites: [Constants.Sites] = Constants.Sites.allCases,
                                expectation: XCTestExpectation) {

        self.reachSitesSequencially(sites: sites) { expectation.fulfill() }
    }

    func reachSitesSequencially(sites: [Constants.Sites] = Constants.Sites.allCases,
                                completion: @escaping () -> Void) {

        DispatchQueue.global().async {

            for site in sites {

                let semaphore = DispatchSemaphore(value: 0)

                self.reachSite(site: site) { semaphore.signal() }

                semaphore.wait()
            }

            DispatchQueue.main.async(execute: completion)
        }
    }

    private func reachSite(site: Constants.Sites,
                           completion: @escaping () -> Void) {

        var request = URLRequest(url: URL(string: site.rawValue)!)
        request.allHTTPHeaderFields = site.headerFields
        URLSession.shared.dataTask(with: request, completionHandler: { _, _, _ in completion() }).resume()
    }
}

extension XCTestCase {

    func request(for urlString: String,
                 httpMethod: String,
                 httpHeaders: [String: String]? = nil,
                 body: String? = nil) -> NSURLRequest {

        let request = NSMutableURLRequest(url: URL(string: urlString)!)
        request.httpMethod = httpMethod
        request.allHTTPHeaderFields = httpHeaders
        request.httpBody = body?.data(using: .utf8)

        return request
    }

    func firstMatch(profiles: [FNMProfile],
                    request: NSURLRequest) -> FNMProfile? {

        return profiles.first {

            switch $0.matches(request) {

                case .hit(_, _): return true
                default: return false
            }
        }
    }
}
