import Foundation
import Yams

/// Normalize Rime patch shapes before merging generated patches.
enum RimePatchNormalizer {
    static func firstMap(_ yaml: String) -> [String: Any] {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        if let dict = try? Yams.load(yaml: yaml) as? [String: Any] { return dict }
        if let documents = try? Yams.load_all(yaml: yaml) {
            return documents.compactMap { $0 as? [String: Any] }.first ?? [:]
        }
        return [:]
    }

    static func patchRoot(_ yaml: String) -> [String: Any] {
        let dict = firstMap(yaml)
        return dict["patch"] as? [String: Any] ?? dict
    }

    /// Resolve full nodes, append lists (`+`) and item replacement (`@n`) into full lists.
    static func effectiveEngineSections(schemaYAML: String, patchYAML: String) -> [String: [String]] {
        let schema = firstMap(schemaYAML)
        let patch = patchRoot(patchYAML)
        var sections = [String: [String]]()
        if let engine = schema["engine"] as? [String: Any] {
            for (section, value) in engine {
                if let list = value as? [String] {
                    sections[section] = list
                } else if let list = value as? [Any] {
                    sections[section] = list.compactMap { $0 as? String }
                }
            }
        }

        func readFull(_ value: Any?) -> [String]? {
            (value as? [String]) ?? (value as? [Any])?.compactMap { $0 as? String }
        }

        // Old nested form.
        if let engine = patch["engine"] as? [String: Any] {
            for (section, value) in engine {
                if let list = readFull(value) { sections[section] = list }
            }
        }
        // Flat full form and append/item forms.
        for (key, value) in patch {
            if key.hasPrefix("engine/"), key != "engine" {
                let tail = String(key.dropFirst("engine/".count))
                if tail.hasSuffix("/+"), let appended = readFull(value) {
                    let section = String(tail.dropLast(2))
                    sections[section] = (sections[section] ?? []) + appended
                    continue
                }
                if let list = readFull(value) {
                    sections[tail] = list
                    continue
                }
                let parts = tail.split(separator: "/")
                if parts.count == 2, parts[1].hasPrefix("@"), let index = Int(parts[1].dropFirst()) {
                    let section = String(parts[0])
                    var list = sections[section] ?? []
                    if index < list.count, let item = value as? String { list[index] = item }
                    sections[section] = list
                }
            }
        }
        return sections
    }

    /// Replace every legacy engine patch shape with full section lists, leaving
    /// unpatched schema sections untouched.
    static func normalizeEnginePatch(patch: inout [String: Any], schemaYAML: String) {
        let originalPatch = patch
        var sections = [String: [String]]()
        if let engine = originalPatch["engine"] as? [String: Any] {
            for (section, value) in engine where value is [String] {
                sections[section] = value as? [String]
            }
        }
        for (key, value) in originalPatch where key.hasPrefix("engine/") && key != "engine" {
            let tail = String(key.dropFirst("engine/".count))
            if tail.hasSuffix("/+"), let appended = value as? [String] {
                let section = String(tail.dropLast(2))
                sections[section] = (sections[section] ?? []) + appended
            } else if let list = value as? [String] {
                sections[tail] = list
            }
        }

        patch.removeValue(forKey: "engine")
        for key in patch.keys where key.hasPrefix("engine/") { patch.removeValue(forKey: key) }
        for (section, list) in sections { patch["engine/\(section)"] = list }
    }
}
