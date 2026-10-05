import FileMintCore
import SwiftUI

@MainActor
final class TemplatePackageReview: ObservableObject, Identifiable {
    let id = UUID()
    let package: ValidatedTemplatePackage
    @Published var plan: TemplateImportPlan
    @Published var choices: [String: TemplateImportChoice] = [:]
    @Published var adoptDefaults = false
    @Published var message: String?
    @Published var isPlanning = false
    @Published var isPlanValid = true
    var canConfirm: Bool { isPlanValid && !isPlanning && plan.acceptedCount > 0 }
    var generation = UUID()
    init(package: ValidatedTemplatePackage, plan: TemplateImportPlan) { self.package = package; self.plan = plan }
}

struct TemplateImportReviewView: View {
    @EnvironmentObject private var model: PreferencesModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var review: TemplatePackageReview
    @State private var selectedID: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.workflowText(.importPackage)).font(.title2)
            Text("\(review.plan.acceptedCount) \(model.workflowText(.add)) · \(review.plan.rows.filter { $0.choice == .skip }.count) \(model.workflowText(.skip))")
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(review.plan.rows) { row in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Button(row.incoming.displayName + " (." + row.incoming.fileExtension + ")") { selectedID = row.id }.buttonStyle(.plain).font(.headline)
                                if let name = row.resultName, name != row.incoming.displayName { Text("→ " + name).font(.caption) }
                                if model.preferences.creationOpeningEnabled {
                                    Text(model.workflowText(row.incoming.afterCreation.kind.textKey) + (row.incoming.afterCreation.application.map { " · " + $0.displayName } ?? ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Picker("", selection: Binding(get: { review.choices[row.id] ?? row.choice }, set: {
                                review.choices[row.id] = $0; model.rebuildTemplateReview(review)
                            })) {
                                ForEach(row.allowedChoices, id: \.self) { choice in
                                    Text(model.workflowText(choice == .add ? .add : choice == .skip ? .skip : .saveCopy)).tag(choice)
                                }
                            }.labelsHidden().frame(width: 145)
                        }.padding(10).background(FileMintStyle.soft, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
            if let row = review.plan.rows.first(where: { $0.id == selectedID }) ?? review.plan.rows.first,
               let descriptor = review.package.descriptors.first(where: { $0.id == row.incoming.payloadID }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.incoming.suggestedFileName + " · " + row.incoming.group + " · \(descriptor.byteCount) B").font(.caption)
                    Text(row.incoming.isEnabled ? (model.preferences.language.resolved() == .chinese ? "已启用" : "Enabled") : (model.preferences.language.resolved() == .chinese ? "未启用" : "Disabled")).font(.caption).foregroundStyle(.secondary)
                    if model.preferences.templatePreviewEnabled {
                        TemplatePreviewView(template: previewTemplate(row, descriptor: descriptor), assets: model.documentTemplates,
                            language: model.preferences.language, documentBytes: descriptor.kind == .utf8Text ? nil : review.package.payloads[descriptor.id])
                            .frame(height: 130)
                        Text(model.workflowText(.exampleContext)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Toggle(model.workflowText(.adoptDefaults), isOn: Binding(get: { review.adoptDefaults }, set: {
                review.adoptDefaults = $0; model.rebuildTemplateReview(review)
            }))
            ForEach(Array(review.plan.defaultChanges.enumerated()), id: \.offset) { _, change in
                let before = change.before.flatMap { id in model.preferences.templates.first { $0.id == id }?.displayName } ?? "—"
                let after = change.after.flatMap { id in review.plan.preferences.templates.first { $0.id == id }?.displayName } ?? "—"
                Text(".\(change.suffix): \(before) → \(after)").font(.caption)
            }
            if let message = review.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            HStack {
                if review.isPlanning || model.isMutatingTemplates { ProgressView().controlSize(.small) }
                Spacer()
                Button(model.text(.cancel)) { model.packageReview = nil; dismiss() }.keyboardShortcut(.cancelAction)
                    .disabled(model.isMutatingTemplates)
                Button(model.workflowText(.confirmImport)) { Task { await model.confirmTemplateImport(review) } }
                    .keyboardShortcut(.defaultAction).disabled(!review.canConfirm || model.isMutatingTemplates)
            }
        }.padding(24).frame(width: 630, height: 550).background(FileMintStyle.background)
            .onAppear { model.hasTemplateModalWork = true }
            .onDisappear { model.hasTemplateModalWork = false }
    }
    private func previewTemplate(_ row: TemplateImportRow, descriptor: TemplatePackagePayload) -> FileTemplate {
        let bytes = review.package.payloads[descriptor.id] ?? Data()
        var template = FileTemplate(id: row.id, displayName: row.incoming.displayName,
            suggestedFileName: row.incoming.suggestedFileName, group: row.incoming.group,
            content: descriptor.kind == .utf8Text ? String(decoding: bytes, as: UTF8.self) : "", rank: 0,
            fileExtension: row.incoming.fileExtension)
        if let kind = OfficeDocumentKind(rawValue: descriptor.kind.rawValue) {
            template.document = .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, kind: kind,
                byteCount: descriptor.byteCount, sha256: descriptor.sha256)
        }
        return template
    }
}

struct TemplateExportSelectionView: View {
    @EnvironmentObject private var model: PreferencesModel
    @Environment(\.dismiss) private var dismiss
    let selectedID: String?
    @State private var scope = TemplateWorkflowText.selected
    @State private var customIDs: Set<String> = []
    private var ids: Set<String> {
        switch scope {
        case .enabled: Set(model.preferences.templates.filter(\.isEnabled).map(\.id))
        case .all: Set(model.preferences.templates.map(\.id))
        case .custom: customIDs
        default: selectedID.map { [$0] } ?? []
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.workflowText(.exportSelection)).font(.title2)
            Picker(model.workflowText(.exportSelection), selection: $scope) {
                Text(model.workflowText(.selected)).tag(TemplateWorkflowText.selected)
                Text(model.workflowText(.enabled)).tag(TemplateWorkflowText.enabled)
                Text(model.workflowText(.all)).tag(TemplateWorkflowText.all)
                Text(model.workflowText(.custom)).tag(TemplateWorkflowText.custom)
            }.labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(model.preferences.templates) { template in
                        Toggle(model.templateDisplayName(for: template) + " (." + template.fileExtension + ")", isOn: Binding(
                            get: { ids.contains(template.id) }, set: { enabled in
                                if enabled { customIDs.insert(template.id) } else { customIDs.remove(template.id) }
                            })).disabled(scope != .custom)
                    }
                }
            }
            Text("\(ids.count) / \(model.preferences.templates.count)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(model.text(.cancel)) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(model.workflowText(.exportPackage)) {
                    let selection = ids; dismiss()
                    Task { await model.exportTemplatePackage(ids: selection) }
                }.keyboardShortcut(.defaultAction).disabled(ids.isEmpty)
            }
        }.padding(24).frame(width: 480, height: 420).background(FileMintStyle.background)
            .onAppear { customIDs = selectedID.map { [$0] } ?? []; model.hasTemplateModalWork = true }
            .onDisappear { model.hasTemplateModalWork = false }
    }
}
