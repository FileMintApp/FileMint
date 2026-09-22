import SwiftUI
import FileMintCore

@ViewBuilder
private func resourceToolIcon(_ tool: ResourceTool, size: CGFloat) -> some View {
    if let image = FileToolAppearance.image(for: tool, size: size) {
        Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
    } else {
        Image(systemName: tool.symbol).font(.system(size: size, weight: .regular))
    }
}

struct ResourceToolsPane: View {
    var launchTool: (ResourceTool) -> Void = { FileOperationCoordinator.shared.chooseImages(for: $0) }
    @EnvironmentObject private var model: PreferencesModel
    @State private var menuSettings = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 24) {
                tab(.useTools, selected: !menuSettings) { menuSettings = false }
                tab(.menuSettings, selected: menuSettings) { menuSettings = true }
                Spacer()
            }.overlay(alignment: .bottom) { FileMintStyle.line.frame(height: 0.5) }
            ScrollView {
                if menuSettings { settings }
                else {
                    VStack(alignment: .leading, spacing: 22) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                            ForEach(ResourceTool.allCases) { tool in
                                ResourceToolCard(tool: tool, language: model.preferences.language) {
                                    launchTool(tool)
                                }
                            }
                        }
                        Label(InterfaceText.finderTip.text(model.preferences.language), systemImage: "cursorarrow")
                            .font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(1)
                }
            }
        }
    }

    private func tab(_ key: InterfaceText, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(key.text(model.preferences.language)).font(.system(size: 12, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) { (selected ? FileMintStyle.accent : Color.clear).frame(height: 2) }
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 26) {
            PreferenceRow(title: InterfaceText.menuEnabled.text(model.preferences.language),
                detail: ResourceText.hint.text(model.preferences.language)) {
                Toggle(InterfaceText.menuEnabled.text(model.preferences.language), isOn: $model.preferences.resourceTools.isEnabled)
                    .labelsHidden().toggleStyle(SmallSettingsSwitchStyle())
                    .onChange(of: model.preferences.resourceTools.isEnabled) { _ in model.save() }
            }.mintSurface()
            VStack(spacing: 15) {
                ForEach(ResourceTool.allCases) { tool in
                    if tool != ResourceTool.allCases.first { Divider() }
                    PreferenceRow(title: tool.title(model.preferences.language).replacingOccurrences(of: "…", with: ""),
                        detail: tool.summary(model.preferences.language)) {
                        Toggle(tool.title(model.preferences.language), isOn: Binding(
                            get: { model.preferences.resourceTools.enabledTools.contains(tool) },
                            set: { value in
                                if value { model.preferences.resourceTools.enabledTools.insert(tool) }
                                else { model.preferences.resourceTools.enabledTools.remove(tool) }
                                model.save()
                            })).labelsHidden().toggleStyle(SmallSettingsSwitchStyle())
                            .accessibilityIdentifier("resourceTools.\(tool.rawValue)")
                    }
                }
            }.mintSurface().disabled(!model.preferences.resourceTools.isEnabled)
                .saturation(model.preferences.resourceTools.isEnabled ? 1 : 0)
                .opacity(model.preferences.resourceTools.isEnabled ? 1 : 0.5)
        }.padding(1)
    }
}

private struct ResourceToolCard: View {
    let tool: ResourceTool
    let language: AppLanguage
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 13) {
                resourceToolIcon(tool, size: 21).frame(width: 25, height: 25).padding(.top, 2)
                VStack(alignment: .leading, spacing: 7) {
                    Text(tool.title(language).replacingOccurrences(of: "…", with: "")).font(.system(size: 13, weight: .medium))
                    Text(tool.summary(language)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(19).frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
                .background(hovering ? FileMintStyle.soft : FileMintStyle.surface,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).onHover { hovering = $0 }.accessibilityIdentifier("resource.launch.\(tool.rawValue)")
    }
}

struct ResourceToolsView: View {
    @ObservedObject var model: ResourceToolsController
    @State private var details = false
    private func text(_ key: ResourceText) -> String { key.text(model.language) }
    private func label(_ key: InterfaceText) -> String { key.text(model.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                resourceToolIcon(model.tool, size: 20).frame(width: 22, height: 22)
                Text(model.tool.title(model.language).replacingOccurrences(of: "…", with: ""))
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Label(label(.localOnly), systemImage: "checkmark.shield")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                FileMintStyle.line.frame(width: 0.7)
                inspector.frame(width: model.tool == .ocr ? 300 : 240)
            }
            .background(FileMintStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
            if let message = model.message {
                Text(message).font(.system(size: 11)).foregroundStyle(model.result?.failure == nil ? Color.secondary : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            footer
        }.padding(24).background(FileMintStyle.background).tint(FileMintStyle.accent)
            .frame(minWidth: 800, minHeight: 530)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(model.selectedInput?.url.lastPathComponent ?? text(.selected), systemImage: "photo")
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if model.isPreparing { ProgressView().controlSize(.mini) }
                Text(label(.preview)).foregroundStyle(.tertiary)
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack {
                    TransparencyGrid()
                    if model.tool == .stitch {
                        stitchPreview(size: proxy.size)
                    } else if let input = model.selectedInput, let image = model.thumbnails[input.url] {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(width: model.tool == .icons ? min(210, proxy.size.width - 32) : max(1, proxy.size.width - 24),
                                   height: max(1, proxy.size.height - 24))
                    } else {
                        VStack(spacing: 9) {
                            Image(systemName: "photo").font(.system(size: 27))
                            Text(label(.previewMissing)).font(.system(size: 11))
                        }.foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            }.frame(minHeight: 150)
            HStack {
                if let input = model.selectedInput, let size = model.dimensions[input.url] {
                    Text("\(size.width) × \(size.height)").monospacedDigit()
                }
                Spacer()
                Text(model.tool == .icons ? label(.fitting) : label(.original))
            }.font(.system(size: 10)).foregroundStyle(.secondary)
            Divider()
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Array(model.inputs.enumerated()), id: \.element.url) { index, input in
                        Button { model.select(index) } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    if let image = model.thumbnails[input.url] {
                                        Image(nsImage: image).resizable().scaledToFit()
                                    } else { Image(systemName: "photo").foregroundStyle(.secondary) }
                                }.frame(width: 47, height: 40)
                                Text("\(index + 1)").font(.system(size: 9)).foregroundStyle(.secondary)
                            }.padding(4).background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                                    model.selectedIndex == index ? FileMintStyle.accent : Color.clear, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityLabel(input.url.lastPathComponent)
                            .accessibilityAddTraits(model.selectedIndex == index ? .isSelected : [])
                    }
                }.padding(1)
            }.frame(height: 65)
            if model.tool == .stitch {
                HStack {
                    Text("\(text(.selected)) · \(model.inputs.count)").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.move(model.selectedIndex, by: -1) } label: { Image(systemName: "arrow.left") }
                        .disabled(model.selectedIndex == 0).help(text(.moveUp)).accessibilityLabel(text(.moveUp))
                    Button { model.move(model.selectedIndex, by: 1) } label: { Image(systemName: "arrow.right") }
                        .disabled(model.selectedIndex + 1 >= model.inputs.count).help(text(.moveDown)).accessibilityLabel(text(.moveDown))
                }.disabled(model.isRunning || model.result != nil).controlSize(.small)
            }
        }.padding(17).background(FileMintStyle.soft)
    }

    private func stitchPreview(size: CGSize) -> some View {
        let shown = Array(model.inputs.prefix(20))
        let dimensions = shown.compactMap { model.dimensions[$0.url] }
        let layout = dimensions.count == shown.count
            ? try? ImageStitchLayout(inputs: dimensions, edge: model.options.stitchEdge, horizontal: model.options.horizontal) : nil
        return Canvas { context, canvas in
            guard let layout else { return }
            let factor = min((canvas.width - 24) / CGFloat(layout.canvas.width),
                             (canvas.height - 24) / CGFloat(layout.canvas.height))
            let origin = CGPoint(x: (canvas.width - CGFloat(layout.canvas.width) * factor) / 2,
                                 y: (canvas.height - CGFloat(layout.canvas.height) * factor) / 2)
            var offset: CGFloat = 0
            for (index, input) in shown.enumerated() {
                let part = layout.sizes[index]
                let rect = CGRect(x: origin.x + (model.options.horizontal ? offset : 0),
                                  y: origin.y + (model.options.horizontal ? 0 : offset),
                                  width: CGFloat(part.width) * factor, height: CGFloat(part.height) * factor)
                if let image = model.thumbnails[input.url] { context.draw(Image(nsImage: image), in: rect) }
                else { context.fill(Path(rect), with: .color(FileMintStyle.line)) }
                offset += (model.options.horizontal ? rect.width : rect.height)
            }
        }.overlay(alignment: .bottom) {
            if model.inputs.count > 20 { Text(text(.previewHint)).font(.system(size: 10)).padding(8).background(FileMintStyle.surface) }
            else if layout == nil && !model.isPreparing {
                Text(ResourceError.dimensionsTooLarge.message(model.language)).font(.system(size: 11))
                    .foregroundStyle(.secondary).padding(12)
            }
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.tool == .ocr { ocrResult }
                else {
                    options.disabled(model.isRunning || model.result != nil)
                    VStack(alignment: .leading, spacing: 9) {
                        inspectorLabel(text(.output))
                        Button { model.chooseDestination() } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(model.destination?.lastPathComponent ?? text(.sourceFolder)).lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down").font(.system(size: 9))
                            }
                        }.buttonStyle(MintButtonStyle()).disabled(model.isRunning || model.result != nil)
                        if let destination = model.destination {
                            Text(destination.path).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                Label(label(.keepOriginal), systemImage: "checkmark.shield").font(.system(size: 11)).foregroundStyle(.secondary)
                DisclosureGroup(label(.more), isExpanded: $details) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(text(.limits))
                        Text(text(model.tool == .ocr ? .accuracyHint : .originalHint))
                    }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 8)
                }.font(.system(size: 11))
                if let result = model.result {
                    Text("\(text(result.cancelled ? .cancelled : result.failure != nil ? .failed : .completed)) · \(result.completed)/\(model.inputs.count)")
                        .font(.system(size: 11, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    if result.completed == 0, result.failure != nil {
                        Button(text(.editOptions)) { model.editOptions() }.buttonStyle(MintButtonStyle())
                    }
                }
            }.padding(18)
        }
    }

    private func inspectorLabel(_ value: String) -> some View {
        Text(value).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
    }

    @ViewBuilder private var options: some View {
        if model.tool == .convert || model.tool == .resize || model.tool == .icons {
            VStack(alignment: .leading, spacing: 10) {
                inspectorLabel(text(.format))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(model.formats) { format in
                        Button { model.options.format = format } label: {
                            Text(format == .pngSet ? text(.pngSet) : format.rawValue.uppercased())
                                .font(.system(size: 11)).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(model.options.format == format ? FileMintStyle.selection : FileMintStyle.background,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                                    model.options.format == format ? FileMintStyle.accent : FileMintStyle.line, lineWidth: 0.7))
                        }.buttonStyle(.plain).accessibilityAddTraits(model.options.format == format ? .isSelected : [])
                    }
                }
                if model.options.format == .jpeg { Text(text(.whiteBackground)).font(.system(size: 10)).foregroundStyle(.secondary) }
            }
        }
        if model.tool == .compress || ((model.tool == .convert || model.tool == .resize) && model.options.format.isLossy) {
            VStack(spacing: 8) {
                HStack {
                    inspectorLabel(text(.quality)); Spacer()
                    Text(model.options.quality, format: .percent.precision(.fractionLength(0))).font(.system(size: 11)).monospacedDigit()
                }
                Slider(value: $model.options.quality, in: 0.1...1, step: 0.05).accessibilityLabel(text(.quality))
            }
        }
        if model.tool == .compress { Text(text(.compressHint)).font(.system(size: 10)).foregroundStyle(.secondary) }
        if model.tool == .resize {
            VStack(alignment: .leading, spacing: 9) {
                inspectorLabel(text(.longestEdge))
                TextField(text(.longestEdge), value: $model.options.longestEdge, format: .number.grouping(.never)).textFieldStyle(.roundedBorder)
                Text(label(.reduceWithoutUpscale)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        if model.tool == .icons { Text(text(.iconHint)).font(.system(size: 10)).foregroundStyle(.secondary) }
        if model.tool == .stitch {
            VStack(alignment: .leading, spacing: 10) {
                inspectorLabel(text(.direction))
                Picker(text(.direction), selection: $model.options.horizontal) {
                    Text(text(.vertical)).tag(false); Text(text(.horizontal)).tag(true)
                }.pickerStyle(.segmented).labelsHidden()
                inspectorLabel(label(model.options.horizontal ? .pixelHeight : .pixelWidth))
                TextField(label(.outputSize), value: $model.options.stitchEdge, format: .number.grouping(.never)).textFieldStyle(.roundedBorder)
            }
        }
    }

    private var ocrResult: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorLabel(label(.textResult))
            if model.result != nil {
                if model.hasText || model.editedText != nil {
                    PlainTextEditor(text: Binding(get: { model.text }, set: { model.setEditedText($0) }), label: label(.textResult))
                        .font(.system(size: 12)).frame(minHeight: 245)
                        .padding(7).background(FileMintStyle.background, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                    Button(text(.copyText)) { model.copyText() }.buttonStyle(MintButtonStyle()).disabled(model.isRunning || !model.hasText)
                } else { Text(text(.noText)).font(.system(size: 12)).foregroundStyle(.secondary) }
            } else {
                Text(text(.ocrHint)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if model.isRunning {
                    ProgressView(value: Double(model.completed), total: Double(max(1, model.inputs.count))).frame(width: 160)
                    Text(model.isCancelling ? text(.cancelling) : "\(text(.working)) \(model.completed)/\(model.inputs.count)")
                } else {
                    Text("\(text(.selected)) · \(model.inputs.count)")
                    Text(label(.keepOriginal)).foregroundStyle(.tertiary)
                }
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button(text(model.isRunning ? .cancel : .close)) { model.cancel() }.keyboardShortcut(.cancelAction)
                .buttonStyle(MintButtonStyle()).disabled(model.isCancelling || model.isSavingText)
            if model.result == nil {
                Button(model.tool == .ocr ? model.tool.title(model.language).replacingOccurrences(of: "…", with: "") : label(.start)) { model.run() }
                    .keyboardShortcut(.defaultAction).buttonStyle(MintButtonStyle(primary: true))
                    .disabled(model.isRunning || model.isPreparing || model.inputs.isEmpty)
            } else if model.tool == .ocr && model.hasText {
                Button(text(.saveText)) { model.saveText() }.buttonStyle(MintButtonStyle(primary: true)).disabled(model.isRunning)
            } else if !(model.result?.outputs.isEmpty ?? true) {
                Button(text(.showOutputs)) { model.showOutputs() }.buttonStyle(MintButtonStyle(primary: true))
            }
        }
    }
}

private struct TransparencyGrid: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(FileMintStyle.surface))
            for row in 0...Int(size.height / 12) {
                for column in 0...Int(size.width / 12) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: column * 12, y: row * 12, width: 12, height: 12)),
                                 with: .color(FileMintStyle.soft))
                }
            }
        }.accessibilityHidden(true)
    }
}
