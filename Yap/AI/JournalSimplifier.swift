import Foundation

/// The one deliberate exception to this app's otherwise 100%-on-device design. Tapping
/// "Simplify" on a note sends *that entry's text* to NVIDIA's hosted inference API (NIM,
/// an OpenAI-compatible chat completions endpoint) to strip verbal filler — "um," "uh,"
/// false starts, words repeated mid-sentence — while preserving the speaker's exact
/// wording. It never rewrites, rephrases, or summarizes: same words, minus the speech
/// artifacts, so a dictated entry reads like it was typed instead of spoken.
///
/// Scoped tightly on purpose: only fires on an explicit tap on one entry, never
/// automatically, never on anything else in the app. See `Secrets.swift` for the API key
/// (gitignored, not committed) and why a client-embedded key is an acceptable tradeoff
/// only because this build is personal/device-only, never App-Store-distributed.
enum JournalSimplifier {
    enum SimplifyError: LocalizedError {
        case empty
        case network(String)
        case badResponse
        case httpStatus(Int, String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "There's nothing to simplify."
            case .network(let message):
                return "Couldn't reach the simplify service: \(message)"
            case .badResponse:
                return "The simplify service returned something unexpected."
            case .httpStatus(let code, let detail):
                if code == 401 || code == 403 {
                    return "The NVIDIA API key was rejected — it may need to be rotated."
                }
                if code == 429 {
                    return "Rate limited — try again in a moment."
                }
                return "Simplify failed (HTTP \(code)). \(detail)"
            }
        }
    }

    private static let endpoint = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!
    // A small instruct model is plenty for "strip filler words" — this is a light,
    // low-stakes edit, not generation, so there's no need to reach for a larger/slower one.
    private static let model = "meta/llama-3.1-8b-instruct"

    private static let systemPrompt = """
    You lightly copy-edit a personal voice journal's raw speech-to-text transcript. Remove \
    filler words (um, uh, like, you know, so, basically, I mean), false starts, and words \
    or short phrases repeated by mistake mid-sentence. Fix only what's needed so it reads \
    like the person typed it themselves instead of speaking it out loud.

    Rules, strictly:
    - Do NOT rephrase or reword any sentence.
    - Do NOT change word choice.
    - Do NOT summarize, shorten, or add anything that wasn't said.
    - Do NOT fix grammar beyond removing disfluencies (a dropped "the" or a sentence that \
    trails off is fine to leave as-is if that's genuinely what was said).
    - Every real word the speaker said stays, in the same order. Only verbal filler comes out.

    Return ONLY the cleaned text. No preamble, no quotation marks, no commentary, no \
    markdown.
    """

    static func simplify(_ text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SimplifyError.empty }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.nvidiaAPIKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": trimmed],
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SimplifyError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw SimplifyError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? ""
            throw SimplifyError.httpStatus(http.statusCode, detail)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw SimplifyError.badResponse
        }

        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw SimplifyError.badResponse }
        return cleaned
    }
}
