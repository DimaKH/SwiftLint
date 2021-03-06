//
//  Linter.swift
//  SwiftLint
//
//  Created by JP Simard on 5/16/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import Dispatch
import Foundation
import SourceKittenFramework

private struct LintResult {
    let violations: [StyleViolation]
    let ruleTime: (id: String, time: Double)?
    let deprecatedToValidIDPairs: [(String, String)]
}

extension Rule {
    fileprivate func performLint(file: File, regions: [Region], benchmark: Bool) -> LintResult? {
        if !(self is SourceKitFreeRule) && file.sourcekitdFailed {
            return nil
        }

        let violations: [StyleViolation]
        let ruleTime: (String, Double)?
        if benchmark {
            let start = Date()
            violations = validateFile(file)
            let id = type(of: self).description.identifier
            ruleTime = (id, -start.timeIntervalSinceNow)
        } else {
            violations = validateFile(file)
            ruleTime = nil
        }

        let (disabledViolationsAndRegions, enabledViolationsAndRegions) = violations.map { violation in
            return (violation, regions.first(where: { $0.contains(violation.location) }))
        }.partitioned { _, region in
            return region?.isRuleEnabled(self) ?? true
        }

        let enabledViolations = enabledViolationsAndRegions.map { $0.0 }
        let deprecatedToValidIDPairs = disabledViolationsAndRegions.flatMap { _, region -> [(String, String)] in
            let identifiers = region?.deprecatedAliasesDisablingRule(self) ?? []
            return identifiers.map { ($0, type(of: self).description.identifier) }
        }

        return LintResult(violations: enabledViolations, ruleTime: ruleTime,
                          deprecatedToValidIDPairs: deprecatedToValidIDPairs)
    }
}

public struct Linter {
    public let file: File
    private let rules: [Rule]

    public var styleViolations: [StyleViolation] {
        return getStyleViolations().0
    }

    public var styleViolationsAndRuleTimes: ([StyleViolation], [(id: String, time: Double)]) {
        return getStyleViolations(true)
    }

    private func getStyleViolations(_ benchmark: Bool = false) -> ([StyleViolation], [(id: String, time: Double)]) {
        if file.sourcekitdFailed {
            queuedPrintError("Most rules will be skipped because sourcekitd has failed.")
        }
        let regions = file.regions()
        let validationResults = rules.parallelFlatMap {
            $0.performLint(file: self.file, regions: regions, benchmark: benchmark)
        }
        let violations = validationResults.flatMap { $0.violations }
        let ruleTimes = validationResults.flatMap { $0.ruleTime }
        var deprecatedToValidIdentifier = [String: String]()
        for (key, value) in validationResults.flatMap({ $0.deprecatedToValidIDPairs }) {
            deprecatedToValidIdentifier[key] = value
        }

        for (deprecatedIdentifier, identifier) in deprecatedToValidIdentifier {
            queuedPrintError("'\(deprecatedIdentifier)' rule has been renamed to '\(identifier)' and will be " +
                "completely removed in a future release.")
        }

        return (violations, ruleTimes)
    }

    public init(file: File, configuration: Configuration = Configuration()!) {
        self.file = file
        rules = configuration.rules
    }

    public func correct() -> [Correction] {
        var corrections = [Correction]()
        for rule in rules.flatMap({ $0 as? CorrectableRule }) {
            let newCorrections = rule.correctFile(file)
            corrections += newCorrections
            if !newCorrections.isEmpty {
                file.invalidateCache()
            }
        }
        return corrections
    }
}
