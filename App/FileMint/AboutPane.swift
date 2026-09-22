import AppKit
import FileMintCore
import SwiftUI

struct AboutPane: View {
    @EnvironmentObject private var model: PreferencesModel
    @EnvironmentObject private var updater: UpdateModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 76, height: 76).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FileMint").font(.system(size: 27, weight: .semibold))
                        Text("\(model.text(.version)) \(updater.currentVersion) (\(updater.buildNumber))")
                            .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text(model.text(.copyright)).foregroundStyle(.secondary)
                        Text("© \(FileMintAbout.copyright)").textSelection(.enabled)
                    }
                    GridRow {
                        Text(model.text(.developers)).foregroundStyle(.secondary)
                        Text(FileMintAbout.developers.joined(separator: " · ")).textSelection(.enabled)
                    }
                    GridRow(alignment: .top) {
                        Text(model.text(.specialThanks)).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Link(FileMintAbout.specialThanksName, destination: FileMintAbout.specialThanksURL)
                                .buttonStyle(.link)
                            Text(model.text(.signingThanks)).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.font(.system(size: 12)).mintSurface()
                HStack(spacing: 18) {
                    Link(model.text(.projectPage), destination: FileMintAbout.projectURL)
                    Link(model.text(.license), destination: FileMintAbout.licenseURL)
                    Link(model.text(.privacyPolicy), destination: FileMintAbout.privacyURL)
                }.font(.callout).buttonStyle(.link)
                SettingsSection(title: model.text(.updates)) {
                    Text(model.text(updater.statusKey))
                        .font(.callout).foregroundStyle(updater.isFailure ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("updateStatus")
                    if let update = updater.update {
                        HStack(spacing: 8) {
                            Text("\(model.text(.availableVersion)) \(update.version.description)")
                            Text(ByteCountFormatter.string(fromByteCount: update.size, countStyle: .file))
                                .foregroundStyle(.secondary)
                        }.font(.callout)
                    }
                    if updater.state == .downloading {
                        HStack {
                            ProgressView(value: updater.progress).accessibilityLabel(model.text(.updateDownloading))
                            Text(updater.progress, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.monospacedDigit()).frame(width: 38, alignment: .trailing)
                        }
                    } else if updater.isBusy {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel(model.text(updater.statusKey))
                    }
                    HStack(spacing: 10) {
                        if updater.canCancel {
                            Button(model.text(.cancel)) { updater.cancel() }
                        } else if !updater.isBusy {
                            Button(model.text(.checkForUpdates)) { updater.checkForUpdates() }
                            if updater.canDownload {
                                Button(model.text(.downloadUpdate)) { updater.downloadUpdate() }
                                    .buttonStyle(MintButtonStyle(primary: true))
                            }
                        }
                        if updater.state == .waitingToRestart {
                            Button(model.text(.updateRestartNow)) { updater.retryInstallationRestart() }
                        }
                        Spacer()
                        Link(model.text(.releaseNotes), destination: updater.update?.releaseURL ?? FileMintAbout.releasesURL)
                            .buttonStyle(.link)
                    }
                    if updater.update != nil {
                        Text(model.text(.updateInstallHint)).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.padding(1)
        }
    }
}
