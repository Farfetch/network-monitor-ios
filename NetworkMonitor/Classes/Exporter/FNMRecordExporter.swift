//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public enum FNMRecordExporterSortOption: String {

    case sortedStartTimestamp = "sorted-start-timestamp"
    case sortedAlphabetically = "sorted-alphabetically"
    case sortedSlowest = "sorted-slowest"
}

struct FNMRecordExporter {

    static func export(_ requestRecords: [FNMHTTPRequestRecord],
                       option: FNMRecordExporterSortOption) {

        DispatchQueue.global().async {

            do {

                let recordsFilenameURL = try self.recordsFilenameURL(option: option)

                let serializableObject = FNMHTTPRequestRecordCodableContainer(records: requestRecords,
                                                                             option: option)

                try self.encodeObject(serializableObject,
                                      fileUrl: recordsFilenameURL)

                FNMRecordExporter.log(message: "Exported Request Records Using Option '\(option)'")

            } catch {

                assertionFailure("Failed to export, please advise")
            }
        }
    }

    static func exportAppLaunchRecord(_ appLaunchRecord: FNMAppLaunchRecord,
                                      requestRecords: [FNMHTTPRequestRecord]) {

        DispatchQueue.global().async {

            do {

                // Current run
                let currentRunConfigurationFilenameURL = try self.currentRunConfigurationFilenameURL()

                let currentRunSerializableObject = FNMAppLaunchCurrentRunCodableContainer(appLaunchRecord: appLaunchRecord,
                                                                                          requestRecords: requestRecords)
                try self.encodeObject(currentRunSerializableObject,
                                      fileUrl: currentRunConfigurationFilenameURL)

                FNMRecordExporter.log(message: "Exported App Configuration Current run")

            } catch {

                assertionFailure("Failed to export, please advise")
            }
        }
    }
}

extension FNMRecordExporter {

    enum RecordExporterError: Error {

        case notEnoughInfoForFolderCreation
        case failedToCreateFolder
        case invalidObject
        case failedToWrite
        case failedToRead
    }

    static func currentRunConfigurationFilenameURL() throws -> URL {

        let currentRunFolderPath = try self.relativeCurrentRunConfigurationFolder(title: self.folderBaseName())
        _ = try self.createFolder(at: currentRunFolderPath)
        return self.currentRunConfigurationFilenameURL(path: currentRunFolderPath)
    }

    static func recordsFilenameURL(option: FNMRecordExporterSortOption) throws -> URL {

        let folderPath = try self.relativeRecordsFolder(title: self.folderBaseName())

        _ = try self.createFolder(at: folderPath)

        return self.recordsFilenameURL(path: folderPath,
                                       option: option)
    }

    private static func log(message: String) {

        FNMLogger.log(message: message,
                      scope: .export)
    }

    private static func baseFolder(title: String) throws -> URL {

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {

                                                                    throw RecordExporterError.failedToCreateFolder
        }

        var path = documentsDirectory

        path.appendPathComponent(Constants.exportMonitorGeneralFolderPath)
        path.appendPathComponent(title)

        return path
    }

    private static func relativeCurrentRunConfigurationFolder(title: String) throws -> URL {

        do {

            var path = try self.baseFolder(title: title)

            path.appendPathComponent(Constants.exportAppLaunchGeneralFolderPath)
            path.appendPathComponent(Constants.exportAppLaunchCurrentRunFolderPath)

            return path
        }
    }

    private static func currentRunConfigurationFilenameURL(path: URL) -> URL {

        var filePath = path

        filePath.appendPathComponent(Constants.exportAppLaunchCurrentRunFilename + Constants.exportFileExtension)

        return filePath
    }

    private static func relativeRecordsFolder(title: String) throws -> URL {

        do {

            var path = try self.baseFolder(title: title)

            path.appendPathComponent(Constants.exportRecordsGeneralFolderPath)

            return path
        }
    }

    private static func recordsFilenameURL(path: URL,
                                           option: FNMRecordExporterSortOption) -> URL {

        var filePath = path

        filePath.appendPathComponent(Constants.exportRecordsSimpleFilename +
            Constants.exportFileSeparator +
            option.rawValue +
            Constants.exportFileExtension)

        return filePath
    }

    static func createFolder(at path: URL) throws -> URL {

        do {

            try FileManager.default.createDirectory(at: path,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {

            throw RecordExporterError.failedToCreateFolder
        }

        return path
    }

    static func folderBaseName() -> String {

        return "\(FNMNetworkMonitor.shared.referenceDate.timeIntervalSince1970)"
    }

    static func encodeObject<T>(_ object: T,
                                fileUrl: URL) throws where T: Encodable {

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted // Inefficient but the file size difference isn't significant

        do {

            let encodedData = try jsonEncoder.encode(object)

            try encodedData.write(to: fileUrl,
                                  options: Data.WritingOptions.atomic)

        } catch {

            throw RecordExporterError.failedToWrite
        }
    }
}

private extension FNMRecordExporter {

    private enum Constants {

        static let exportMonitorGeneralFolderPath = "NetworkMonitor"
        static let exportAppLaunchGeneralFolderPath = "AppLaunch"
        static let exportAppLaunchCurrentRunFolderPath = "CurrentRun"
        static let exportRecordsGeneralFolderPath = "Records"
        static let exportAppLaunchCurrentRunFilename = "configuration"
        static let exportRecordsSimpleFilename = "records"
        static let exportFileExtension = ".json"
        static let exportFileSeparator = "-"
    }
}
