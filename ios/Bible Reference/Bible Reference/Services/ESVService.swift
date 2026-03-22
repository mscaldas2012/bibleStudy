/// ESVService.swift
/// Fetches Bible passage text from api.esv.org.
/// Only called for short passages (≤5 verses).

import Foundation

actor ESVService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.esv.org/v3/passage/text/")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchPassage(for reference: BibleReference) async throws -> String {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: reference.esvQuery),
            URLQueryItem(name: "include-headings", value: "false"),
            URLQueryItem(name: "include-footnotes", value: "false"),
            URLQueryItem(name: "include-passage-references", value: "false"),
            URLQueryItem(name: "include-short-copyright", value: "false"),
            URLQueryItem(name: "include-copyright", value: "false"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AppError.esvNetworkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.esvNetworkError("No HTTP response")
        }
        if http.statusCode == 401 { throw AppError.esvAuthError }
        guard http.statusCode == 200 else {
            throw AppError.esvNetworkError("HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(ESVResponse.self, from: data)
        guard let text = decoded.passages.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw AppError.esvNoPassage
        }
        return text
    }
}

private struct ESVResponse: Decodable {
    let passages: [String]
}
