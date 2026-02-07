//
//  StorageService.swift
//  TextCoach
//
//  Local data persistence using UserDefaults and FileManager
//

import Foundation

class StorageService {
    static let shared = StorageService()
    
    private let conversationsKey = "saved_conversations"
    private let localOnlyModeKey = "local_only_mode"
    
    private let fileManager = FileManager.default
    private var conversationsURL: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("conversations.json")
    }
    
    // MARK: - Conversations
    
    func saveConversations(_ conversations: [Conversation]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            try data.write(to: conversationsURL)
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }
    
    func loadConversations() -> [Conversation] {
        guard fileManager.fileExists(atPath: conversationsURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: conversationsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Conversation].self, from: data)
        } catch {
            print("Failed to load conversations: \(error)")
            return []
        }
    }
    
    // MARK: - Settings
    
    func saveLocalOnlyMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: localOnlyModeKey)
    }
    
    func loadLocalOnlyMode() -> Bool {
        UserDefaults.standard.bool(forKey: localOnlyModeKey)
    }
    
    // MARK: - Clear All
    
    func clearAll() {
        try? fileManager.removeItem(at: conversationsURL)
        UserDefaults.standard.removeObject(forKey: localOnlyModeKey)
    }
}

// MARK: - Keychain Service

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.textcoach.app"
    private let tokenKey = "auth_token"
    
    func saveToken(_ token: String) throws {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
    
    func getToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        
        return token
    }
    
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }
}

enum KeychainError: Error {
    case saveFailed
    case notFound
    case deleteFailed
}
