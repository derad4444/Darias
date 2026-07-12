#!/bin/bash
# =============================================================================
# DARIAS アプリ起動スクリプト
#
# iOSシミュレータ / Web / Androidエミュレータ を統一コマンドで起動・再起動する。
# CLAUDE.md / memory の起動ルールに準拠:
#   - iOS   : Xcodeが実際にビルド可能なシミュレータのみを対象にする
#             （`xcodebuild -showdestinations` で判定）。起動中でも非対応ランタイム
#             （古い iOS）は避け、対応ランタイムの既定機種を boot する。App Check は
#             コード内 AppleDebugProvider を使うため dart-define 不要。
#   - Web   : `-d chrome` は使わず web-server モードで起動（新タブを開かない）。
#             起動後、既存 Chrome の localhost:PORT タブを reload して反映。
#             WEB_APP_CHECK_DEBUG_TOKEN を dart-define で付与。
#   - Android: エミュレータ未起動なら AVD を launch → boot 待ち → 起動。
#
# 使い方:
#   ./run.sh ios            # iOSシミュレータで起動（既定）
#   ./run.sh web            # Webで起動
#   ./run.sh android        # Androidエミュレータで起動
#   ./run.sh restart ios    # iOS を停止してから起動（= ./run.sh ios と同じ挙動）
#   ./run.sh stop ios       # iOS の flutter プロセスを停止
#   ./run.sh stop all       # 全ターゲットを停止
#   ./run.sh status         # 各ターゲットの起動状況を表示
#   ./run.sh logs ios       # 起動中プロセスのログを追尾（tail -f）
#
# ※ 各ターゲットは常に「再起動セマンティクス」で動作する。起動コマンドを実行すると
#   同ターゲットの既存 flutter プロセスを停止してから起動し直す。
#   flutter は background で走らせ、ログをファイルに出力。フォアグラウンドでは
#   tail -f でログを表示する。tail を Ctrl-C しても アプリ本体は動き続ける。
# =============================================================================

set -uo pipefail

# ---- 設定 -------------------------------------------------------------------
WEB_PORT=8080
WEB_DEBUG_TOKEN=6c6674e4-dc43-4eb2-97a9-2dd004888428
IOS_DEFAULT_DEVICE="iPhone 16e"     # booted が無いとき boot する機種名
ANDROID_AVD="Pixel_8_API35"         # 起動する Android AVD 名

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$SCRIPT_DIR/.run"          # pid / log 置き場
mkdir -p "$RUN_DIR"
# FIFO(名前付きパイプ)はプロジェクト外に置く。
# 理由: flutter run/build はビルド前に `xattr -r -d com.apple.FinderInfo <flutterディレクトリ>`
# を実行するが、これがプロジェクト内にFIFOがあると open() で永久ブロックしてビルドがハングする。
# FIFOを外に出せば xattr が遭遇しないため再発しない。
FIFO_DIR="$HOME/.darias-run"
mkdir -p "$FIFO_DIR"
cd "$SCRIPT_DIR"

# ---- 色付きログ -------------------------------------------------------------
c_info()  { printf "\033[36m[run]\033[0m %s\n" "$*"; }
c_ok()    { printf "\033[32m[ok ]\033[0m %s\n" "$*"; }
c_warn()  { printf "\033[33m[warn]\033[0m %s\n" "$*"; }
c_err()   { printf "\033[31m[err]\033[0m %s\n" "$*" >&2; }

logfile() { echo "$RUN_DIR/$1.log"; }

# flutter はラッパー(bash)→dart へ fork/exec するため起動時の PID が安定しない。
# そこで各起動に一意マーカー --dart-define=DARIAS_RUN_TARGET=<t> を付与し、
# pgrep -f でそのマーカーを含むプロセス群を確実に特定・停止する。
marker() { echo "DARIAS_RUN_TARGET=$1"; }

# 対象ターゲットの起動中 PID 群（マーカー一致・自分自身の pgrep は除外）
target_pids() {
  pgrep -f "$(marker "$1")" 2>/dev/null | tr '\n' ' '
}

is_running() {
  [[ -n "$(target_pids "$1")" ]]
}

stop_target() {
  local t="$1" pids
  pids="$(target_pids "$t")"
  if [[ -n "$pids" ]]; then
    c_info "$t: 既存プロセス (pid=$pids) を停止します"
    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true
    for _ in $(seq 1 20); do
      is_running "$t" || break
      sleep 0.5
    done
    if is_running "$t"; then
      c_warn "$t: TERM で止まらないため KILL します"
      # shellcheck disable=SC2086
      kill -KILL $(target_pids "$t") 2>/dev/null || true
    fi
    c_ok "$t: 停止しました"
  else
    c_info "$t: 起動中プロセスはありません"
  fi
  # iOS は補助プロセス（xattr / log stream / debugserver）が居残りやすいので掃除
  [[ "$t" == ios ]] && cleanup_ios_orphans
}

# 起動中(Booted)の iOS シミュレータ UDID を1件返す（simctl が信頼できる情報源）
ios_booted_udid() {
  xcrun simctl list devices booted -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
for runtime in d.get("devices", {}).values():
    for dev in runtime:
        if dev.get("state") == "Booted":
            print(dev.get("udid","")); sys.exit(0)
' 2>/dev/null
}

# ---- iOS: Xcodeがビルド可能なシミュレータの判定 -----------------------------
# simctl の isAvailable では「Xcodeがビルド先として受け付けるか」を判定できない
# （古い iOS 26.0 等も isAvailable=true のまま残るため）。唯一信頼できる情報源は
# `xcodebuild -showdestinations`。iOS Simulator の宛先を "OS<TAB>UDID<TAB>名前"
# （新しい OS 順）で返す。取得できないとき（Generated.xcconfig 未生成等）は空を返し、
# 呼び出し側が従来ロジックへフォールバックする。
xcode_sim_destinations() {
  ( cd "$SCRIPT_DIR/ios" 2>/dev/null &&
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -showdestinations 2>/dev/null ) \
  | python3 -c '
import sys, re
rows = []
for line in sys.stdin:
    if "platform:iOS Simulator" not in line or "placeholder" in line:
        continue
    d = dict(re.findall(r"(\w+):([^,}]+)", line))
    uid = d.get("id", "").strip()
    osv = d.get("OS", "").strip()
    name = d.get("name", "").strip()
    if uid and osv:
        rows.append((osv, uid, name))
def oskey(r):
    try: return tuple(int(x) for x in r[0].split("."))
    except Exception: return (0,)
rows.sort(key=oskey, reverse=True)
for osv, uid, name in rows:
    print("\t".join((osv, uid, name)))
' 2>/dev/null
}

# 宛先一覧($1)のうち、いま Booted かつ Xcodeビルド可能な UDID を1件返す
booted_buildable_udid() {
  local dests="$1" booted u tab
  tab="$(printf '\t')"
  booted="$(xcrun simctl list devices booted -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
for l in d.get("devices", {}).values():
    for dev in l:
        if dev.get("state") == "Booted":
            print(dev.get("udid", ""))
' 2>/dev/null)"
  for u in $booted; do
    printf '%s\n' "$dests" | grep -qF -- "${tab}${u}${tab}" && { echo "$u"; return; }
  done
}

# 宛先一覧($1)から boot 対象を1件選ぶ（既定機種名優先 → 無ければ最新iPhone → 最新の何か）
# dests は OS 新しい順なので、最初の一致が最新ランタイム。
pick_boot_target() {
  local dests="$1" u
  u="$(printf '%s\n' "$dests" | awk -F'\t' -v n="$IOS_DEFAULT_DEVICE" '$3==n{print $2; exit}')"
  [[ -z "$u" ]] && u="$(printf '%s\n' "$dests" | awk -F'\t' '$3 ~ /^iPhone/{print $2; exit}')"
  [[ -z "$u" ]] && u="$(printf '%s\n' "$dests" | awk -F'\t' 'NR==1{print $2}')"
  echo "$u"
}

# flutter devices --machine から Android の deviceId を1件取得
# ※ コールドスタート時は列挙が間に合わず空になることがあるので、呼び出し側でリトライする
android_device_id() {
  flutter devices --machine 2>/dev/null | python3 -c '
import sys, json
try: data = json.load(sys.stdin)
except Exception: sys.exit(0)
for d in data:
    if (d.get("targetPlatform") or "").startswith("android"):
        print(d.get("id","")); break
' 2>/dev/null
}

# background で flutter run を起動（マーカー付き）、ログをファイルへ出力
launch_flutter() {
  local t="$1"; shift
  local lf fifo; lf="$(logfile "$t")"; fifo="$FIFO_DIR/$t.stdin"
  : > "$lf"
  # 非対話シェルの `&` 起動では flutter の stdin が /dev/null になり、即 EOF を受けて
  # アプリ起動直後に flutter run が終了してしまう。これを防ぐため FIFO を read-write で
  # 開いた fd を stdin に与え、常に書き込み側が存在する状態にして EOF を発生させない。
  # （sleep 等の常駐プロセスを使わないので後始末不要＝リークしない）
  [[ -p "$fifo" ]] || { rm -f "$fifo"; mkfifo "$fifo"; }
  c_info "$t: flutter run 起動中...  (log: $lf)"
  # マーカー用 dart-define を必ず先頭に付与（停止・状態確認の目印。アプリ側は未使用でOK）。
  # trap '' INT HUP: 後段の tail を Ctrl-C しても、また端末を閉じても本体が巻き添えで
  # 落ちないよう、flutter をシグナルから隔離してバックグラウンド常駐させる。
  ( trap '' INT HUP; exec 3<>"$fifo"; flutter run --dart-define="$(marker "$t")" "$@" <&3 >>"$lf" 2>&1 ) &
  disown
  c_ok "$t: 起動しました（ビルド開始）"
}

# iOSビルドで宙に浮いた補助プロセスを掃除する。
# 特に flutter は起動前に `xattr -r -d com.apple.FinderInfo <project>`（37k超のファイルを
# 走査）をタイムアウト無しで待つため、前回の残骸xattrが固まっていると次回ビルドが永久に
# ブロックされる。stop_target 直後（=正規の flutter は残っていない）に呼ぶので安全。
cleanup_ios_orphans() {
  local killed=""
  for pat in "xattr -r -d com.apple.FinderInfo" "log stream --style json" "simctl spawn .* log stream" "debugserver"; do
    if pgrep -f "$pat" >/dev/null 2>&1; then
      pkill -9 -f "$pat" 2>/dev/null || true
      killed="yes"
    fi
  done
  [[ -n "$killed" ]] && c_info "iOS: 前回ビルドの残骸プロセス（xattr等）を掃除しました"
  return 0
}

# ---- 各ターゲット起動 -------------------------------------------------------
start_ios() {
  stop_target ios
  cleanup_ios_orphans
  c_info "iOS: シミュレータを確認..."
  open -a Simulator >/dev/null 2>&1 || true

  # Xcodeが実際にビルドできるシミュレータ一覧を取得（唯一信頼できる判定元）。
  c_info "iOS: Xcodeがビルド可能なシミュレータを確認中..."
  local dests; dests="$(xcode_sim_destinations)"

  local dev=""
  if [[ -n "$dests" ]]; then
    # まず Booted かつビルド可能なものを使う
    dev="$(booted_buildable_udid "$dests")"
    if [[ -z "$dev" ]]; then
      # Booted があっても非対応ランタイム(古いiOS)なら、その旨を伝えて対応機種を boot
      if [[ -n "$(ios_booted_udid)" ]]; then
        c_warn "iOS: 起動中シミュレータはXcode非対応ランタイム(古いiOS)です。ビルド可能な機種を起動します"
      fi
      local target; target="$(pick_boot_target "$dests")"
      if [[ -n "$target" ]]; then
        c_info "iOS: ビルド可能な機種を boot: $target"
        xcrun simctl boot "$target" 2>/dev/null || true
        for _ in $(seq 1 30); do
          dev="$(booted_buildable_udid "$dests")"; [[ -n "$dev" ]] && break; sleep 1
        done
      fi
    fi
  else
    # xcodebuild 宛先が取れないとき（Generated.xcconfig 未生成等）は従来ロジックへ
    c_warn "iOS: Xcode宛先を取得できず。従来の方法でシミュレータを選択します"
    dev="$(ios_booted_udid)"
    if [[ -z "$dev" ]]; then
      c_info "iOS: booted シミュレータ無し → '$IOS_DEFAULT_DEVICE' を boot"
      # 機種名 boot は同名の別UDIDを二重起動しうるので、まず UDID を特定してから boot する
      local udid
      udid="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import sys, json
name = sys.argv[1]
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
for runtime in d.get("devices", {}).values():
    for dev in runtime:
        if dev.get("name") == name:
            print(dev.get("udid","")); sys.exit(0)
' "$IOS_DEFAULT_DEVICE" 2>/dev/null)"
      if [[ -n "$udid" ]]; then
        xcrun simctl boot "$udid" 2>/dev/null || true
      else
        c_warn "iOS: '$IOS_DEFAULT_DEVICE' が見つかりません。機種名で boot を試みます"
        xcrun simctl boot "$IOS_DEFAULT_DEVICE" 2>/dev/null || true
      fi
      for _ in $(seq 1 30); do
        dev="$(ios_booted_udid)"; [[ -n "$dev" ]] && break; sleep 1
      done
    fi
  fi

  if [[ -z "$dev" ]]; then
    c_err "iOS: ビルド可能なシミュレータを準備できませんでした。'xcrun simctl list devices' と Xcode のインストール済みランタイムを確認してください"
    return 1
  fi
  c_ok "iOS: device=$dev"
  launch_flutter ios -d "$dev"
  tail_logs ios
}

start_android() {
  stop_target android
  c_info "Android: エミュレータを確認..."
  local dev; dev="$(android_device_id)"
  if [[ -z "$dev" ]]; then
    c_info "Android: 起動中エミュレータ無し → AVD '$ANDROID_AVD' を launch"
    flutter emulators --launch "$ANDROID_AVD" >/dev/null 2>&1 || \
      c_warn "Android: AVD launch に失敗（既に起動中かもしれません）"
    c_info "Android: boot 完了を待機中..."
    for _ in $(seq 1 60); do
      dev="$(android_device_id)"; [[ -n "$dev" ]] && break; sleep 2
    done
  fi
  if [[ -z "$dev" ]]; then
    c_err "Android: エミュレータを検出できませんでした。'flutter emulators' / 'flutter devices' を確認してください"
    return 1
  fi
  c_ok "Android: device=$dev"
  launch_flutter android -d "$dev"
  tail_logs android
}

start_web() {
  stop_target web
  # web-server モードは既存の 8080 を掴んだままだと起動できないので念のため解放。
  # ※ LISTEN 中のサーバプロセスだけを対象にする（-sTCP:LISTEN）。これを付けないと
  #   Chrome 側のクライアント接続まで巻き込んで kill してしまうため。
  local stale; stale="$(lsof -ti:"$WEB_PORT" -sTCP:LISTEN 2>/dev/null || true)"
  [[ -n "$stale" ]] && { c_info "Web: ポート $WEB_PORT の待受プロセスを解放"; echo "$stale" | xargs kill -9 2>/dev/null || true; }

  launch_flutter web -d web-server --web-port="$WEB_PORT" \
    --dart-define=WEB_APP_CHECK_DEBUG_TOKEN="$WEB_DEBUG_TOKEN"

  # サーバが待受開始するまで待ってから Chrome を reload / open（LISTEN を判定基準にする）
  c_info "Web: サーバ待受を待機中 (localhost:$WEB_PORT)..."
  for _ in $(seq 1 60); do
    lsof -ti:"$WEB_PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
    sleep 1
  done
  reload_or_open_chrome
  tail_logs web
}

# 既存 Chrome に localhost:PORT タブがあれば reload、無ければ新規に開く
reload_or_open_chrome() {
  local url="http://localhost:$WEB_PORT"
  local reloaded
  reloaded="$(osascript <<OSA 2>/dev/null
tell application "Google Chrome"
  set found to false
  repeat with w in windows
    repeat with t in tabs of w
      if (URL of t) contains "localhost:$WEB_PORT" then
        tell t to reload
        set found to true
      end if
    end repeat
  end repeat
  return found
end tell
OSA
)"
  if [[ "$reloaded" == "true" ]]; then
    c_ok "Web: 既存 Chrome タブを reload しました ($url)"
  else
    c_info "Web: 既存タブ無し → Chrome で $url を開きます"
    open -a "Google Chrome" "$url" 2>/dev/null || open "$url"
  fi
}

# ---- ログ追尾 ---------------------------------------------------------------
tail_logs() {
  local t="$1" lf; lf="$(logfile "$t")"
  c_info "$t: ログを表示します（Ctrl-C で追尾終了。アプリは動き続けます）"
  echo "----------------------------------------------------------------------"
  tail -n +1 -f "$lf"
}

# ---- status -----------------------------------------------------------------
show_status() {
  for t in ios android web; do
    if is_running "$t"; then
      c_ok "$t: 起動中 (pid=$(target_pids "$t"))  log: $(logfile "$t")"
    else
      c_info "$t: 停止"
    fi
  done
}

usage() {
  cat <<EOF
DARIAS アプリ起動スクリプト

使い方:
  ./run.sh ios | web | android      起動（既存があれば再起動）
  ./run.sh restart <target>         再起動（ios|web|android）
  ./run.sh stop <target|all>        停止
  ./run.sh status                   起動状況
  ./run.sh logs <target>            ログ追尾

例:
  ./run.sh ios
  ./run.sh web
  ./run.sh android
  ./run.sh restart web
  ./run.sh stop all
EOF
}

# ---- ディスパッチ -----------------------------------------------------------
CMD="${1:-ios}"
case "$CMD" in
  ios)     start_ios ;;
  web)     start_web ;;
  android) start_android ;;
  restart)
    case "${2:-}" in
      ios)     start_ios ;;
      web)     start_web ;;
      android) start_android ;;
      *) c_err "restart の対象を指定してください: ios|web|android"; exit 1 ;;
    esac ;;
  stop)
    case "${2:-}" in
      all)                stop_target ios; stop_target android; stop_target web ;;
      ios|web|android)    stop_target "$2" ;;
      *) c_err "stop の対象を指定してください: ios|web|android|all"; exit 1 ;;
    esac ;;
  logs)
    case "${2:-}" in
      ios|web|android)    tail_logs "$2" ;;
      *) c_err "logs の対象を指定してください: ios|web|android"; exit 1 ;;
    esac ;;
  status)  show_status ;;
  -h|--help|help) usage ;;
  *) c_err "不明なコマンド: $CMD"; echo; usage; exit 1 ;;
esac
