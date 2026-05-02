/// KeychainService.swift
/// Secure storage for API keys.
/// On iOS uses the Keychain; on macOS/Mac Catalyst falls back to UserDefaults
/// because ad-hoc signed Mac builds lack the keychain-access-groups entitlement.

import Foundation
import Security

enum KeychainService {
    private static let service = "com.dailykairos"
    private static let esvAccount = "esv_api_key"

    // MARK: - ESV key

    static func saveESVKey(_ key: String) {
        #if targetEnvironment(macCatalyst)
        UserDefaults.standard.set(key, forKey: "com.dailykairos.esv_api_key")
        #else
        keychainSave(key, account: esvAccount)
        #endif
    }

    static func loadESVKey() -> String? {
        #if targetEnvironment(macCatalyst)
        return UserDefaults.standard.string(forKey: "com.dailykairos.esv_api_key")
        #else
        return keychainLoad(account: esvAccount)
        #endif
    }

    static func deleteESVKey() {
        #if targetEnvironment(macCatalyst)
        UserDefaults.standard.removeObject(forKey: "com.dailykairos.esv_api_key")
        #else
        keychainDelete(account: esvAccount)
        #endif
    }

    // MARK: - Generic provider key storage

    static func saveKey(_ key: String, forProvider providerID: String) {
        #if targetEnvironment(macCatalyst)
        UserDefaults.standard.set(key, forKey: "com.dailykairos.provider.\(providerID)")
        #else
        keychainSave(key, account: providerID)
        #endif
    }

    static func loadKey(forProvider providerID: String) -> String? {
        #if targetEnvironment(macCatalyst)
        return UserDefaults.standard.string(forKey: "com.dailykairos.provider.\(providerID)")
        #else
        return keychainLoad(account: providerID)
        #endif
    }

    static func deleteKey(forProvider providerID: String) {
        #if targetEnvironment(macCatalyst)
        UserDefaults.standard.removeObject(forKey: "com.dailykairos.provider.\(providerID)")
        #else
        keychainDelete(account: providerID)
        #endif
    }

    // MARK: - Keychain helpers (iOS only)

    private static func keychainSave(_ value: String, account: String) {
        let data = Data(value.utf8)
        keychainDelete(account: account)
        SecItemAdd([kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: account,
                    kSecValueData: data,
                    kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked] as CFDictionary, nil)
    }

    private static func keychainLoad(account: String) -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching(
            [kSecClass: kSecClassGenericPassword,
             kSecAttrService: service,
             kSecAttrAccount: account,
             kSecReturnData: true,
             kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainDelete(account: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword,
                       kSecAttrService: service,
                       kSecAttrAccount: account] as CFDictionary)
    }
}
