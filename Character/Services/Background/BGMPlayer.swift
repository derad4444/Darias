import SwiftUI
import AVFoundation

class BGMPlayer {
    static let shared = BGMPlayer()

    private var audioPlayer: AVAudioPlayer?

    func playBGM(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // 無限ループ

            // 🔸 AppStorageから音量を読み取って適用
            let savedVolume = UserDefaults.standard.double(forKey: "bgmVolume")
            audioPlayer?.volume = savedVolume == 0 ? 0.5 : Float(savedVolume)

            audioPlayer?.play()
        } catch {
            // BGM playback failed
        }
    }

    func updateVolume(_ volume: Double) {
        audioPlayer?.volume = Float(volume)
        // Volume updated
    }

    func stopBGM() {
        audioPlayer?.stop()
    }
}
