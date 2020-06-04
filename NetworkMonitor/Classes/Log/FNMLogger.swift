//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

struct FNMLogger {

    static func log(message: String,
                    scope: FNMLogScope) {

        if let currentLogScope = FNMNetworkMonitor.shared.logScope,
            currentLogScope.contains(scope) {

            self.queue.async { print(self.normalizedMessage(message,
                                                            scope: scope) ) }
        }
    }
}

private extension FNMLogger {

    private enum Constants {

        static let dispatchQueueName = "NetworkMonitor.loggerSyncQueue"
    }

    static var queue: DispatchQueue = DispatchQueue(label: Constants.dispatchQueueName)

    static func normalizedMessage(_ message: String,
                                  scope: FNMLogScope) -> String {

        return scope.flavor() + " " + message
    }
}

public struct FNMLogScope: OptionSet {

    public let rawValue: Int

    public init(rawValue: Int) {

        self.rawValue = rawValue
    }

    public static let urlProtocol = FNMLogScope(rawValue: 1 << 0)
    public static let profile = FNMLogScope(rawValue: 1 << 1)
    public static let export = FNMLogScope(rawValue: 1 << 2)
}

private extension FNMLogScope {

    func flavor() -> String {

        switch self {
        case FNMLogScope.urlProtocol: return "✈️"
        case FNMLogScope.profile: return "🔆"
        case FNMLogScope.export: return "📤"
        default: return ""
        }
    }
}
