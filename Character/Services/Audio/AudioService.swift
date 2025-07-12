import Foundation
import AVFoundation

class AudioService {
    static let shared = AudioService()
    
    private init() {}
    
    func playVoice(url: URL, volume: Double = 0.8) {
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // AppStorageからキャラクター音量を読み取って適用
        let savedVolume = UserDefaults.standard.double(forKey: "characterVolume")
        let finalVolume = savedVolume == 0 ? volume : savedVolume
        
        // AVPlayerは直接音量を設定できないので、AVAudioMixを使う
        guard let audioTrack = playerItem.asset.tracks.first else {
            print("⚠️ オーディオトラックが見つかりません")
            return
        }
        
        let audioMix = AVMutableAudioMix()
        let inputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
        inputParameters.setVolume(Float(finalVolume), at: CMTime.zero)
        audioMix.inputParameters = [inputParameters]
        playerItem.audioMix = audioMix

        player.play()
    }
}