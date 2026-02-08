import Foundation

enum AppRuntimeConfig {
    static let defaultAPIBaseURL = "https://rizzmeow.com/api/v1"

    static var apiBaseURL: URL {
        if let configured = stringValue(for: "API_BASE_URL"),
           let url = URL(string: configured) {
            return url
        }
        return URL(string: defaultAPIBaseURL)!
    }

    static var apiBaseURLString: String {
        apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var enableDirectGrokFallback: Bool {
        #if DEBUG
        return boolValue(for: "ENABLE_DIRECT_GROK_FALLBACK") ?? true
        #else
        return boolValue(for: "ENABLE_DIRECT_GROK_FALLBACK") ?? false
        #endif
    }

    private static func stringValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return nil
        }

        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    private static func boolValue(for key: String) -> Bool? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return nil
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let stringValue = value as? String {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "on"].contains(normalized) {
                return true
            }
            if ["0", "false", "no", "off"].contains(normalized) {
                return false
            }
        }

        return nil
    }
}
