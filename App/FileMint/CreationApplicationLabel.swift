import AppKit
import FileMintCore
import SwiftUI

@MainActor
enum CreationApplicationPresentation {
    static func icon(for application: CreationApplication) async -> NSImage? {
        let app = application.openWithApplication
        let resolved = await Task.detached(priority: .utility) { () -> URL? in
            guard let url = try? OpenWithApplicationAccess.resolve(app) else { return nil }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            guard (try? OpenWithApplicationAccess.validate(app, at: url)) != nil else { return nil }
            return url
        }.value
        guard !Task.isCancelled, let resolved else { return nil }
        let granted = resolved.startAccessingSecurityScopedResource()
        defer { if granted { resolved.stopAccessingSecurityScopedResource() } }
        return FileToolAppearance.applicationImage(at: resolved, size: 20)
    }
}

struct CreationApplicationLabel: View {
    let name: String
    let application: CreationApplication?
    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: 7) {
            Group {
                if let icon { Image(nsImage: icon).resizable() }
                else { Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary) }
            }.frame(width: 20, height: 20).accessibilityHidden(true)
            Text(name).lineLimit(1).truncationMode(.middle).help(name)
        }
        .task(id: application) {
            icon = nil
            guard let application else { return }
            let loaded = await CreationApplicationPresentation.icon(for: application)
            guard !Task.isCancelled else { return }
            icon = loaded
        }
    }
}
