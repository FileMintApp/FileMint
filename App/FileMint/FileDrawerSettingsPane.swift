import FileMintCore
import SwiftUI

struct FileDrawerSettingsPane: View {
    var openDrawer: @MainActor () -> Void = { FileDrawerController.shared.show() }
    var checkDiskRootAccess: @MainActor (PreferencesModel) async -> Bool = { await $0.hasSavedDrawerRootAccess() }
    @EnvironmentObject private var model: PreferencesModel
    @State private var sliderValue: Double?
    @State private var diskRootAuthorized: Bool?
    @State private var diskRootAccessRevision = 0

    private var settings: FileDrawerPreferences { model.preferences.fileDrawer }
    private func text(_ en: String, _ zh: String) -> String {
        model.preferences.language.resolved() == .chinese ? zh : en
    }

    private func binding<Value>(_ key: WritableKeyPath<FileDrawerPreferences, Value>) -> Binding<Value> {
        Binding(get: { settings[keyPath: key] }, set: {
            var value = settings
            value[keyPath: key] = $0
            model.setFileDrawer(value)
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: model.text(.fileDrawer)) {
                    let title = text("Enable File Drawer", "启用文件抽屉")
                    PreferenceRow(title: title, detail: text("Show File Drawer in the menu bar menu and File menu.",
                                                             "在菜单栏菜单和「文件」菜单中显示文件抽屉。")) {
                        Button(text("Open File Drawer", "打开文件抽屉"), action: openDrawer)
                            .disabled(!settings.enabled)
                            .accessibilityIdentifier("drawer.open")
                        Toggle(title, isOn: binding(\.enabled)).labelsHidden().accessibilityIdentifier("drawer.enabled")
                    }
                }
                openingControls.disabled(!settings.enabled)
                accessControls.disabled(!settings.enabled)
                SettingsSection(title: text("Global Shortcut", "全局快捷键")) {
                    GlobalShortcutControls(controller: model.drawerShortcuts, destination: .drawer)
                    Divider()
                    toggle(text("Show shortcut hints in the drawer", "在抽屉中显示快捷键提示"),
                           \.showsShortcutHints, id: "drawer.shortcutHints")
                }.disabled(!settings.enabled)
                SettingsSection(title: model.text(.appearance)) {
                    let side = text("Screen edge", "出现位置")
                    PreferenceRow(title: side) {
                        Picker(side, selection: binding(\.side)) {
                            Text(text("Left", "左侧")).tag(FileDrawerPreferences.Side.left)
                            Text(text("Right", "右侧")).tag(FileDrawerPreferences.Side.right)
                        }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 130)
                        .accessibilityIdentifier("drawer.side")
                    }
                    Divider()
                    toggle(text("Frosted glass", "毛玻璃"), \.glass, id: "drawer.glass")
                    Divider()
                    transparencyControl.disabled(!settings.glass)
                }.disabled(!settings.enabled)
                FileDrawerDimensionControls(axis: .horizontal).disabled(!settings.enabled)
                FileDrawerDimensionControls(axis: .vertical).disabled(!settings.enabled)
                SettingsSection(title: text("Preview", "预览")) {
                    toggle(text("Automatically preview small files", "自动预览小文件"), \.autoPreview,
                           id: "drawer.autoPreview",
                           detail: text("Files larger than 50 MB or of unknown size can be previewed on demand with Space.",
                                        "超过 50 MB 或大小未知的文件可按空格按需预览。"))
                }.disabled(!settings.enabled)
            }.toggleStyle(SmallSettingsSwitchStyle()).padding(1)
        }
    }

    private var openingControls: some View {
        SettingsSection(title: text("Opening Behavior", "打开行为")) {
            toggle(text("Remember Last Location", "记住上次位置"), \.remembersLastLocation,
                   id: "drawer.remembersLastLocation",
                   detail: text("Reopen the last folder when available. Turn this off to always start at the default location.",
                                "优先恢复上次浏览的位置。关闭后，每次打开都会使用默认位置。"))
            Divider()
            PreferenceRow(title: text("Default Drawer Location", "默认抽屉激活位置"),
                          detail: settings.defaultDirectoryPath ??
                            text("Choose where the drawer starts when it uses the default location.",
                                 "设置抽屉在使用默认位置时显示的文件夹。")) {
                if settings.defaultDirectoryPath != nil {
                    Button(text("Clear", "清除")) { binding(\.defaultDirectoryPath).wrappedValue = nil }
                }
                Button(text("Choose Folder…", "选择文件夹…"), action: chooseDefaultLocation)
                    .accessibilityIdentifier("drawer.chooseDefaultLocation")
            }
        }
    }

    private var accessControls: some View {
        SettingsSection(title: text("Access Permissions", "访问权限")) {
            PreferenceRow(title: text("Full Disk Access", "完全磁盘访问"),
                          detail: text("Read and write access to the disk root (/) and its folders is subject to macOS permissions.",
                                       "磁盘根目录（/）及其子目录的读写访问受 macOS 权限限制。")) {
                if diskRootAuthorized == true {
                    Label(text("Disk Root Authorized", "根目录已授权"), systemImage: "checkmark.circle")
                        .font(.callout).foregroundStyle(.secondary)
                        .accessibilityIdentifier("drawer.diskRootAuthorized")
                } else if diskRootAuthorized == false {
                    Button(text("Authorize Disk Root…", "授权根目录…"), action: authorizeDiskRoot)
                        .accessibilityIdentifier("drawer.authorizeDiskRoot")
                }
            }
        }
        .task(id: diskRootAccessRevision) {
            let authorized = await checkDiskRootAccess(model)
            guard !Task.isCancelled else { return }
            diskRootAuthorized = authorized
        }
        .onReceive(model.drawerAccessChanged) { _ in
            diskRootAuthorized = nil
            diskRootAccessRevision += 1
        }
    }

    private func chooseDefaultLocation() {
        let picker = model.fileDrawerDefaultLocationPanel()
        guard picker.runModal() == .OK, let url = picker.url else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        model.setFileDrawerDefaultLocation(url)
    }

    private func authorizeDiskRoot() {
        let picker = model.fileDrawerDiskRootPanel()
        guard picker.runModal() == .OK, let url = picker.url else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        model.authorizeFileDrawerDiskRoot(url)
    }

    private func toggle(_ title: String, _ key: WritableKeyPath<FileDrawerPreferences, Bool>,
                        id: String, detail: String? = nil) -> some View {
        PreferenceRow(title: title, detail: detail) {
            Toggle(title, isOn: binding(key))
                .labelsHidden().accessibilityIdentifier(id)
        }
    }

    private var transparencyControl: some View {
        let title = text("Background transparency", "背景透明度")
        return PreferenceRow(title: title) {
            Slider(value: Binding(
                get: { sliderValue ?? settings.transparency },
                set: { value in
                    if sliderValue != nil { sliderValue = value }
                    else { binding(\.transparency).wrappedValue = value }
                }
            ), in: 0...1, step: 0.05, onEditingChanged: { editing in
                if editing { sliderValue = settings.transparency }
                else if let value = sliderValue {
                    sliderValue = nil
                    binding(\.transparency).wrappedValue = value
                }
            })
            .accessibilityLabel(title).accessibilityIdentifier("drawer.transparency")
            .frame(width: 120)
            Text((sliderValue ?? settings.transparency).formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit().frame(width: 42, alignment: .trailing)
        }
    }
}

struct FileDrawerDimensionControls: View {
    let axis: Axis
    @EnvironmentObject private var model: PreferencesModel
    @State private var minimum = ""
    @State private var maximum = ""
    @State private var preferred = ""
    @State private var preferredWasEdited = false
    @FocusState private var editing: Field?
    private enum Field { case minimum, maximum, preferred }

    private var width: Bool { axis == .horizontal }
    private var limits: ClosedRange<Double> {
        width ? FileDrawerPreferences.supportedWidths : FileDrawerPreferences.supportedHeights
    }
    private var minKey: WritableKeyPath<FileDrawerPreferences, Double> { width ? \.minimumWidth : \.minimumHeight }
    private var maxKey: WritableKeyPath<FileDrawerPreferences, Double> { width ? \.maximumWidth : \.maximumHeight }
    private var preferredKey: WritableKeyPath<FileDrawerPreferences, Double> { width ? \.width : \.height }
    private var autoKey: WritableKeyPath<FileDrawerPreferences, Bool> { width ? \.fitsDisplayWidth : \.fitsDisplayHeight }
    private var settings: FileDrawerPreferences { model.preferences.fileDrawer }
    private var dimension: String { width ? "Width" : "Height" }
    private var chinese: Bool { model.preferences.language.resolved() == .chinese }
    private var label: String { chinese ? (width ? "宽度" : "高度") : dimension }
    private var savedNumbers: [Double] { [settings[keyPath: minKey], settings[keyPath: maxKey], settings[keyPath: preferredKey]] }

    private var edited: FileDrawerPreferences? {
        guard let lower = Int(minimum).map(Double.init), limits.contains(lower),
              let upper = Int(maximum).map(Double.init), limits.contains(upper), lower <= upper,
              let value = Int(preferred).map(Double.init), limits.contains(value) else { return nil }
        var next = settings
        next[keyPath: minKey] = lower
        next[keyPath: maxKey] = upper
        if preferredWasEdited {
            guard (lower...upper).contains(value) else { return nil }
            next[keyPath: preferredKey] = value
            next[keyPath: autoKey] = false
        } else {
            next[keyPath: preferredKey] = min(max(settings[keyPath: preferredKey], lower), upper)
        }
        return next
    }

    var body: some View {
        SettingsSection(title: label) {
            let fit = chinese ? label + "适应显示器" : "Fit " + dimension.lowercased() + " to display"
            PreferenceRow(title: fit) {
                Toggle(fit, isOn: Binding(get: { settings[keyPath: autoKey] }, set: { enabled in
                    var next = edited ?? settings
                    next[keyPath: autoKey] = enabled
                    if model.setFileDrawer(next) { reset() }
                })).labelsHidden().accessibilityIdentifier("drawer.fitsDisplay" + dimension)
            }
            Divider()
            numberField(chinese ? "最小" + label : "Minimum " + dimension.lowercased(),
                        value: $minimum, field: .minimum, id: "drawer.minimum" + dimension)
            Divider()
            numberField(chinese ? "最大" + label : "Maximum " + dimension.lowercased(),
                        value: $maximum, field: .maximum, id: "drawer.maximum" + dimension)
            Divider()
            numberField(chinese ? "固定" + label : "Fixed " + dimension.lowercased(),
                        value: Binding(get: { preferred }, set: { preferred = $0; preferredWasEdited = true }),
                        field: .preferred, id: "drawer." + dimension.lowercased())
            HStack {
                Text(feedback).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(chinese ? "应用" + label : "Apply " + dimension.lowercased(), action: apply)
                    .disabled(edited == nil || edited == settings)
                    .accessibilityIdentifier(width ? "drawer.applyWidths" : "drawer.applyHeight")
            }
        }
        .onAppear(perform: reset)
        .onChange(of: savedNumbers) { _ in reset() }
        .onChange(of: editing) { _ in apply() }
        .onDisappear(perform: apply)
    }

    private var feedback: String {
        if edited == nil {
            if preferredWasEdited, let lower = Int(minimum), let upper = Int(maximum), let fixed = Int(preferred),
               limits.contains(Double(lower)), limits.contains(Double(upper)), limits.contains(Double(fixed)),
               lower <= upper, !(lower...upper).contains(fixed) {
                return chinese ? "当前范围是 \(lower)–\(upper) pt。要使用 \(fixed) pt，请调整上下限。"
                    : "The current range is \(lower)–\(upper) pt. Adjust the limits to use \(fixed) pt."
            }
            let range = "\(Int(limits.lowerBound))–\(Int(limits.upperBound))"
            return chinese ? "请输入 \(range) pt 内的整数，最小值不能超过最大值。"
                : "Use whole numbers within \(range) pt. The minimum must be at or below the maximum."
        }
        return chinese ? "修改固定" + label + "会关闭此方向的自动适应。"
            : "Editing the fixed " + dimension.lowercased() + " turns off automatic sizing for this dimension."
    }

    private func numberField(_ title: String, value: Binding<String>, field: Field, id: String) -> some View {
        PreferenceRow(title: title) {
            HStack(spacing: 5) {
                TextField(title, text: value).labelsHidden().frame(width: 66)
                    .multilineTextAlignment(.trailing).accessibilityIdentifier(id)
                    .focused($editing, equals: field).onSubmit(apply)
                Text("pt").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func apply() {
        guard let next = edited, next != settings else { return }
        if model.setFileDrawer(next) { reset() }
    }

    private func reset() {
        minimum = String(Int(settings[keyPath: minKey].rounded()))
        maximum = String(Int(settings[keyPath: maxKey].rounded()))
        preferred = String(Int(settings[keyPath: preferredKey].rounded()))
        preferredWasEdited = false
    }
}
