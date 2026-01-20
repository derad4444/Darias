const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const { logger } = require('./src/utils/logger');
const { GMAIL_USER, GMAIL_APP_PASSWORD } = require('./src/config/config');

// Firebase Admin初期化（未初期化の場合のみ）
if (!admin.apps.length) {
  admin.initializeApp();
}

// Nodemailer設定
const createTransporter = () => {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: GMAIL_USER.value(),
      pass: GMAIL_APP_PASSWORD.value()
    }
  });
};

const sendContactEmail = onDocumentCreated({
  document: 'contacts/{contactId}',
  secrets: [GMAIL_USER, GMAIL_APP_PASSWORD]
}, async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error('No data associated with the event');
      return;
    }

    const contactData = snapshot.data();
    const contactId = event.params.contactId;

    try {
      // ユーザー情報を取得
      const db = getFirestore();
      const userDoc = await db.collection('users').doc(contactData.userId).get();

      if (!userDoc.exists) {
        throw new Error('ユーザー情報が見つかりません');
      }

      const userData = userDoc.data();

      // 管理者向けメールを送信
      const adminEmailResult = await sendAdminEmail(contactData, userData);

      // ユーザー向け確認メールを送信
      const userEmailResult = await sendUserConfirmationEmail(contactData, userData);

      // 送信成功をFirestoreに記録
      await db.collection('contacts').doc(contactId).update({
        status: 'sent',
        emailSentAt: new Date(),
        adminEmailSent: true,
        userEmailSent: true,
        adminEmailId: adminEmailResult.messageId,
        userEmailId: userEmailResult.messageId
      });

      logger.info(`Contact email sent successfully for contact ID: ${contactId}`);

    } catch (error) {
      logger.error('Error sending contact email:', error);

      // エラーをFirestoreに記録
      const db = getFirestore();
      await db.collection('contacts').doc(contactId).update({
        errorMessage: error.message,
        errorAt: new Date()
      });

      throw error;
    }
  });

// 管理者向けメール送信
async function sendAdminEmail(contactData, userData) {
  const transporter = createTransporter();
  const emailBody = createAdminEmailBody(contactData, userData);

  const mailOptions = {
    from: `"DARIAS App" <${GMAIL_USER.value()}>`,
    to: 'darias.app4@gmail.com',
    replyTo: userData.email, // ユーザーのメールアドレスを返信先に設定
    subject: contactData.subject,
    text: emailBody
  };

  return await transporter.sendMail(mailOptions);
}

// ユーザー向け確認メール送信
async function sendUserConfirmationEmail(contactData, userData) {
  const transporter = createTransporter();
  const emailBody = createUserConfirmationEmailBody(contactData, userData);

  const mailOptions = {
    from: `"DARIAS App" <${GMAIL_USER.value()}>`,
    to: userData.email,
    subject: '【DARIAS】お問い合わせを受け付けました',
    text: emailBody
  };

  return await transporter.sendMail(mailOptions);
}

// 管理者向けメール本文作成
function createAdminEmailBody(contactData, userData) {
  const deviceInfo = contactData.deviceInfo || {};

  return `
DARIASアプリに新しいお問い合わせが届きました。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
■ お問い合わせ情報
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【カテゴリ】${contactData.categoryDisplay || 'その他'}
【受信日時】${formatDate(contactData.createdAt)}

■ ユーザー情報
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【ユーザー名】${userData.name || '不明'}
【メールアドレス】${userData.email || '不明'}
【ユーザーID】${contactData.userId || '不明'}
【キャラクターID】${userData.character_id || '未設定'}

■ お問い合わせ内容
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${contactData.message || '内容が記録されていません'}

■ デバイス・アプリ情報
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【アプリ名】DARIAS
【アプリバージョン】${deviceInfo.appVersion || '不明'}
【デバイス】${deviceInfo.deviceModel || '不明'}
【iOS バージョン】${deviceInfo.iosVersion || '不明'}
【デバイス名】${deviceInfo.deviceName || '不明'}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

このメールに直接返信することで、ユーザーに回答できます。

DARIAS自動送信システム
`;
}

// ユーザー向け確認メール本文作成
function createUserConfirmationEmailBody(contactData, userData) {
  return `
${userData.name || 'お客様'} 様

この度は、DARIASアプリにお問い合わせいただき、誠にありがとうございます。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
■ お問い合わせ受付完了
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【受付日時】${formatDate(contactData.createdAt)}
【お問い合わせ種類】${contactData.categoryDisplay || 'その他'}

お送りいただいたお問い合わせ内容を確認いたしました。
開発チームにて内容を確認し、順次対応いたします。

■ 対応について
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【返答目安】通常 2-3営業日以内
【返答方法】このメールアドレスに直接返信いたします

※ お問い合わせ内容によっては、お時間をいただく場合がございます。
※ バグ報告の場合、修正版のリリース時期もお知らせいたします。

■ お問い合わせ内容（確認用）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${contactData.message || '内容が記録されていません'}

■ その他のサポート
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【公式Instagram】@darias_1025
【アプリストア】App Store で「DARIAS」を検索

今後ともDARIASをよろしくお願いいたします。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DARIAS開発チーム
darias.app4@gmail.com

※ このメールは自動送信されています。
※ 返信いただければ、開発者が直接対応いたします。
`;
}

// 日時フォーマット関数
function formatDate(timestamp) {
  if (!timestamp) return '不明';

  try {
    const date = timestamp.toDate();
    return date.toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'Asia/Tokyo'
    });
  } catch (error) {
    console.error('Date formatting error:', error);
    return '日時取得エラー';
  }
}

module.exports = { sendContactEmail };