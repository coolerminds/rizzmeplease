import Foundation

enum AppRuntimeConfig {
    static let defaultAPIBaseURL = "https://rizzmeow.com/api/v1"
    private static let apiBaseURLOverrideKey = "API_BASE_URL_OVERRIDE"

    static var apiBaseURL: URL {
        if let configured = apiBaseURLStringValue,
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

    #if DEBUG
    static var debugAPIBaseURLOverride: String? {
        UserDefaults.standard.string(forKey: apiBaseURLOverrideKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    static func setDebugAPIBaseURLOverride(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let trimmed {
            UserDefaults.standard.set(trimmed, forKey: apiBaseURLOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: apiBaseURLOverrideKey)
        }
    }
    #endif

    private static var apiBaseURLStringValue: String? {
        #if DEBUG
        if let override = debugAPIBaseURLOverride {
            return override
        }
        #endif
        return stringValue(for: "API_BASE_URL")
    }

    private static func stringValue(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
