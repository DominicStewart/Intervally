//
//  AudioService.swift
//  RunLoop
//
//  Manages AVAudioSession and plays interval boundary chimes.
//  Configures background audio capability for reliable timer operation.
//

import Foundation
import AVFoundation

/// Service for managing audio session and playing chime sounds
final class AudioService {

    // MARK: - Properties

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Audio Session Configuration

    /// Configure audio session for background playback
    func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            // Set category to playback with mixing enabled
            // This allows background audio while respecting other apps
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )

            // Activate session
            try session.setActive(true)

            print("✅ Audio session configured for background playback")
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Deactivate audio session (call when session stops)
    func deactivateSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Sound Playback

    /// Play the interval boundary chime
    func playChime() {
        // Attempt to load chime.wav from bundle
        guard let soundURL = Bundle.main.url(forResource: "chime", withExtension: "wav") else {
            print("⚠️ chime.wav not found in bundle - using system sound as fallback")
            playSystemSound()
            return
        }

        do {
            // Create and configure player
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            print("🔔 Chime played")
        } catch {
            print("❌ Failed to play chime: \(error.localizedDescription)")
            playSystemSound()
        }
    }

    /// Fallback: play system sound if custom chime unavailable
    private func playSystemSound() {
        // Use system sound ID 1007 (SMS alert tone)
        AudioServicesPlaySystemSound(1007)
    }

    // MARK: - Background Audio Keep-Alive (Optional)

    /// Play a silent audio loop to keep session alive in background
    /// Call this if you need to maintain timing without relying solely on notifications
    func startSilentAudioLoop() {
        // Generate a short silent audio buffer and loop it
        // This is optional - notifications provide a more battery-efficient approach
        // Uncomment if you need guaranteed background timing:

        /*
        guard let silenceURL = createSilenceAudioFile() else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1 // Infinite loop
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            print("🔇 Silent audio loop started")
        } catch {
            print("❌ Failed to start silent loop: \(error.localizedDescription)")
        }
        */
    }

    /// Stop silent audio loop
    func stopSilentAudioLoop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Helpers

    /// Create a temporary silent audio file
    private func createSilenceAudioFile() -> URL? {
        // Create a 1-second silent audio file in LPCM format
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(44100) // 1 second

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        // Buffer is already silent (zeros) by default

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("silence.caf")

        do {
            let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try file.write(from: buffer)
            return tempURL
        } catch {
            print("❌ Failed to create silence file: \(error.localizedDescription)")
            return nil
        }
    }
}
