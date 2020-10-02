//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public enum FNMRecordExporterPreference {

    case off
    case on(setting: FNMRecordExporterPreferenceSetting)

    public enum FNMRecordExporterPreferenceSetting {

        case unlimited
        case first(numberOfRecords: Int)
        case last(numberOfRecords: Int)
    }
}

struct FNMRecordExporter {

    static var requestRecordExportQueued: Bool = false

    static func export(_ requestRecords: [FNMHTTPRequestRecord],
                       preference: FNMRecordExporterPreference) {

        if case let FNMRecordExporterPreference.on(setting) = preference {

            if self.requestRecordExportQueued == false {

                self.requestRecordExportQueued = true

                DispatchQueue.global().asyncAfter(deadline: .now() + Constants.exportDebounceDelay,
                                                  execute: {

                                                    do {

                                                        let recordsFilenameURL = try self.recordsFilenameURL()
                                                        let requestRecordsToProcess: [FNMHTTPRequestRecord]

                                                        switch setting {

                                                        case .unlimited:
                                                            requestRecordsToProcess = requestRecords

                                                        case .first(let numberOfRecords):
                                                            requestRecordsToProcess = Array(requestRecords.prefix(numberOfRecords))

                                                        case .last(let numberOfRecords):
                                                            requestRecordsToProcess = Array(requestRecords.suffix(numberOfRecords))
                                                        }

                                                        let serializableObject = FNMHTTPRequestRecordCodableContainer(records: requestRecordsToProcess)

                                                        try self.encodeObject(serializableObject,
                                                                              fileUrl: recordsFilenameURL)

                                                        FNMRecordExporter.log(message: "Exported Request Records Using Setting '\(setting)'")

                                                        self.requestRecordExportQueued = false

                                                    } catch {

                                                        assertionFailure("Failed to export, please advise")
                                                    }
                                                  })
            }
        }
    }

    static func exportRecord(_ record: FNMRecord,
                             requestRecords: [FNMHTTPRequestRecord],
                             overallRecords: Bool = false) {

        DispatchQueue.global().async {

            do {

                // Current run
                let currentRunConfigurationFilenameURL = try self.currentRunConfigurationFilenameURL()

                let currentRunSerializableObject = FNMCurrentRunCodableContainer(record: record,
                                                                                          requestRecords: requestRecords,
                                                                                          overallRecords: overallRecords)
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

    static func recordsFilenameURL() throws -> URL {

        let folderPath = try self.relativeRecordsFolder(title: self.folderBaseName())

        _ = try self.createFolder(at: folderPath)

        return self.recordsFilenameURL(path: folderPath)
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

            path.appendPathComponent(Constants.exportGeneralFolderPath)
            path.appendPathComponent(Constants.exportCurrentRunFolderPath)

            return path
        }
    }

    private static func currentRunConfigurationFilenameURL(path: URL) -> URL {

        var filePath = path

        filePath.appendPathComponent(Constants.exportCurrentRunFilename + Constants.exportFileExtension)

        return filePath
    }

    private static func relativeRecordsFolder(title: String) throws -> URL {

        do {

            var path = try self.baseFolder(title: title)

            path.appendPathComponent(Constants.exportRecordsGeneralFolderPath)

            return path
        }
    }

    private static func recordsFilenameURL(path: URL) -> URL {

        var filePath = path

        filePath.appendPathComponent(Constants.exportRecordsSimpleFilename +
            Constants.exportFileSeparator +
            Constants.exportRecordsFilename +
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
        static let exportGeneralFolderPath = "AppLaunch"
        static let exportCurrentRunFolderPath = "CurrentRun"
        static let exportRecordsGeneralFolderPath = "Records"
        static let exportRecordsFilename = "sorted-start-timestamp"
        static let exportCurrentRunFilename = "configuration"
        static let exportRecordsSimpleFilename = "records"
        static let exportFileExtension = ".json"
        static let exportFileSeparator = "-"

        static let exportDebounceDelay = 1.5
    }
}
