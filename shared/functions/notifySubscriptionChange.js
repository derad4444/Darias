const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const {getFirestore} = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const {logger} = require('./src/utils/logger');
const {GMAIL_USER, GMAIL_APP_PASSWORD} = require('./src/config/config');

// Firebase Admin初期化（デフォルトアプリの存在を確認して初期化）
try { admin.app(); } catch (e) { admin.initializeApp(); }

/** 通知先（運営）のメールアドレス。sendContactEmail.js の管理者宛と同じ */
const ADMIN_EMAIL = 'darias.app4@gmail.com';

const createTransporter = () => {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: GMAIL_USER.value(),
      pass: GMAIL_APP_PASSWORD.value(),
    },
  });
};

/**
 * プレミアムプランの課金・解約を運営へメール通知する。
 *
 * iOS(validateAppStoreReceipt) / Android(validateGooglePlayReceipt) /
 * Appleのサーバー通知(appleServerNotification) はいずれも
 * users/{userId}/subscription/current を書き換えるため、
 * このドキュメントのトリガー1本で3経路すべてをカバーできる。
 *
 * 通知するタイミング:
 *   - active 以外 → active … 新規課金・再開
 *   - active → active で end_date が変わった … 自動更新
 *   - active → active 以外 … 解約・失効
 */
const notifySubscriptionChange = onDocumentWritten({
  document: 'users/{userId}/subscription/current',
}, async (event) => {
  const userId = event.params.userId;
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;

  // ドキュメント削除時は通知しない
  if (!after) return;

  const beforeActive = before?.status === 'active';
  const afterActive = after.status === 'active';
  const beforeEnd = before?.end_date ? before.end_date.toMillis() : null;
  const afterEnd = after.end_date ? after.end_date.toMillis() : null;

  let eventType = null;
  if (!beforeActive && afterActive) {
    eventType = 'purchased';
  } else if (beforeActive && !afterActive) {
    eventType = 'cancelled';
  } else if (beforeActive && afterActive && beforeEnd !== afterEnd) {
    // 期限が伸びた＝自動更新。通知後の記録書き戻し（end_date は変わらない）とはここで区別する
    eventType = 'renewed';
  }

  // 状態が変わらない書き込み（通知後の記録更新を含む）はここで終了
  if (!eventType) return;

  // 同じ変化での再送を防ぐキー。トリガーの再実行時に二重送信しない
  const notifyKey = [
    eventType,
    after.transaction_id || after.original_transaction_id || 'unknown',
    after.end_date ? after.end_date.toMillis() : 'none',
  ].join(':');

  if (after.adminNotifyKey === notifyKey) {
    logger.info(`Subscription notification already sent: ${userId} (${notifyKey})`);
    return;
  }

  const db = getFirestore();

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};

    const transporter = createTransporter();
    await transporter.sendMail({
      from: `"DARIAS App" <${GMAIL_USER.value()}>`,
      to: ADMIN_EMAIL,
      subject: SUBJECTS[eventType],
      text: createEmailBody(eventType, userId, userData, after),
    });

    await event.data.after.ref.set({
      adminNotifyKey: notifyKey,
      adminNotifiedAt: admin.firestore.Timestamp.now(),
    }, {merge: true});

    logger.info(`Subscription notification sent: ${userId} (${eventType})`);
  } catch (error) {
    logger.error('Failed to send subscription notification', error, {userId, eventType});
    throw error;
  }
});

/** イベント種別ごとの件名 */
const SUBJECTS = {
  purchased: '【DARIAS】プレミアムプランの課金がありました',
  renewed: '【DARIAS】プレミアムプランが自動更新されました',
  cancelled: '【DARIAS】プレミアムプランが解約・失効しました',
};

/** イベント種別ごとの本文冒頭 */
const TITLES = {
  purchased: 'プレミアムプランの課金がありました。',
  renewed: 'プレミアムプランが自動更新されました。',
  cancelled: 'プレミアムプランが解約・失効しました。',
};

/** payment_method を日本語のストア名にする */
function storeName(paymentMethod) {
  switch (paymentMethod) {
    case 'app_store':
      return 'App Store（iOS）';
    case 'google_play':
      return 'Google Play（Android）';
    default:
      return paymentMethod || '不明';
  }
}

function formatDate(timestamp) {
  if (!timestamp) return '不明';

  try {
    return timestamp.toDate().toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'Asia/Tokyo',
    });
  } catch (error) {
    logger.error('Date formatting error', error);
    return '日時取得エラー';
  }
}

function createEmailBody(eventType, userId, userData, subscription) {
  const title = TITLES[eventType];
  const dateLabel = eventType === 'cancelled' ? '終了日' : '次回更新日';

  return `
DARIASで${title}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
■ ユーザー情報
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【ユーザー名】${userData.name || '不明'}
【メールアドレス】${userData.email || '不明'}
【ユーザーID】${userId}

■ サブスクリプション情報
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【ステータス】${subscription.status || '不明'}
【プラン】${subscription.plan || '不明'}
【ストア】${storeName(subscription.payment_method)}
【商品ID】${subscription.product_id || '不明'}
【開始日】${formatDate(subscription.start_date)}
【${dateLabel}】${formatDate(subscription.end_date)}
【自動更新】${subscription.auto_renewal === true ? 'あり' : 'なし'}
【取引ID】${subscription.transaction_id || '不明'}
【検知日時】${formatDate(admin.firestore.Timestamp.now())}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DARIAS自動送信システム
`;
}

module.exports = {notifySubscriptionChange};
