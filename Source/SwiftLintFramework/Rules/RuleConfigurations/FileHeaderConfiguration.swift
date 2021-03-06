//
//  FileHeaderConfiguration.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 01/12/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation

public struct FileHeaderConfiguration: RuleConfiguration, Equatable {
    private(set) var severityConfiguration = SeverityConfiguration(.warning)
    private var requiredString: String?
    private var requiredPattern: String?
    private var forbiddenString: String?
    private var forbiddenPattern: String?

    private var _forbiddenRegex: NSRegularExpression?

    private(set) var requiredRegex: NSRegularExpression?
    private(set) var forbiddenRegex: NSRegularExpression? {
        get {
            if _forbiddenRegex != nil {
                return _forbiddenRegex
            }

            if requiredRegex == nil {
                return FileHeaderConfiguration.defaultRegex
            }

            return nil
        }
        set {
            _forbiddenRegex = newValue
        }
    }

    private static let defaultRegex = regex("\\bCopyright\\b", options: [.caseInsensitive])

    public var consoleDescription: String {
        return severityConfiguration.consoleDescription + ", required_string: \(requiredString)" +
            ", required_pattern: \(requiredPattern), forbidden_string: \(forbiddenString)" +
            ", forbidden_pattern: \(forbiddenPattern)"
    }

    public init() {}

    public mutating func applyConfiguration(_ configuration: Any) throws {
        guard let configuration = configuration as? [String: String] else {
            throw ConfigurationError.unknownConfiguration
        }

        if let requiredString = configuration["required_string"] {
            self.requiredString = requiredString
            requiredRegex = try NSRegularExpression(pattern: requiredString,
                                                    options: [.ignoreMetacharacters])
        } else if let requiredPattern = configuration["required_pattern"] {
            self.requiredPattern = requiredPattern
            requiredRegex = try .cached(pattern: requiredPattern)
        }

        if let forbiddenString = configuration["forbidden_string"] {
            self.forbiddenString = forbiddenString
            forbiddenRegex = try NSRegularExpression(pattern: forbiddenString,
                                                     options: [.ignoreMetacharacters])
        } else if let forbiddenPattern = configuration["forbidden_pattern"] {
            self.forbiddenPattern = forbiddenPattern
            forbiddenRegex = try .cached(pattern: forbiddenPattern)
        }

        if let severityString = configuration["severity"] {
            try severityConfiguration.applyConfiguration(severityString)
        }
    }
}

public func == (lhs: FileHeaderConfiguration,
                rhs: FileHeaderConfiguration) -> Bool {
    return lhs.severityConfiguration == rhs.severityConfiguration
}
