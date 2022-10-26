//
//  Logger.swift
//  ProcessOut
//
//  Created by Andrii Vysotskyi on 25.10.2022.
//

import Foundation

final class Logger {

    init(destinations: [LoggerDestination]) {
        self.destinations = destinations
    }

    /// Records a message at the specified log level. Use this method when you need to adjust the log level
    /// dynamically for a given message.
    ///
    /// - Parameters:
    ///   - level: The log level at which to store the message. This value determines the severity of the message and
    ///   whether the system persists it to disk. You may specify a constant or variable for this parameter.
    ///   - message: the message you want to add to the logs.
    func log(level: LogLevel, _ message: LogMessage, file: String = #file, line: Int = #line) {
        // swiftlint:disable:next legacy_objc_type
        let fileName = NSString(string: NSString(string: file).deletingPathExtension).lastPathComponent
        let entry = LogEntry(level: level, message: message, timestamp: Date(), file: fileName, line: line)
        destinations.forEach { $0.log(entry: entry) }
    }

    /// Logs a message at the `debug` level.
    func debug(_ message: LogMessage, file: String = #file, line: Int = #line) {
        log(level: .debug, message, file: file, line: line)
    }

    /// Logs a message at the `info` level.
    func info(_ message: LogMessage, file: String = #file, line: Int = #line) {
        log(level: .info, message, file: file, line: line)
    }

    /// Logs a message at the `error` level.
    func error(_ message: LogMessage, file: String = #file, line: Int = #line) {
        log(level: .error, message, file: file, line: line)
    }

    /// Logs a message at the `fault` level.
    func fault(_ message: LogMessage, file: String = #file, line: Int = #line) {
        log(level: .fault, message, file: file, line: line)
    }

    // MARK: -

    private let destinations: [LoggerDestination]
}
