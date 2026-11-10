import Foundation

/// Decides how long to wait after each character.
/// The whole schedule is computed before typing starts, so the countdown is exact.
enum Pacing: String, CaseIterable {
    case human      // random, realistic human rhythm
    case veryFast
    case fast
    case normal
    case slow

    var label: String {
        switch self {
        case .human: return "Human-like (random)"
        case .veryFast: return "Very fast"
        case .fast: return "Fast"
        case .normal: return "Normal"
        case .slow: return "Slow"
        }
    }

    /// Returns one delay (in seconds) per character.
    func delays(for characters: [Character]) -> [TimeInterval] {
        switch self {
        case .veryFast: return Array(repeating: 0.004, count: characters.count)
        case .fast: return Array(repeating: 0.012, count: characters.count)
        case .normal: return Array(repeating: 0.03, count: characters.count)
        case .slow: return Array(repeating: 0.07, count: characters.count)
        case .human: return Self.humanDelays(for: characters)
        }
    }

    // MARK: - Human model
    //
    // Real typists average roughly 40–100 words per minute, which is about 120–300 ms
    // per keystroke. The gap between keys is not uniform: it follows a skewed,
    // log-normal-like curve (most keys are quick, a few are slow). People also pause
    // after words, longer after commas and sentences, and sometimes stop to think.

    private static let fastest: TimeInterval = 0.045   // ~220 wpm burst, a quick key pair
    private static let slowest: TimeInterval = 0.45    // a hesitant key

    static func humanDelays(for characters: [Character]) -> [TimeInterval] {
        var result: [TimeInterval] = []
        result.reserveCapacity(characters.count)

        // Each session gets its own "typist": some people are a bit faster than others.
        let typistMedian = Double.random(in: 0.085...0.14)

        for (i, char) in characters.enumerated() {
            // Log-normal key interval around the typist's median, clamped to human limits.
            var delay = typistMedian * exp(gaussian() * 0.35)
            delay = min(max(delay, fastest), slowest)

            let next = i + 1 < characters.count ? characters[i + 1] : nil

            switch char {
            case " ":
                delay += .random(in: 0.0...0.08)            // small gap between words
            case ",", ";", ":":
                delay += .random(in: 0.12...0.35)
            case ".", "!", "?":
                if next == " " || next == "\n" || next == nil {
                    delay += .random(in: 0.25...0.7)        // end of a sentence
                }
            case "\n":
                delay += .random(in: 0.35...0.9)            // new line or paragraph
            default:
                break
            }

            // Uppercase letters and symbols need Shift or a reach, so they're a bit slower.
            if char.isUppercase || (char.isPunctuation && char != "." && char != ",") || char.isSymbol {
                delay += .random(in: 0.02...0.08)
            }

            // Every so often, a short "thinking" pause at a word boundary.
            if char == " " && Double.random(in: 0...1) < 0.03 {
                delay += .random(in: 0.4...1.2)
            }

            result.append(delay)
        }
        return result
    }

    /// Standard normal random number (Box–Muller).
    private static func gaussian() -> Double {
        let u1 = Double.random(in: Double.ulpOfOne...1)
        let u2 = Double.random(in: 0...1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}
