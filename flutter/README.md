# darias

A new Flutter project.

## アプリ起動スクリプト（run.sh）

iOSシミュレータ / Web / Androidエミュレータ を統一コマンドで起動・再起動できる。
バックグラウンド常駐で動くため、`tail` を Ctrl-C してもアプリは動き続ける。

```bash
./run.sh ios            # iOSシミュレータで起動（既定）
./run.sh web            # Webで起動（web-server + 既存Chromeタブをreload）
./run.sh android        # Androidエミュレータで起動（未起動ならAVDを自動boot）

./run.sh restart ios    # 停止してから起動し直す（= ./run.sh ios と同じ挙動）
./run.sh stop ios       # 停止（stop all で全ターゲット停止）
./run.sh status         # 各ターゲットの起動状況
./run.sh logs web       # 起動中プロセスのログを追尾
```

- 起動コマンドは常に「再起動」動作（同ターゲットの既存プロセスを停止してから起動）。
- 各起動は `--dart-define=DARIAS_RUN_TARGET=<ios|web|android>` のマーカーで識別・停止するため、3ターゲットを同時に起動しても互いに干渉しない。
- ログ・作業ファイルは `.run/`（gitignore済み）に出力。
- 既定のiOS機種・Android AVD名はスクリプト冒頭の `IOS_DEFAULT_DEVICE` / `ANDROID_AVD` で変更可能。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
