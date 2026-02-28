// functions/src/functions/sendRegistrationEmail.js
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const { logger } = require('../utils/logger');
const { GMAIL_USER, GMAIL_APP_PASSWORD } = require('../config/config');

// Firebase Admin初期化（未初期化の場合のみ）
if (!admin.apps.length) {
  admin.initializeApp();
}

// Gmail SMTPを使用したメール送信設定
const createTransporter = () => {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: GMAIL_USER.value(), // Gmail アドレス
      pass: GMAIL_APP_PASSWORD.value(), // アプリパスワード
    },
  });
};

// メールテンプレートの作成
const createEmailTemplate = (userName, userId, registrationDate) => {
  const formattedDate = new Intl.DateTimeFormat('ja-JP', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Tokyo'
  }).format(registrationDate);

  return {
    subject: '【DARIAS】アカウント登録完了のお知らせ',
    html: `
    <div style="font-family: 'Hiragino Sans', 'ヒラギノ角ゴシック', sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
      <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
        <!-- ヘッダー -->
        <div style="text-align: center; margin-bottom: 30px;">
          <h1 style="color: #4285f4; font-size: 28px; margin: 0;">DARIAS</h1>
          <p style="color: #666; font-size: 16px; margin: 10px 0 0 0;">アカウント登録完了</p>
        </div>

        <!-- 挨拶 -->
        <div style="margin-bottom: 25px;">
          <p style="font-size: 16px; color: #333; line-height: 1.6; margin: 0;">
            ${userName} 様
          </p>
          <p style="font-size: 16px; color: #333; line-height: 1.6; margin: 15px 0 0 0;">
            この度は、DARIASアプリにご登録いただき、誠にありがとうございます。<br>
            アカウントの登録が正常に完了いたしました。
          </p>
        </div>

        <!-- 登録情報 -->
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 25px;">
          <h3 style="color: #333; font-size: 18px; margin: 0 0 15px 0; border-bottom: 2px solid #4285f4; padding-bottom: 8px;">
            ご登録情報
          </h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px; width: 120px;">ユーザーID:</td>
              <td style="padding: 8px 0; color: #333; font-size: 14px; font-weight: bold;">${userId}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">お名前:</td>
              <td style="padding: 8px 0; color: #333; font-size: 14px; font-weight: bold;">${userName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">登録日時:</td>
              <td style="padding: 8px 0; color: #333; font-size: 14px; font-weight: bold;">${formattedDate}</td>
            </tr>
          </table>
        </div>

        <!-- アプリの特徴 -->
        <div style="margin-bottom: 25px;">
          <h3 style="color: #333; font-size: 18px; margin: 0 0 15px 0; border-bottom: 2px solid #4285f4; padding-bottom: 8px;">
            DARIASアプリの主な機能
          </h3>
          <ul style="color: #333; font-size: 14px; line-height: 1.6; margin: 0; padding-left: 20px;">
            <li style="margin-bottom: 8px;">🤖 <strong>AI予定管理</strong> - AIがあなたの予定を効率的に管理・提案</li>
            <li style="margin-bottom: 8px;">🧠 <strong>AI性格診断</strong> - あなたの行動パターンからAIが性格を分析</li>
            <li style="margin-bottom: 8px;">📅 <strong>スマート予定提案</strong> - AIがあなたの生活スタイルに合わせた予定を提案</li>
            <li style="margin-bottom: 8px;">🔔 <strong>インテリジェント通知</strong> - AIが最適なタイミングで通知</li>
            <li style="margin-bottom: 8px;">📊 <strong>行動分析レポート</strong> - あなたの行動データを元にした詳細分析</li>
          </ul>
        </div>

        <!-- 注意事項 -->
        <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 8px; margin-bottom: 25px;">
          <h4 style="color: #856404; font-size: 16px; margin: 0 0 10px 0;">⚠️ 重要なお知らせ</h4>
          <ul style="color: #856404; font-size: 14px; line-height: 1.5; margin: 0; padding-left: 20px;">
            <li>このユーザーIDは今後のサポート時に必要となりますので、大切に保管してください。</li>
            <li>アカウント情報の変更やお問い合わせの際は、このメールを保存しておくことをお勧めします。</li>
          </ul>
        </div>

        <!-- サポート情報 -->
        <div style="margin-bottom: 20px;">
          <h3 style="color: #333; font-size: 18px; margin: 0 0 15px 0; border-bottom: 2px solid #4285f4; padding-bottom: 8px;">
            お困りの際は
          </h3>
          <p style="color: #333; font-size: 14px; line-height: 1.6; margin: 0;">
            ご不明な点やお困りのことがございましたら、アプリ内の「お問い合わせ」機能またはサポートチームまでお気軽にご連絡ください。
          </p>
        </div>

        <!-- フッター -->
        <div style="text-align: center; padding-top: 20px; border-top: 1px solid #e9ecef;">
          <p style="color: #666; font-size: 12px; margin: 0;">
            このメールは自動送信されています。返信はできませんのでご了承ください。<br>
            © 2025 DARIAS App. All rights reserved.
          </p>
        </div>
      </div>
    </div>
    `,
    text: `
${userName} 様

この度は、DARIASアプリにご登録いただき、誠にありがとうございます。
アカウントの登録が正常に完了いたしました。

【ご登録情報】
ユーザーID: ${userId}
お名前: ${userName}
登録日時: ${formattedDate}

【DARIASの主な機能】
- AI予定管理: AIがあなたの予定を効率的に管理・提案
- AI性格診断: あなたの行動パターンからAIが性格を分析
- スマート予定提案: AIがあなたの生活スタイルに合わせた予定を提案
- インテリジェント通知: AIが最適なタイミングで通知
- 行動分析レポート: あなたの行動データを元にした詳細分析

このユーザーIDは今後のサポート時に必要となりますので、大切に保管してください。

ご不明な点がございましたら、アプリ内のお問い合わせ機能よりご連絡ください。

DARIAS サポートチーム
    `
  };
};

// Firestoreのusersコレクションに新しいドキュメントが作成されたときにトリガー
const sendRegistrationEmail = onDocumentCreated({
  document: 'users/{userId}',
}, async (event) => {
  try {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error('No data associated with the event');
      return;
    }

    const userData = snapshot.data();
    const userId = event.params.userId;

    // 必要なデータの検証
    if (!userData.email || !userData.name) {
      logger.error('Required user data missing', { userId, email: userData.email, name: userData.name });
      return;
    }

    logger.info('Sending registration email', { userId, email: userData.email, name: userData.name });

    // メール送信の設定確認
    try {
      logger.info('Checking email configuration');
      const gmailUser = GMAIL_USER.value();
      const gmailPassword = GMAIL_APP_PASSWORD.value();
      if (!gmailUser || !gmailPassword) {
        logger.error('Email configuration missing. Please set GMAIL_USER and GMAIL_APP_PASSWORD secrets.');
        return;
      }
      logger.info('Email configuration verified');
    } catch (error) {
      logger.error('Failed to access email configuration secrets', error, { userId });
      return;
    }

    // メールトランスポーターの作成
    logger.info('Creating email transporter');
    const transporter = createTransporter();

    // 登録日時の取得（createdAt があればそれを使用、なければ現在時刻）
    const registrationDate = userData.createdAt ? userData.createdAt.toDate() : new Date();
    logger.info('Registration date retrieved', { registrationDate });

    // メールテンプレートの作成
    logger.info('Creating email template');
    const emailTemplate = createEmailTemplate(userData.name, userId, registrationDate);

    // メール送信オプション
    const mailOptions = {
      from: `"DARIAS App" <${GMAIL_USER.value()}>`,
      to: userData.email,
      subject: emailTemplate.subject,
      text: emailTemplate.text,
      html: emailTemplate.html,
    };
    logger.info('Mail options prepared', { to: userData.email, subject: emailTemplate.subject });

    // メール送信実行
    logger.info('Attempting to send email');
    const result = await transporter.sendMail(mailOptions);
    logger.info('Email send call completed', { messageId: result.messageId });

    logger.info('Registration email sent successfully', {
      userId,
      email: userData.email,
      messageId: result.messageId
    });

    // Firestoreに送信記録を保存（オプション）
    const db = getFirestore();
    await db.collection('users').doc(userId).update({
      emailSent: true,
      emailSentAt: new Date(),
      emailMessageId: result.messageId
    });

  } catch (error) {
    // エラーの詳細をコンソールに直接出力
    console.error('=== REGISTRATION EMAIL ERROR ===');
    console.error('Error name:', error.name);
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    console.error('Error object:', JSON.stringify(error, Object.getOwnPropertyNames(error)));
    console.error('================================');

    logger.error('Failed to send registration email', error, {
      userId: event.params.userId,
      errorName: error.name,
      errorMessage: error.message,
      errorStack: error.stack
    });

    // エラーをFirestoreに記録（デバッグ用）
    try {
      const db = getFirestore();
      await db.collection('users').doc(event.params.userId).update({
        emailError: error.message,
        emailErrorName: error.name,
        emailErrorStack: error.stack,
        emailErrorAt: new Date()
      });
    } catch (dbError) {
      console.error('Failed to save error to Firestore:', dbError);
      logger.error('Failed to save email error to Firestore', dbError);
    }
  }
});

module.exports = { sendRegistrationEmail };