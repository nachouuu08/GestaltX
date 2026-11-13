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
        precondition(!report.contains("expected") && !report.contains("boot\""))
        for _ in 0..<510 { reopened.record("read") }
        let object = try JSONSerialization.jsonObject(with: Data(reopened.report().utf8)) as! [String: Any]
        precondition((object["events"] as! [Any]).count == 500)
        print("AdvancedDiagnosticsTests passed")
    }
}
