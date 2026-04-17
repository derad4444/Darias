// functions/const/answerAppQuestion.js
// アプリに関する質問 & ユーザーデータ参照に答えるCloud Function

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const db = getFirestore();

// ============================================================
// アプリガイド（システムプロンプトに埋め込む）
// ============================================================
const APP_GUIDE = `
# DARIASアプリ 機能ガイド

## 基本機能一覧
- **チャット**: キャラクターと会話できる。メモ・タスク・予定の追加もチャットから可能。
- **メモ**: テキストメモを保存・管理できる。
- **タスク（TODO）**: やることリストを管理できる。優先度・期日・タグ設定可能。
- **予定（カレンダー）**: 日程を管理できる。月間カレンダーで確認可能。
- **日記**: アクティビティ型日記が毎日23:50に自動生成される。
- **自分会議（6人会議）**: 自分の6つの分身キャラクターが悩みについてディスカッションしてくれる機能。
- **フレンド**: アプリ内でフレンドを作り、予定を共有したり相性診断ができる。
- **相性診断**: フレンドとのBIG5ベースのカテゴリ別相性診断（友情・恋愛・仕事・信頼）。
- **プレミアム**: 月額課金でキャラクター返答のAIモデルが高品質になり、自分会議が月30回利用可能になる。

## チャットでできること
| 操作 | 入力例 |
|------|--------|
| メモを追加 | 「〇〇をメモして」「メモしといて：〇〇」|
| タスクを追加 | 「〇〇をタスクに追加」「TODO：〇〇」|
| 予定を追加 | 「明日14時に会議」「来週月曜に歯医者の予定」|
| キャラクターと会話 | 自由にメッセージを送る |
| アプリの使い方を質問 | 「〇〇はどうやるの？」|

## メモの使い方
- **チャットから追加**: 「〇〇をメモして」と入力 → 確認ダイアログ → 追加/編集/キャンセル
- **メモ画面から追加**: 右下の＋ボタン → 新規メモ作成
- **編集**: メモ一覧からタップして編集（自動保存）
- **タグ・ピン留め**: メモ詳細画面で設定可能
- **メモからタスク登録**: メモ編集画面のツールバーにある「タスク」ボタン（✓アイコン）を押すと行頭にタスクマークが付く。タスクマーク付きの行が1件以上あると「タスクに登録」ボタンが表示され、チェックした行をタスク（TODO）に一括登録できる

## タスクの使い方
- **チャットから追加**: 「〇〇をタスクに追加」「TODO：〇〇」と入力
- **タスク画面から追加**: 右下の＋ボタン
- **完了にする**: タスク一覧でチェックボックスをタップ
- **優先度**: 高・中・低 の3段階
- **期限設定**: タスク編集画面でインラインカレンダーから日付・時刻を選択して設定できる

## 予定の使い方
- **チャットから追加**: 日時を含む文章を送ると自動検出 → 確認ダイアログ
- **カレンダーから追加**: 右下の＋ボタン
- **繰り返し設定**: 毎日・毎週・毎月・毎年などの繰り返しオプションあり
- **リマインダー**: 予定編集画面で通知タイミングを設定できる（通知設定画面での通知許可も必要）
- **フレンドの予定確認**: フレンドが予定を公開している場合、カレンダー画面でフレンドの予定も表示できる（フレンド一覧からフレンドを選択してオン/オフ）

## チャット履歴の確認
- ホーム画面には最新の返答1件のみ吹き出しで表示される（過去のメッセージはそこでは見られない）
- 過去の会話履歴は「履歴」ボタン（ホーム画面のキャラクターの下にあるボタン）をタップして確認できる
- 履歴画面ではチャット・自分会議・日記をタブで切り替えられ、日付ごとに表示される。検索機能もある
- 会議（自分会議）の結論は、次回のチャット返答にコンテキストとして自動反映される

## キャラクターについて
- BIG5性格診断をもとにキャラクターの性格が変化する
- 診断はチャットで「性格診断して」と入力すると始まる。100問の質問に1〜5で答える
- 診断結果（BIG5スコア・性格タイプ・強み・弱みなど）は「詳細」タブで確認できる
- キャラクターはこのアプリ（DARIAS）専用のAIアシスタント。他のサービスやアプリのことは答えられない
- キャラクターを変更したい場合は「設定」→「キャラクター選択」または「詳細」タブから変更できる
- キャラクターのアバター画像は「詳細」タブのキャラクター詳細画面から変更できる

## 日記（自動生成）
- 毎日23:50に当日の活動（チャット・タスク・メモ・予定）をもとにアクティビティ型日記が自動生成される
- 日記は「履歴」ボタン → 日記タブで確認できる
- 日記に自分のコメントを追記することもできる

## 自分会議（6人会議）の使い方
- 自分の6つの分身キャラクター（今の自分・真逆の自分・理想の自分・本音の自分・子供の頃の自分・未来の自分）が悩みについてディスカッションしてくれる機能
- **アクセス方法**: ホーム画面のメニューまたは「会議を開く」ボタンから利用
- **利用制限**: 無料ユーザーは生涯1回まで。プレミアムユーザーは月30回まで
- **操作手順**: 悩みカテゴリを選択 → 悩みを入力 → 6人が3ラウンドで議論 → 結論（まとめ・推奨・次のステップ）が表示される
- **会議結論の活用**: 会議後に「チャットで深掘りする」ボタンを押すと、次のチャット返答に会議結論が自動的に反映される
- **履歴確認**: 「履歴」ボタン → 自分会議タブで過去の会議を確認できる

## フレンド機能の使い方
- **アクセス方法**: 画面下部ナビゲーションの「フレンド」タブ
- **フレンド追加**: フレンド画面の検索ボタンから名前またはメールアドレスで検索 → フレンド申請を送る
- **申請の承認**: 受信した申請はフレンド画面の通知バッジで確認 → 承認/拒否できる
- **フレンド削除**: フレンド詳細画面またはフレンド一覧の長押しから削除できる
- **予定共有レベルの設定**: フレンドごとに「非公開」「公開」「全公開」の3段階で設定できる
  - 非公開: 予定を一切見せない
  - 公開: 公開設定の予定のみ見せる
  - 全公開: 非公開設定の予定も含めてすべて見せる
- **フレンドの予定確認**: カレンダー画面でフレンドを選択してオンにすると、そのフレンドの予定がカレンダーに重ねて表示される

## 相性診断の使い方
- **アクセス方法**: フレンドタブ → フレンド詳細 → 相性診断ボタン
- **カテゴリ**: 友情・恋愛・仕事・信頼の4カテゴリそれぞれを個別に診断できる
- **スコア**: 双方のBIG5性格スコアをもとに0〜100%で表示される（BIG5診断が必要）
- **診断の解放方法**: 各カテゴリはリワード広告（動画広告）を視聴することで診断できる
- **診断結果**: スコア・キャラクターの会話・コメント・アドバイスが表示される
- **条件**: 自分とフレンド双方がBIG5性格診断を完了している必要がある

## プレミアム機能について
- **加入方法**: 設定画面の「プレミアムに登録」からApp Store/Google Playで月額課金
- **プレミアムでできること**:
  - キャラクター返答が高品質AIモデル（GPT-4o）になる（無料はGPT-4o-mini）
  - 日記生成も高品質AIモデルを使用
  - 自分会議が月30回まで利用可能（無料は生涯1回）
- **解約方法**: App Store/Google PlayアプリのサブスクリプションページからキャンセルできるURLを「設定」→「プレミアム」画面で確認できる

## タグ管理
- **アクセス方法**: 設定画面 → 「タグ管理」
- **タグの追加**: タグ名と好きな色（カラーピッカー）を設定して追加できる
- **用途**: メモ・タスク・予定に設定でき、色でカテゴリ分けして管理しやすくなる
- **公開設定**: タグごとに「フレンドに公開するか」を設定できる（非公開タグの付いた予定はフレンドから見えない）

## 設定
- **テーマカラー変更**: 設定画面 → 「テーマ設定」からアプリのメインカラーやグラデーションを変更できる
- **音量設定**: 設定画面 → 「音量設定」でBGM音量とキャラクター音声の音量を個別に調整できる。ミュートボタンでワンタップ消音も可能
- **通知設定**: 設定画面 → 「通知設定」で予定リマインダーの通知許可・設定を確認できる
- **データエクスポート**: 設定画面 → 「データエクスポート」でメモ・タスクをエクスポートできる

## アカウント管理
- **パスワード変更（メール認証の場合）**: 設定画面 → 「パスワードを忘れた」のリンクからリセットメールを送れる
- **アカウント削除**: 設定画面 → 「アカウント削除」から削除できる（削除するとすべてのデータが消えて元に戻せない）
- **プレミアムのまま退会する場合**: App Store/Google Playのサブスクリプションを先にキャンセルしてからアカウントを削除することを推奨
`;

// ============================================================
// ユーザーデータをFirestoreから取得
// ============================================================
async function fetchUserData(userId, dataTypes) {
  const results = {};
  const now = new Date();

  if (dataTypes.includes("schedules")) {
    try {
      // 前後30日の予定を取得
      const from = new Date(now);
      from.setDate(from.getDate() - 1);
      const to = new Date(now);
      to.setDate(to.getDate() + 30);

      const snap = await db
          .collection("users").doc(userId)
          .collection("schedules")
          .where("startDate", ">=", from)
          .where("startDate", "<=", to)
          .orderBy("startDate")
          .limit(20)
          .get();

      results.schedules = snap.docs.map((doc) => {
        const d = doc.data();
        return {
          title: d.title,
          startDate: d.startDate?.toDate()?.toLocaleDateString("ja-JP", {timeZone: "Asia/Tokyo"}),
          endDate: d.endDate?.toDate()?.toLocaleDateString("ja-JP", {timeZone: "Asia/Tokyo"}),
          isAllDay: d.isAllDay,
          location: d.location || "",
        };
      });
    } catch (e) {
      console.warn("schedules fetch error:", e.message);
    }
  }

  if (dataTypes.includes("todos")) {
    try {
      const snap = await db
          .collection("users").doc(userId)
          .collection("todos")
          .where("isCompleted", "==", false)
          .orderBy("createdAt", "desc")
          .limit(20)
          .get();

      results.todos = snap.docs.map((doc) => {
        const d = doc.data();
        return {
          title: d.title,
          priority: d.priority || "中",
          dueDate: d.dueDate?.toDate()?.toLocaleDateString("ja-JP", {timeZone: "Asia/Tokyo"}) || null,
        };
      });
    } catch (e) {
      console.warn("todos fetch error:", e.message);
    }
  }

  if (dataTypes.includes("memos")) {
    try {
      const snap = await db
          .collection("users").doc(userId)
          .collection("memos")
          .orderBy("updatedAt", "descending")
          .limit(10)
          .get();

      results.memos = snap.docs.map((doc) => {
        const d = doc.data();
        return {title: d.title, tag: d.tag || ""};
      });
    } catch (e) {
      console.warn("memos fetch error:", e.message);
    }
  }

  return results;
}

// ============================================================
// Cloud Function本体
// ============================================================
exports.answerAppQuestion = onCall(
    {
      region: "asia-northeast1",
      memory: "256MiB",
      timeoutSeconds: 60,
      minInstances: 0,
      enforceAppCheck: false,
    },
    async (request) => {
      const {data} = request;
      const {userId, userMessage, dataTypes = []} = data;

      if (!userId || !userMessage) {
        return {error: "Missing userId or userMessage"};
      }

      try {
        // 必要に応じてユーザーデータを取得
        let userDataSection = "";
        if (dataTypes.length > 0) {
          const userData = await fetchUserData(userId, dataTypes);
          if (Object.keys(userData).length > 0) {
            userDataSection = "\n\n## あなたのデータ（参考情報）\n" +
              JSON.stringify(userData, null, 2);
          }
        }

        // 日本時間の現在日時
        const nowStr = new Date().toLocaleDateString("ja-JP", {
          year: "numeric", month: "long", day: "numeric",
          weekday: "long", timeZone: "Asia/Tokyo",
        });

        const systemPrompt =
          `あなたはDARIASというアプリのキャラクターです。` +
          `ユーザーのアプリに関する質問や、データについての質問に答えてください。` +
          `回答は100文字以内で、フレンドリーに答えてください。` +
          `現在日時：${nowStr}` +
          APP_GUIDE +
          userDataSection;

        const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [
                {role: "system", content: systemPrompt},
                {role: "user", content: userMessage},
              ],
              temperature: 0.7,
              max_tokens: 200,
            },
        );

        const reply = completion?.choices?.[0]?.message?.content?.trim() ?? "うまく答えられなかったよ、ごめんね。";
        console.log(`✅ answerAppQuestion: "${userMessage}" → "${reply}"`);

        return {reply};
      } catch (e) {
        console.error("answerAppQuestion error:", e);
        return {reply: "うまく答えられなかったよ、ごめんね。"};
      }
    },
);
