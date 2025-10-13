//
//  SpeechService.swift
//  RunLoop
//
//  Manages voice announcements using AVSpeechSynthesizer.
//

import Foundation
import AVFoundation

/// Service for voice announcements using speech synthesis
final class SpeechService {

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Public Methods

    /// Speak the given text with optional rate adjustment
    /// - Parameters:
    ///   - text: Text to speak
    ///   - rate: Speech rate (0.0 = slow, 0.5 = normal, 1.0 = fast)
    func speak(_ text: String, rate: Float = 0.5) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0

        // Use default language (device language)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())

        // Speak
        synthesizer.speak(utterance)

        print("🗣️ Speaking: \"\(text)\"")
    }

    /// Stop any ongoing speech
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
