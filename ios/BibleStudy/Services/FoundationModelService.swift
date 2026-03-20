/// FoundationModelService.swift
/// Generates passage context and applications using Apple Foundation Models.
/// Requires iPadOS 26+ with Apple Intelligence enabled on M1+ hardware.

import Foundation
import FoundationModels

actor FoundationModelService {

    private let instructions = """
        You are a Bible study assistant with deep knowledge of Scripture, \
        biblical history, and Christian theology. When given a Bible reference \
        and its text, provide accurate, concise insights grounded in the passage.
        """

    func analyze(reference: BibleReference, verseText: String?) async throws -> PassageAnalysis {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }

        let session = LanguageModelSession(instructions: instructions)

        var prompt = "Bible reference: \(reference.displayTitle)"
        if let text = verseText {
            prompt += "\n\nESV text:\n\(text)"
        }
        prompt += "\n\nProvide the study note."

        do {
            let response = try await session.respond(to: prompt, generating: PassageAnalysis.self)
            return response.content
        } catch {
            throw AppError.modelGenerationFailed(error.localizedDescription)
        }
    }
}
