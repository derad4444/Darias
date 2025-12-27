import SwiftUI

struct VolumeSettingsView: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @AppStorage("bgmVolume") var bgmVolume: Double = 0.5
    @AppStorage("characterVolume") var characterVolume: Double = 0.8
    @AppStorage("bgmMuted") var bgmMuted: Bool = false
    @AppStorage("characterMuted") var characterMuted: Bool = false
    @AppStorage("bgmVolumeBeforeMute") var bgmVolumeBeforeMute: Double = 0.5
    @AppStorage("characterVolumeBeforeMute") var characterVolumeBeforeMute: Double = 0.8

    var body: some View {
        ZStack {
            // 背景グラデーション
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // カスタムヘッダー
                headerSection

                // 音量設定リスト
                settingsListView
            }
        }
        .onAppear {
            // ミュート状態の場合は音量を0に設定
            if bgmMuted {
                BGMPlayer.shared.updateVolume(0)
            } else {
                BGMPlayer.shared.updateVolume(bgmVolume)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(colorSettings.getCurrentTextColor())
            }
            .padding(.leading, 16)

            Spacer()

            Text("音量設定")
                .dynamicTitle3()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .fontWeight(.semibold)

            Spacer()

            // バランス調整用の透明ボタン
            Color.clear
                .frame(width: 44, height: 44)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(
            Color.white.opacity(0.1)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Settings List

    private var settingsListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // BGM音量
                bgmVolumeSection

                // キャラクター音声
                characterVolumeSection

                // 説明セクション
                infoSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - BGM Volume Section

    private var bgmVolumeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                    .font(.title2)

                Text("BGM音量")
                    .dynamicHeadline()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.semibold)

                Spacer()

                // ミュートボタン
                Button(action: {
                    toggleBGMMute()
                }) {
                    Image(systemName: bgmMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(bgmMuted ? .red : colorSettings.getCurrentAccentColor())
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(bgmMuted ? Color.red.opacity(0.1) : colorSettings.getCurrentAccentColor().opacity(0.1))
                        )
                }

                Text(bgmMuted ? "0%" : "\(Int(bgmVolume * 100))%")
                    .dynamicTitle3()
                    .foregroundColor(bgmMuted ? .gray : colorSettings.getCurrentAccentColor())
                    .fontWeight(.bold)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            VStack(spacing: 8) {
                Slider(value: $bgmVolume, in: 0...1, step: 0.01, onEditingChanged: { _ in
                    if !bgmMuted {
                        BGMPlayer.shared.updateVolume(bgmVolume)
                        bgmVolumeBeforeMute = bgmVolume
                    }
                })
                .accentColor(colorSettings.getCurrentAccentColor())
                .disabled(bgmMuted)
                .opacity(bgmMuted ? 0.5 : 1.0)

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.5))
                        .font(.caption)
                    Spacer()
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.5))
                        .font(.caption)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(bgmMuted ? Color.red.opacity(0.3) : Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Character Volume Section

    private var characterVolumeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                    .font(.title2)

                Text("キャラクター音声")
                    .dynamicHeadline()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.semibold)

                Spacer()

                // ミュートボタン
                Button(action: {
                    toggleCharacterMute()
                }) {
                    Image(systemName: characterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(characterMuted ? .red : colorSettings.getCurrentAccentColor())
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(characterMuted ? Color.red.opacity(0.1) : colorSettings.getCurrentAccentColor().opacity(0.1))
                        )
                }

                Text(characterMuted ? "0%" : "\(Int(characterVolume * 100))%")
                    .dynamicTitle3()
                    .foregroundColor(characterMuted ? .gray : colorSettings.getCurrentAccentColor())
                    .fontWeight(.bold)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            VStack(spacing: 8) {
                Slider(value: $characterVolume, in: 0...1, step: 0.01, onEditingChanged: { _ in
                    if !characterMuted {
                        characterVolumeBeforeMute = characterVolume
                    }
                })
                .accentColor(colorSettings.getCurrentAccentColor())
                .disabled(characterMuted)
                .opacity(characterMuted ? 0.5 : 1.0)

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.5))
                        .font(.caption)
                    Spacer()
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.5))
                        .font(.caption)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(characterMuted ? Color.red.opacity(0.3) : Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                Text("音量について")
                    .dynamicCallout()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("• BGM音量：アプリ内で流れる背景音楽の音量を調整します")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))

                Text("• キャラクター音声：キャラクターの音声の音量を調整します")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))

                Text("• 音量は0%〜100%の範囲で設定できます")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))

                Text("• ミュートボタンをタップすると、ワンタップで消音/解除できます")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Functions

    private func toggleBGMMute() {
        if bgmMuted {
            // ミュート解除：以前の音量に戻す
            bgmMuted = false
            bgmVolume = bgmVolumeBeforeMute
            BGMPlayer.shared.updateVolume(bgmVolume)
        } else {
            // ミュート：現在の音量を保存して0にする
            bgmMuted = true
            bgmVolumeBeforeMute = bgmVolume
            bgmVolume = 0
            BGMPlayer.shared.updateVolume(0)
        }
    }

    private func toggleCharacterMute() {
        if characterMuted {
            // ミュート解除：以前の音量に戻す
            characterMuted = false
            characterVolume = characterVolumeBeforeMute
        } else {
            // ミュート：現在の音量を保存して0にする
            characterMuted = true
            characterVolumeBeforeMute = characterVolume
            characterVolume = 0
        }
    }
}

#Preview {
    VolumeSettingsView()
}
