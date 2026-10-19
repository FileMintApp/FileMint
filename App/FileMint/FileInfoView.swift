import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

struct FileInfoView: View {
    @ObservedObject var model: FileInfoController
    @State private var pathExpanded = false
    @State private var comparisonExpanded = false
    private func text(_ key: FileInfoText) -> String { model.text(key) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    summary
                    Divider()
                    algorithm
                    results
                    DisclosureGroup(text(.comparison), isExpanded: $comparisonExpanded) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text(text(.expected)).font(.callout)
                            TextField(text(.expected), text: $model.expectedChecksum)
                                .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                                .accessibilityIdentifier("fileInfo.expected")
                                .disabled(model.choice == .all || model.isWorking)
                            Label(comparisonText, systemImage: comparisonSymbol)
                                .font(.callout).fixedSize(horizontal: false, vertical: true)
                        }.padding(.top, 10)
                    }.disabled(model.metadata?.canCalculate != true)
                }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let feedback = model.feedback {
                    Text(text(feedback)).font(.callout).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("fileInfo.status")
                }
                HStack {
                    Spacer()
                    Button(text(.close)) { model.requestClose() }
                        .accessibilityIdentifier("fileInfo.close")
                    if model.isWorking {
                        Button(text(.cancel)) { model.cancel() }.disabled(model.isCancelling)
                            .accessibilityIdentifier("fileInfo.cancel")
                    } else {
                        Button(text(model.result == nil ? .calculate : .recalculate)) { model.calculate() }
                            .buttonStyle(.borderedProminent).disabled(!model.canCalculate)
                            .accessibilityIdentifier("fileInfo.calculate")
                    }
                }
            }.padding(.horizontal, 26).padding(.vertical, 16)
        }.background(FileMintStyle.background).tint(FileMintStyle.accent)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: model.metadata?.kind == .directory ? "folder" : "doc.text")
                    .font(.system(size: 30)).foregroundStyle(FileMintStyle.accent).accessibilityHidden(true)
                Text(model.selection?.source.lastPathComponent ?? text(.title))
                    .font(.title3.weight(.semibold)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("fileInfo.name")
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                row(.type, typeDescription)
                row(.size, model.metadata?.logicalSize.map {
                    "\(ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)) (\($0) B)"
                } ?? text(.unavailable))
                row(.created, model.metadata?.createdAt.map(date) ?? text(.unavailable))
                row(.modified, model.metadata?.modifiedAt.map(date) ?? text(.unavailable))
            }.font(.callout)
            DisclosureGroup(text(.location), isExpanded: $pathExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.selection?.source.path ?? text(.unavailable))
                        .font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fileInfo.path")
                    Button(text(.copyPath)) {
                        if let value = model.selection?.source.path { model.copy(value) }
                    }
                }.padding(.top, 8).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.callout)
        }
    }

    private func row(_ label: FileInfoText, _ value: String) -> some View {
        GridRow(alignment: .top) {
            Text(text(label)).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var algorithm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text(.algorithm)).font(.headline)
            Picker(text(.algorithm), selection: Binding(get: { model.choice }, set: { model.select($0) })) {
                ForEach(FileDigestChoice.allCases, id: \.self) { value in
                    Text(text(value.title)).tag(value)
                }
            }.pickerStyle(.menu).labelsHidden().fixedSize()
                .disabled(model.isWorking || model.metadata?.canCalculate != true)
                .accessibilityIdentifier("fileInfo.algorithm")
            Label(text(model.choice.hint), systemImage: "info.circle")
                .font(.callout).foregroundStyle(model.choice.includesLegacy
                    ? Color(nsColor: FileMintStyle.adaptive(0x805A16, 0xE2BB73)) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let reason = unsupportedReason {
                Text(text(reason)).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isWorking {
                if let progress = model.progress {
                    ProgressView(value: Double(progress.bytesRead), total: Double(max(1, progress.totalBytes)))
                        .accessibilityLabel(text(.calculate))
                    Text("\(progress.bytesRead) / \(progress.totalBytes) B")
                        .font(.system(.callout, design: .monospaced))
                }
                Text(text(model.isCancelling ? .stopping : model.isPreparing ? .preparing : model.progress == nil ? .waiting : .reading)).font(.callout)
            } else if let result = model.result {
                ForEach(result.values, id: \.algorithm) { value in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(value.algorithm.rawValue).font(.headline)
                            Spacer()
                            Button(text(.copy)) { model.copyResult(value.algorithm) }
                                .accessibilityLabel("\(text(.copy)) \(value.algorithm.rawValue)")
                        }
                        Text(value.hexadecimal).font(.system(.body, design: .monospaced))
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(value.hexadecimal)
                    }
                }
                if model.choice == .all { Button(text(.copyAll)) { model.copyResult() } }
                Text(text(.readScope)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else { Text(text(.notCalculated)).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func date(_ value: Date) -> String {
        value.formatted(.dateTime.locale(Locale(identifier: model.language.resolved() == .chinese ? "zh_CN" : "en_US"))
            .year().month().day().hour().minute().second())
    }
    private var typeDescription: String {
        if let identifier = model.metadata?.typeIdentifier, let type = UTType(identifier)?.localizedDescription { return type }
        guard let kind = model.metadata?.kind else { return text(.unavailable) }
        return text(kind == .directory ? .directory : kind == .file ? .file : .unsupported)
    }
    private var unsupportedReason: FileInfoText? {
        guard let metadata = model.metadata else { return nil }
        if metadata.isPlaceholder { return .placeholder }
        switch metadata.kind { case .file: return nil; case .directory: return .directoryHint; case .unsupported: return .unsupported }
    }
    private var comparisonText: String {
        let key: FileInfoText = switch model.comparison {
        case .empty: .emptyComparison; case .chooseSingleAlgorithm: .chooseSingle
        case .invalid: .invalidComparison; case .unavailable: .calculateFirst; case .match: .match; case .mismatch: .mismatch
        }
        return text(key)
    }
    private var comparisonSymbol: String {
        switch model.comparison { case .match: "checkmark.circle"; case .mismatch: "xmark.circle"; default: "info.circle" }
    }
}
