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
        // Ensure audio session is active (critical for background playback)
        ensureAudioSessionActive()

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

    /// Ensure audio session is active before speaking (important for background operation)
    private func ensureAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()

        do {
            // Re-activate if needed (especially when coming from background)
            if !session.isOtherAudioPlaying {
                try session.setActive(true)
            }
        } catch {
            print("⚠️ Failed to activate audio session: \(error.localizedDescription)")
        }
    }

    /// Stop any ongoing speech
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
