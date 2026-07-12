#!/bin/bash
# ダブルクリックで DARIAS を Web（web-server + Chrome）で起動（再実行で再起動）
cd "/Users/onoderaryousuke/dev/DARIAS/flutter" || {
  echo "flutter ディレクトリが見つかりません"; read -r -p "Enterで閉じる..."; exit 1;
}
exec ./run.sh web
