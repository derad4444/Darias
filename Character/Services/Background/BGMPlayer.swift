import SwiftUI
import AVFoundation

class BGMPlayer {
    static let shared = BGMPlayer()

    private var audioPlayer: AVAudioPlayer?

    func playBGM(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("❌ BGMファイルが見つかりません: \(filename)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // 無限ループ

            // 🔸 AppStorageから音量を読み取って適用
            let savedVolume = UserDefaults.standard.double(forKey: "bgmVolume")
            audioPlayer?.volume = savedVolume == 0 ? 0.5 : Float(savedVolume)

            audioPlayer?.play()
            print("✅ BGM再生開始 (音量: \(audioPlayer?.volume ?? 0))")
        } catch {
            print("❌ BGM再生失敗: \(error)")
        }
    }

    func updateVolume(_ volume: Double) {
        audioPlayer?.volume = Float(volume)
        print("✅ 音量更新: \(volume)")
    }

    func stopBGM() {
        audioPlayer?.stop()
    }
}
