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
    private func refresh() {
        do { report = try AdvancedDiagnostics.shared.report(pending: model.diagnosticPending); error = nil }
        catch { self.error = "No se pudo preparar el informe." }
    }
}
