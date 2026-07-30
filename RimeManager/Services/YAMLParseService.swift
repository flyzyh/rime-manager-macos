import Foundation
import Yams

/// Wrapper around the Yams library for YAML parsing and serialization.
final class YAMLParseService {

    /// Parse a YAML string into a dictionary.
    func parse(_ content: String) throws -> [String: Any] {
        guard let dict = try Yams.load(yaml: content) as? [String: Any] else {
            throw YAMLParseError.invalidRootType
        }
        return dict
    }

    /// Parse a YAML string with multiple documents.
    func parseAll(_ content: String) throws -> [[String: Any]] {
        let documents = try Yams.load_all(yaml: content)
        return documents.compactMap { $0 as? [String: Any] }
    }

    /// Serialize a dictionary to YAML string.
    func serialize(_ dict: [String: Any]) throws -> String {
        return try Yams.dump(object: dict)
    }

    /// Validate that a YAML string is syntactically correct.
    func validate(_ content: String) -> Result<Void, Error> {
        do {
            _ = try Yams.load(yaml: content)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Pretty-print YAML content (format it consistently).
    func prettyPrint(_ content: String) throws -> String {
        let parsed = try Yams.compose(yaml: content)
        return try Yams.serialize(node: parsed!)
    }
}

enum YAMLParseError: LocalizedError {
    case invalidRootType
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .invalidRootType:
            return "YAML root is not a dictionary (expected a mapping)."
        case .emptyDocument:
            return "YAML document is empty."
        }
    }
}
