/// SecretsLoader.swift
/// Reads API keys from Secrets.plist (gitignored).
/// Copy Secrets.example.plist → Secrets.plist and fill in your key.

import Foundation

enum SecretsLoader {
    static func esvAPIKey() throws -> String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let key = dict["ESV_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_ESV_API_KEY_HERE"
        else {
            throw AppError.esvMissingKey
        }
        return key
    }
}
