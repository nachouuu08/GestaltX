import Foundation

@main struct AdvancedDiagnosticsTests {
    static func main() throws {
        let key = AdvancedDiagnostics.flags[0]
        let values = AdvancedDiagnostics.values([key: NSNumber(value: true), "token": "secret", AdvancedDiagnostics.flags[1]: "private-key"])
        precondition(values[key] == "bool:true")
        precondition(values[AdvancedDiagnostics.flags[1]] == "redacted-type")
        precondition(values[AdvancedDiagnostics.flags[2]] == "absent")
        precondition(values["token"] == nil)
        precondition(AdvancedDiagnostics.comparison(expected: values, actual: values) == "persisted")
        precondition(AdvancedDiagnostics.comparison(expected: values, actual: [:]) == "changed-or-reverted")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("report.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdvancedDiagnostics(url: url)
        store.record("verified", extra: [key: NSNumber(value: true)], written: true)
        let reopened = AdvancedDiagnostics(url: url)
        reopened.record("read", extra: [key: NSNumber(value: false)], read: true)
        let report = try reopened.report()
        precondition(report.contains("changed-or-reverted"))
        precondition(!report.contains("private-key") && !report.contains("secret"))
        precondition(report.range(of: #""(expected|boot)"\s*:"#, options: .regularExpression) == nil)
        for _ in 0..<510 { reopened.record("read") }
        let object = try JSONSerialization.jsonObject(with: Data(reopened.report().utf8)) as! [String: Any]
        precondition((object["events"] as! [Any]).count == 500)
        let changed = ReadingComparison.compare([key: "number:1"], [key: "number:2"], basis: "observed-reading", oldBoot: 10, newBoot: 20)
        precondition(changed.bootState == "after-reboot" && changed.changes[key] == ["number:1", "number:2"])
        precondition(ReadingComparison.compare(values, values, basis: "observed-reading", oldBoot: 10, newBoot: 10).changes.isEmpty)
        precondition(ReadingComparison.compare(values, values, basis: "observed-reading", oldBoot: 0, newBoot: 10).bootState == "unknown")
        let readURL = url.deletingLastPathComponent().appendingPathComponent("read-only.json")
        let first = AdvancedDiagnostics(url: readURL, bootProvider: { 10 })
        first.record("read-start")
        first.record("read-complete", extra: [key: 1], read: true)
        let next = AdvancedDiagnostics(url: readURL, bootProvider: { 20 })
        next.record("read-complete", extra: [key: 2], read: true)
        let readReport = try next.report()
        precondition(readReport.contains("after-reboot") && readReport.contains("observed-reading"))
        precondition(!readReport.contains("verified-write"))
        let decoded = try JSONSerialization.jsonObject(with: Data(readReport.utf8)) as! [String: Any]
        let events = decoded["events"] as! [[String: Any]]
        precondition((events[0]["values"] as! [String: String]).isEmpty)
        print("AdvancedDiagnosticsTests passed")
    }
}
