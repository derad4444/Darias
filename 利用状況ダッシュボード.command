#!/bin/bash
# ダブルクリックで「手帳タブ利用状況ダッシュボード」を起動する。
# ブラウザが自動で開き、「再集計」ボタンで最新データに更新できる。停止は Ctrl+C かウィンドウを閉じる。
cd "/Users/onoderaryousuke/dev/DARIAS/shared/scripts/usage-dashboard" || {
  echo "スクリプトが見つかりません"; read -r -p "Enterで閉じる..."; exit 1;
}
echo "ダッシュボードを起動します（ブラウザが開きます）..."
echo "停止するには、このウィンドウで Ctrl+C を押してください。"
node server.js
read -r -p "終了しました。Enterで閉じる..."
