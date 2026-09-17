# Finder extension enablement

Checked against Apple sources on 2026-09-17.

macOS discovers the Finder Sync extension embedded in the app and manages its
process. This is separate from the user's enabled/disabled choice. With
FileMint's current App Sandbox configuration, the reviewed public APIs do not
provide a supported way to silently turn that choice on at launch.

- Apple's [Finder Sync guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
  describes the extension's bundle metadata and system-managed loading.
- [`isExtensionEnabled`](https://developer.apple.com/documentation/findersync/fifindersynccontroller/isextensionenabled)
  is read-only. [`showExtensionManagementInterface()`](https://developer.apple.com/documentation/findersync/fifindersynccontroller/showextensionmanagementinterface())
  opens the system management interface; it does not set approval.
- [Apple Support](https://support.apple.com/en-md/guide/mac-help/mtusr003/mac)
  documents selecting the extension's checkbox in Login Items & Extensions.
- In the [Apple DTS discussion of macOS 15](https://developer.apple.com/forums/thread/756711),
  Kevin Elliott explains that `pluginkit` can work in Terminal or an unsandboxed
  app, but not when launched by a sandboxed app, and should not be assumed to
  remain a long-term solution. The same discussion retracts the suggested use
  of `EXAppExtensionBrowserViewController` for this Finder Sync case.

Product decision: retain the sandbox and public APIs. Explain the required user
step, offer the system settings button, and refresh actual extension status when
the app becomes active again. In-app New File remains usable before extension
approval. No silent enablement, private API, injected code or shell-based system
setting change is added. These sources establish the supported integration
boundary, not a claim that every unsandboxed workaround is prohibited by Apple.
