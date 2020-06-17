# iOS Network Monitor

[![CocoaPods Compatible](https://img.shields.io/badge/cocoapods-compatible-green.svg)]()
[![Supported languages](https://img.shields.io/badge/supported%20languages-swift-green.svg)]()
[![Platform](https://img.shields.io/badge/platform-ios-green.svg)]()

## What is this ?

FNMNetworkMonitor is a networking SDK that can be used to monitor the network of an iOS app. In addition, it can also mock network requests.

## Installation ⚙️

1. Add `pod 'FNMNetworkMonitor'` to your `Podfile`

## Usage

### There are a few ways to monitor the network:

1. Monitoring URLSession.shared:

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring(passiveExport: false)

2. Monitoring custom URLSessions by supplying the FNMMonitor URL Protocol:

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = FNMNetworkMonitor.normalizedURLProtocols()
        self.customSession = URLSession(configuration: sessionConfig)
        FNMNetworkMonitor.shared.startMonitoring(passiveExport: false)

3. Monitoring all sessions by sizzling the URLSessionConfiguration creation and by supplying the FNMMonitor URL Protocol manually

### Additionally, you can mock certain requests using:

        let request = FNMProfileRequest(urlPattern: .dynamicPattern(expression: "*farfetch.*robots"))
        let profiles = [FNMProfile(request: request,
                                   responses: [request.response(statusCode: 200,
                                   								headers: [ "Content-Type": "application/json" ],
                                                   				responseHolder: .keyValue(value: [ "FieldA": 1 ])
                                                                delay: 0.25)])]
        FNMNetworkMonitor.shared.configure(profiles: profiles)
        FNMNetworkMonitor.shared.startMonitoring(passiveExport: false)


Make sure to follow steps 1, 2 or 3, depending on the URLSession that runs that particular request.

### How to see it all

A debug UI exists that can be used for easy inspection and export of the network:

        FNMNetworkMonitor.shared.showDebugListingViewController(presentingNavigationController: self.navigationController)

Also, different log levels can be applied to see how the requests are navigating through the monitor:

        FNMNetworkMonitor.shared.logScope = [.export, .profile, .urlProtocol]

Finally, you can turn on the passive export and the requests will be exported to a json file inside a folder found the Documents application folder.

        FNMNetworkMonitor.shared.startMonitoring(passiveExport: true)

### Sample app

The project contains a sample app where you can test the tool.

## Contributing

Read the [Contributing guidelines](CONTRIBUTING.md)


## Maintainers

List of [Maintainers](MAINTAINERS.md)


## License

[MIT](LICENSE)
