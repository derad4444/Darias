# App Check リリース準備ガイド

## 現在の状況
✅ App Check設定は既にリリース対応済み（自動切り替え）
✅ シミュレーター/デバッグ環境では自動的にデバッグプロバイダーを使用
✅ 実機リリース時は適切なプロバイダーを自動選択

## リリース前に必要な作業

### 1. Firebase Console での App Check 有効化
1. https://console.firebase.google.com/project/my-character-app/appcheck にアクセス
2. 「App Check を使ってみる」をクリック
3. iOS アプリ `com.Derao.Character` を選択
4. App Attest プロバイダーを有効化

### 2. App Store Connect での設定
1. App Store Connect でアプリを登録
2. Bundle ID: `com.Derao.Character` を確認
3. App Attest が有効になることを確認

### 3. テスト手順
#### 開発中（シミュレーター）
- 自動的にデバッグプロバイダーが使用される
- Console に "Using debug provider" が表示される
- Firestore アクセスが正常に動作する

#### 実機テスト（TestFlight）
- App Attest プロバイダーが使用される
- Console に "Using App Attest provider for production" が表示される
- 本番環境での動作確認

### 4. 本番リリース時の注意事項
- Firebase Console で App Check が有効化されていることを確認
- 実機での最終テストを実施
- エラーログを監視

## トラブルシューティング

### App Attest が利用できない場合
- iOS 14未満では自動的に DeviceCheck にフォールバック
- それも失敗する場合はデバッグプロバイダーで安全に動作

### デバッグトークンの取得方法
1. デバッグビルドでアプリを起動
2. Console でデバッグトークンを確認
3. Firebase Console で登録（必要に応じて）

## 現在の実装の安全性
- 環境を自動判定して適切なプロバイダーを選択
- フォールバック機能により、どの環境でも動作保証
- 詳細なログ出力によりデバッグが容易