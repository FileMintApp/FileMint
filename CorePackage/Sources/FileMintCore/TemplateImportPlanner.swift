import Foundation

public enum TemplateImportChoice: String, CaseIterable, Sendable { case add, skip, copy }
public struct TemplateImportRow: Identifiable, Sendable {
    public let id: String
    public let incoming: PortableTemplate
    public let choice: TemplateImportChoice
    public let allowedChoices: [TemplateImportChoice]
    public let resultID: String?
    public let resultName: String?
    public let identical: Bool
}
public struct TemplatePlannedAsset: Sendable {
    public let reference: DocumentTemplateReference
    public let bytes: Data
}
public struct TemplateDefaultChange: Sendable {
    public let suffix: String
    public let before: String?
    public let after: String?
}
public struct TemplateImportPlan: Sendable {
    public let baseRevision: String
    public let inputDigest: String
    public let rows: [TemplateImportRow]
    public let preferences: FileMintPreferences
    public let assets: [TemplatePlannedAsset]
    public let defaultChanges: [TemplateDefaultChange]
    public var acceptedCount: Int { rows.filter { $0.choice != .skip }.count }
}

public enum TemplateImportPlanner {
    public static func revision(_ preferences: FileMintPreferences) throws -> String {
        var canonical = preferences
        canonical.templates = TemplateCatalog.sortedTemplates(from: preferences.templates)
        canonical.removedBuiltInTemplateIDs.sort()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var object = try JSONSerialization.jsonObject(with: encoder.encode(canonical)) as! [String: Any]
        // Set encoders have no stable iteration order, including after a decode.
        // Canonicalize only unordered fields; template/application order matters.
        for (group, field) in [("resourceTools", "enabledTools"), ("fileTools", "mainMenuTools")] {
            if var values = object[group] as? [String: Any], let unordered = values[field] as? [String] {
                values[field] = unordered.sorted(); object[group] = values
            }
        }
        return TemplatePackageCodec.digest(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }
    public static func plan(_ package: ValidatedTemplatePackage, into original: FileMintPreferences,
                            choices: [String: TemplateImportChoice] = [:], adoptDefaults: Bool = false,
                            copySuffix: String = "Copy", validatedApplicationIDs: Set<UUID> = [], makeID: () -> UUID = UUID.init) throws -> TemplateImportPlan {
        let existing = TemplateCatalog.sortedTemplates(from: original.templates)
        let existingPortable: [PortableTemplate] = existing.map { template in
            let payload: String
            if let doc = template.document { payload = doc.kind.rawValue + "-" + doc.sha256 }
            else { payload = "text-" + TemplatePackageCodec.digest(Data(template.content.utf8)) }
            return .init(template: template, payloadID: payload)
        }
        let reserved = Set(TemplateCatalog.builtInTemplates.map(\.id))
        let descriptors = Dictionary(uniqueKeysWithValues: package.descriptors.map { ($0.id, $0) })
        var usedIDs = Set(existing.map(\.id)), resulting = existing, map: [String: String] = [:]
        var rows: [TemplateImportRow] = [], assetsByPayload: [String: TemplatePlannedAsset] = [:]
        func normalizedName(_ value: String) -> String {
            value.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        }
        func conflict(_ name: String, _ suffix: String) -> Bool {
            resulting.contains { normalizedName($0.displayName) == normalizedName(name) && $0.fileExtension.lowercased() == suffix }
        }
        for incoming in package.templates {
            try Task.checkCancellation()
            let equivalent = existingPortable.first { incoming.equivalent(to: $0) }
            let changedID = existing.contains { $0.id == incoming.id }
            let hasConflict = changedID || conflict(incoming.displayName, incoming.fileExtension)
            let defaultChoice: TemplateImportChoice = equivalent != nil ? .skip : hasConflict ? .copy : .add
            let allowed: [TemplateImportChoice] = equivalent != nil ? [.skip,.copy] : hasConflict ? [.copy,.skip] : [.add,.skip,.copy]
            // Earlier choices can introduce or remove a later row's conflict.
            // Reconcile against this prefix, never a separate default-only plan.
            let choice = choices[incoming.id].flatMap { allowed.contains($0) ? $0 : nil } ?? defaultChoice
            if choice == .skip {
                if let equivalent { map[incoming.id] = equivalent.id }
                rows.append(.init(id: incoming.id, incoming: incoming, choice: choice, allowedChoices: allowed,
                    resultID: equivalent?.id, resultName: equivalent?.displayName, identical: equivalent != nil))
                continue
            }
            let id: String
            if choice == .add && !reserved.contains(incoming.id) && !usedIDs.contains(incoming.id) { id = incoming.id }
            else {
                var generated = "custom-" + makeID().uuidString
                while usedIDs.contains(generated) { generated = "custom-" + makeID().uuidString }
                id = generated
            }
            usedIDs.insert(id); map[incoming.id] = id
            var name = incoming.displayName
            if choice == .copy {
                let base = name + " " + copySuffix
                name = base
                var count = 2
                while conflict(name, incoming.fileExtension) { name = base + " \(count)"; count += 1 }
            }
            guard let descriptor = descriptors[incoming.payloadID], let bytes = package.payloads[incoming.payloadID] else { throw TemplatePackageError.invalid }
            var template = FileTemplate(id: id, displayName: name, suggestedFileName: incoming.suggestedFileName,
                group: incoming.group, content: descriptor.kind == .utf8Text ? String(decoding: bytes, as: UTF8.self) : "",
                isEnabled: incoming.isEnabled, rank: 0, fileExtension: incoming.fileExtension)
            template.customMenuIcon = incoming.customMenuIcon; template.afterCreation = incoming.afterCreation.portable
            if let kind = descriptor.kind.officeKind {
                if assetsByPayload[incoming.payloadID] == nil {
                    let reference = DocumentTemplateReference(id: makeID(), kind: kind, byteCount: bytes.count, sha256: descriptor.sha256)
                    assetsByPayload[incoming.payloadID] = .init(reference: reference, bytes: bytes)
                }
                template.document = assetsByPayload[incoming.payloadID]!.reference
            }
            // Only an already user-selected local reference can resolve a hint.
            if let hint = incoming.afterCreation.application,
               let app = original.creationApplications.first(where: { $0.hint.bundleIdentifier == hint.bundleIdentifier && $0.hint.displayName == hint.displayName && validatedApplicationIDs.contains($0.id) }) {
                template.afterCreation?.localApplicationID = app.id
            }
            resulting.append(template)
            rows.append(.init(id: incoming.id, incoming: incoming, choice: choice, allowedChoices: allowed,
                resultID: id, resultName: name, identical: false))
        }
        var candidate = original
        if rows.contains(where: { $0.choice != .skip }) {
            candidate.templates = TemplateCatalog.normalizedRanks(for: resulting)
            candidate.defaultTemplateIDs = TemplateCatalog.validDefaults(original.defaultTemplateIDs, in: candidate.templates)
            for (suffix, incomingID) in package.defaultTemplateIDs {
                let hadSuffix = existing.contains { $0.fileExtension.lowercased() == suffix }
                guard candidate.defaultTemplateIDs[suffix] == nil, !hadSuffix || adoptDefaults,
                      let resultID = map[incomingID], candidate.templates.contains(where: { $0.id == resultID && $0.isEnabled && $0.fileExtension.lowercased() == suffix }) else { continue }
                candidate.defaultTemplateIDs[suffix] = resultID
            }
            guard try JSONEncoder().encode(candidate).count <= FileMintPreferencesStore.maximumBytes else { throw TemplatePackageError.tooLarge }
        }
        let suffixes = Set(package.templates.map(\.fileExtension)).sorted()
        let changes: [TemplateDefaultChange] = suffixes.compactMap { suffix in
            let before = TemplateCatalog.defaultTemplate(forExtension: suffix, in: existing, defaults: original.defaultTemplateIDs)?.id
            let after = TemplateCatalog.defaultTemplate(forExtension: suffix, in: candidate.templates, defaults: candidate.defaultTemplateIDs)?.id
            return before == after ? nil : .init(suffix: suffix, before: before, after: after)
        }
        return .init(baseRevision: try revision(original), inputDigest: package.digest, rows: rows, preferences: candidate,
            assets: package.descriptors.compactMap { assetsByPayload[$0.id] }, defaultChanges: changes)
    }
}
