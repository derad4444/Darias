#!/bin/bash
# Flutter Web開発サーバー起動スクリプト
# ローカル開発時のログイン状態を保持するため、固定のChromeプロファイルを使用
# ※本番環境ではFirebase AuthのPersistence.LOCALが各ユーザーのブラウザに保存

CHROME_PROFILE_DIR="$HOME/.flutter_chrome_profile"

# プロファイルディレクトリがなければ作成
mkdir -p "$CHROME_PROFILE_DIR"

# Flutter Webを起動（固定プロファイル使用）
flutter run -d chrome \
  --web-port=8080 \
  --web-browser-flag="--user-data-dir=$CHROME_PROFILE_DIR"
