/// KeychainService.swift
/// Secure storage for the ESV API key using iOS Keychain.
/// No third-party packages — uses raw Security framework.

import Foundation
import Security

enum KeychainService {
    private static let service = "com.dailykairos"
    private static let esvAccount = "esv_api_key"

    static func saveESVKey(_ key: String) {
        let data = Data(key.utf8)
        // Delete any existing entry first to avoid duplicate-item errors
        SecItemDelete([kSecClass: kSecClassGenericPassword,
                       kSecAttrService: service,
                       kSecAttrAccount: esvAccount] as CFDictionary)
        SecItemAdd([kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: esvAccount,
                    kSecValueData: data,
                    kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked] as CFDictionary, nil)
    }

    static func loadESVKey() -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching(
            [kSecClass: kSecClassGenericPassword,
             kSecAttrService: service,
             kSecAttrAccount: esvAccount,
             kSecReturnData: true,
             kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteESVKey() {
        SecItemDelete([kSecClass: kSecClassGenericPassword,
                       kSecAttrService: service,
                       kSecAttrAccount: esvAccount] as CFDictionary)
    }
}
