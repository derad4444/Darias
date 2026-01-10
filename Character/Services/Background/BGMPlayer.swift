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

            // 🔸 ミュート状態と音量をUserDefaultsから読み取って適用
            let isMuted = UserDefaults.standard.bool(forKey: "bgmMuted")

            if isMuted {
                // ミュート状態の場合は音量0
                audioPlayer?.volume = 0
            } else {
                // ミュート解除の場合は保存された音量を使用
                let savedVolume = UserDefaults.standard.double(forKey: "bgmVolume")
                audioPlayer?.volume = Float(savedVolume > 0 ? savedVolume : 0.5)
            }

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
