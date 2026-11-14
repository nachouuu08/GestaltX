// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import UniformTypeIdentifiers

private struct DiagnosticReportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct AdvancedDiagnosticsView: View {
    @EnvironmentObject private var model: GestaltManager
    @State private var report = ""
    @State private var exporting = false
    @State private var error: String?
    var body: some View {
        List {
            Section("Estado actual · MobileGestalt") {
                Text("Último documento cargado; desconocido hasta leer. No representa las selecciones de presets.")
                ForEach(Capability.all.filter { !$0.keys.allSatisfy { !AdvancedDiagnostics.flags.contains($0) } }, id: \.id) { capability in
                    ForEach(capability.keys.filter { AdvancedDiagnostics.flags.contains($0) }, id: \.self) { key in
                        LabeledContent(capability.title, value: model.snapshot.map { AdvancedDiagnostics.values($0.document.extra)[key] ?? "unknown" } ?? "unknown")
                    }
                }
            }
            Section("Interfaz de presets · cambios pendientes") {
                ForEach(model.diagnosticPending.keys.sorted(), id: \.self) { key in
                    LabeledContent(key, value: model.diagnosticPending[key] ?? "unknown")
                }
            }
            Section("Siri y Apple Intelligence") {
                Text("MobileGestalt y lecturas iguales no prueban funcionalidad. La API pública SystemLanguageModel.availability informa disponibilidad del modelo local para apps, no preparación completa de Siri ni progreso de descargas. Estado funcional de Siri: desconocido; requiere observación manual.")
            }

            Section {
                Text("Registra lecturas y escrituras del dispositivo. Después de reiniciar, vuelve a leer para comparar con la primera lectura observada y, si existe, la última escritura verificada. Un cambio de flags no demuestra que Apple Intelligence esté disponible.")
                Text("La lectura usa el acceso existente y puede crear el respaldo habitual. Descarta o guarda cambios pendientes antes de leer.")
                Button("Registrar / comparar lectura actual") {
                    Task { await model.connect(); refresh() }
                }.disabled(model.isBusy || model.changeCount > 0)
                Button("Consultar registro", action: refresh)
                Button("Exportar JSON") { refresh(); if error == nil { exporting = true } }
                if let error { Text(error).foregroundStyle(.red) }
            }
            Section("Estado observado después del reinicio") {
                Text(comparisonSummary)
            }
            Section("Escritura y verificación") {
                Text(writeSummary)
            }
            Section("Eventos (máximo 500)") {
                Text(report).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            }
        }
        .navigationTitle("Diagnóstico avanzado")
        .onAppear(perform: refresh)
        .fileExporter(isPresented: $exporting, document: DiagnosticReportFile(text: report), contentType: .json, defaultFilename: "GestaltX-diagnostic") { result in
            if case .failure = result { error = "No se pudo exportar el informe." }
        }
    }
    private var events: [[String: Any]] {
        guard let object = try? JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: Any] else { return [] }
        return object["events"] as? [[String: Any]] ?? []
    }
    private var comparisonSummary: String {
        guard let event = events.last(where: { ($0["operation"] as? String) == "read-complete" }),
              let comparisons = event["comparisons"] as? [[String: Any]], !comparisons.isEmpty else {
            return "Sin comparación: registra una línea base y una lectura posterior."
        }
        return comparisons.map { comparison in
            let changes = comparison["changes"] as? [String: [String]] ?? [:]
            let details = changes.keys.sorted().map { key in key + ": " + (changes[key] ?? []).joined(separator: " → ") }.joined(separator: "\n")
            return (comparison["basis"] as? String ?? "unknown") + " · " + (comparison["bootState"] as? String ?? "unknown") + "\n" + (changes.isEmpty ? "Sin diferencias observadas. No prueba funcionalidad." : details)
        }.joined(separator: "\n\n")
    }
    private var writeSummary: String {
        guard let event = events.last(where: { ($0["operation"] as? String)?.hasPrefix("write-") == true }) else {
            return "No hay eventos de escritura. Una lectura no verifica una escritura."
        }
        return (event["operation"] as? String ?? "unknown") + " · " + (event["outcome"] as? String ?? "unknown")
    }
    private func refresh() {
        do { report = try AdvancedDiagnostics.shared.report(pending: model.diagnosticPending); error = nil }
        catch { self.error = "No se pudo preparar el informe." }
    }
}
