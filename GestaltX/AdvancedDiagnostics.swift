// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CoreFoundation
#if canImport(Darwin)
import Darwin
#endif

struct DiagnosticEvent: Codable, Identifiable {
    let id: UUID
    let session: UUID
    let timestamp: Date
    let operation: String
    let values: [String: String]
    let outcome: String
    var comparisons: [ReadingComparison]? = nil
}

struct ReadingComparison: Codable {
    let basis: String
    let bootState: String
    let changes: [String: [String]]
    static func compare(_ before: [String: String], _ after: [String: String], basis: String, oldBoot: Double?, newBoot: Double) -> Self {
        let state = oldBoot == nil || oldBoot == 0 || newBoot == 0 ? "unknown" : (oldBoot == newBoot ? "same-boot" : "after-reboot")
        return Self(basis: basis, bootState: state, changes: Dictionary(uniqueKeysWithValues: AdvancedDiagnostics.flags.filter { before[$0] != after[$0] }.map { ($0, [before[$0] ?? "unknown", after[$0] ?? "unknown"]) }))
    }
}

/// A closed schema: no raw errors, paths, device identifiers, plist strings or blobs.
final class AdvancedDiagnostics: @unchecked Sendable {
    static let shared = AdvancedDiagnostics()
    static let flags = [
        "A62OafQ85EJAiiqKn4agtg", "a3n5T9sFtlyQ74NEp9ESxg", "K/R1GfGfCkXvEhaPS2Vrng",
        "rb2tKZxlj0Gm2tBmUQSLqQ", "M1n2sAqf33NAOgZRGxQYBA", "XNCjqOupLM/S8fNyxRNQTA",
        "YgYIIViDt1kgzyIsIV61vA", "TusANsf9Lfe3P/9fIXXSrQ"
    ]
    struct Archive: Codable {
        var events: [DiagnosticEvent] = []
        var expected: [String: String]?
        var boot: Double?
        var observed: [String: String]?
        var observedBoot: Double?
    }
    private let lock = NSLock()
    private let url: URL
    private let bootProvider: () -> Double
    private let session = UUID()
    private var archive: Archive
    private(set) var storageFailed = false

    init(url: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GestaltX/Diagnostics/report.json"), bootProvider: @escaping () -> Double = { AdvancedDiagnostics.boot }) {
        self.bootProvider = bootProvider
        self.url = url
        archive = (try? JSONDecoder().decode(Archive.self, from: Data(contentsOf: url))) ?? Archive()
    }
    static func values(_ extra: [String: Any]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: flags.map { key in
            let value: String
            if extra[key] == nil { value = "absent" }
            else if let number = extra[key] as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() { value = number.boolValue ? "bool:true" : "bool:false" }
                else if number.doubleValue.isFinite && abs(number.doubleValue) <= 1024 {
                    value = "number:" + number.stringValue
                } else { value = "redacted-number" }
            } else { value = "redacted-type" }
            return (key, value)
        })
    }
    static func comparison(expected: [String: String], actual: [String: String]) -> String {
        expected == actual ? "persisted" : "changed-or-reverted"
    }
    static var boot: Double {
        #if canImport(Darwin)
        var time = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &time, &size, nil, 0) == 0 { return Double(time.tv_sec) }
        #endif
        return 0
    }
    func record(_ operation: String, extra: [String: Any]? = nil, outcome: String = "ok", written: Bool = false, read: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        let values = extra.map(Self.values) ?? [:]
        let boot = bootProvider()
        var comparisons: [ReadingComparison] = []
        if read, extra != nil {
            if let baseline = archive.observed {
                comparisons.append(.compare(baseline, values, basis: "observed-reading", oldBoot: archive.observedBoot, newBoot: boot))
            } else { archive.observed = values; archive.observedBoot = boot }
            if let baseline = archive.expected {
                comparisons.append(.compare(baseline, values, basis: "verified-write", oldBoot: archive.boot, newBoot: boot))
            }
        }
        if written, extra != nil { archive.expected = values; archive.boot = boot }
        let result = comparisons.contains { !$0.changes.isEmpty } ? "changed-or-reverted" : outcome
        archive.events.append(DiagnosticEvent(id: UUID(), session: session, timestamp: Date(), operation: operation, values: values, outcome: result, comparisons: comparisons))
        if archive.events.count > 500 { archive.events.removeFirst(archive.events.count - 500) }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(archive).write(to: url, options: .atomic)
            storageFailed = false
        } catch { storageFailed = true }
    }
    func report(pending: [String: String] = [:]) throws -> String {
        lock.lock(); defer { lock.unlock() }
        struct Report: Encodable {
            let schema = 2
            let pending: [String: String]
            let interpretation = "Equal readings show observed stability only, never Siri or Apple Intelligence functionality."
            let os: String
            let model: String
            let access = "existing worse_query sandbox extension; readback verification"
            let storageFailed: Bool
            let events: [DiagnosticEvent]
        }
        var model = "unknown"
        #if canImport(Darwin)
        var system = utsname()
        if uname(&system) == 0 {
            model = withUnsafeBytes(of: &system.machine) { bytes in
                String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
        }
        #endif
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(Report(pending: pending, os: ProcessInfo.processInfo.operatingSystemVersionString, model: model, storageFailed: storageFailed, events: archive.events)), as: UTF8.self)
    }
}
