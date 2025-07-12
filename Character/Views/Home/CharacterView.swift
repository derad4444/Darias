// CharacterView.swift

import SwiftUI

// Home画面などに映すキャラクターのView
struct CharacterView: View {
    let singleImageUrl: URL?

    //キャラ表示
    var body: some View {
        VStack {
            Spacer(minLength: 50) // 上部にスペースを追加
            
            if let singleImageUrl = singleImageUrl {
                // 一枚画像表示
                AsyncImage(url: singleImageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 400, height: 400)
            } else {
                // サンプル画像を表示（Assets内の画像）
                Image("sample_character") // Assets.xcassetsに追加した画像名
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 400, height: 400)
            }
            
            Spacer()
        }
    }

}

// カスタム AsyncImage（読み込み失敗時の対応付き）
struct RemoteImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable()
            case .failure(_):
                Image(systemName: "xmark.circle")
                    .resizable()
            @unknown default:
                EmptyView()
            }
        }
    }
}
