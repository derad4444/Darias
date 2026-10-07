// functions/const/sendPasswordResetMail.js
// パスワード再設定メールを DARIAS の文面で送る
//
// Firebase Authentication 標準の再設定メールは、このプロジェクトではテンプレートを
// 変更できない（コンソール・Admin API とも EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED）。
// 標準の文面だとアプリ名すら出ないため、再設定用のリンクだけ Firebase に作らせ、
// メールはお問い合わせと同じ Gmail から送る。リンクの先は dariasapp.web.app/auth/action/。
// 仕様: shared/docs/architecture/認証仕様書.md「パスワードの再設定」

const crypto = require("crypto");
const nodemailer = require("nodemailer");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {admin} = require("../src/utils/firebaseInit");
const {GMAIL_USER, GMAIL_APP_PASSWORD} = require("../src/config/config");

// メールのリンクから開く再設定ページ（dl/auth/action/index.html）
const ACTION_PAGE = "https://dariasapp.web.app/auth/action/";
// 再設定ページが Firebase Auth を呼ぶための Web API キー（公開してよいキー。Firebase の標準メールのリンクにも入っている）
const WEB_API_KEY = "AIzaSyCiQ_AG2ui896nPJNcNieaHnie6tghsZDk";

// 同じメールアドレスへの送信の間隔と、24時間あたりの上限（いたずらで大量に送られるのを防ぐ）
const MIN_INTERVAL_MS = 60 * 1000;
const MAX_PER_DAY = 5;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** HTML に埋め込む文字をエスケープする */
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;",
  })[c]);
}

/** 再設定メールの本文 */
function buildMail(email, link) {
  const e = escapeHtml(email);
  const l = escapeHtml(link);
  const html = `<div style="font-family:-apple-system,'Hiragino Sans','Noto Sans JP',sans-serif;color:#2d2d2d;line-height:1.8;max-width:520px;">
<p>DARIASをご利用いただきありがとうございます。</p>
<p>${e} のDARIASアカウントで、パスワードの再設定が申し込まれました。<br>下のボタンから新しいパスワードを設定してください。</p>
<p style="margin:24px 0;"><a href="${l}" style="display:inline-block;padding:12px 28px;background:#a084ca;color:#ffffff;border-radius:10px;text-decoration:none;font-weight:bold;">パスワードを再設定する</a></p>
<p style="font-size:13px;color:#666;">ボタンが押せない場合は、次のURLを開いてください。<br><a href="${l}" style="color:#7c64ad;word-break:break-all;">${l}</a></p>
<p style="font-size:13px;color:#666;">このリンクの有効期限は1時間です。期限が切れた場合は、アプリのログイン画面の「パスワードをお忘れの方」からもう一度お送りください。</p>
<p style="font-size:13px;color:#666;">このメールに心当たりがない場合は、何もせずに破棄してください。パスワードは変更されません。</p>
<p style="font-size:12px;color:#999;">※このメールは送信専用のため返信できません。お問い合わせはアプリの「設定」→「お問い合わせ」からお願いします。</p>
<p>DARIAS</p>
</div>`;
  const text = `DARIASをご利用いただきありがとうございます。

${email} のDARIASアカウントで、パスワードの再設定が申し込まれました。
次のURLを開いて、新しいパスワードを設定してください。

${link}

このリンクの有効期限は1時間です。期限が切れた場合は、アプリのログイン画面の「パスワードをお忘れの方」からもう一度お送りください。
このメールに心当たりがない場合は、何もせずに破棄してください。パスワードは変更されません。

※このメールは送信専用のため返信できません。お問い合わせはアプリの「設定」→「お問い合わせ」からお願いします。

DARIAS`;
  return {html, text};
}

/**
 * 送ってよいかを確かめ、送るなら記録する（同じアドレスへの連続送信を防ぐ）
 * @return {Promise<boolean>} 送ってよいなら true
 */
async function reserveSend(email) {
  const db = admin.firestore();
  const key = crypto.createHash("sha256").update(email).digest("hex");
  const ref = db.collection("passwordResetRequests").doc(key);
  const now = Date.now();
  return db.runTransaction(async (t) => {
    const d = (await t.get(ref)).data() || {};
    const recent = (d.sentAt || []).filter((ms) => now - ms < 24 * 60 * 60 * 1000);
    if (recent.length > 0 && now - Math.max(...recent) < MIN_INTERVAL_MS) return false;
    if (recent.length >= MAX_PER_DAY) return false;
    t.set(ref, {sentAt: [...recent, now]});
    return true;
  });
}

exports.sendPasswordResetMail = onCall(
    {
      region: "asia-northeast1",
      memory: "256MiB",
      timeoutSeconds: 30,
      minInstances: 0,
      // ログアウト中に使うのでログインは求めない。代わりに App Check でアプリ以外からの呼び出しを防ぐ
      enforceAppCheck: true,
    },
    async (request) => {
      const email = String((request.data || {}).email || "").trim().toLowerCase();
      if (!EMAIL_PATTERN.test(email) || email.length > 254) {
        throw new HttpsError("invalid-argument", "メールアドレスの形式が正しくありません");
      }

      // 登録の有無は返さない（どのアドレスが登録されているかを調べられないようにするため）。
      // 登録が無い・パスワードが無い（Google / Apple だけ）場合は送らずに成功を返す
      let user;
      try {
        user = await admin.auth().getUserByEmail(email);
      } catch (e) {
        if (e.code === "auth/user-not-found") return {ok: true};
        throw new HttpsError("internal", "送信できませんでした");
      }
      if (!user.providerData.some((p) => p.providerId === "password")) {
        console.log("ℹ️ パスワードの無いアカウントへの再設定申込み（送信しない）");
        return {ok: true};
      }

      if (!(await reserveSend(email))) {
        console.log("ℹ️ 再設定メールの送信間隔・上限のため送信しない");
        return {ok: true};
      }

      try {
        const firebaseLink = await admin.auth().generatePasswordResetLink(email);
        const oobCode = new URL(firebaseLink).searchParams.get("oobCode");
        const link = `${ACTION_PAGE}?mode=resetPassword&oobCode=${encodeURIComponent(oobCode)}` +
          `&apiKey=${WEB_API_KEY}&lang=ja`;
        const {html, text} = buildMail(email, link);
        const transporter = nodemailer.createTransport({
          service: "gmail",
          auth: {user: GMAIL_USER.value(), pass: GMAIL_APP_PASSWORD.value()},
        });
        await transporter.sendMail({
          from: `"DARIAS" <${GMAIL_USER.value()}>`,
          to: email,
          subject: "【DARIAS】パスワード再設定のご案内",
          html,
          text,
        });
        console.log(`✅ パスワード再設定メールを送信 uid=${user.uid}`);
        return {ok: true};
      } catch (e) {
        console.error("🔥 パスワード再設定メールの送信エラー:", e);
        throw new HttpsError("internal", "送信できませんでした");
      }
    },
);
