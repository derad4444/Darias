const functions = require('firebase-functions');
const admin = require('firebase-admin');
require('dotenv').config();

/**
 * アカウント削除処理
 *
 * Flutterから呼び出し、以下を順番に実行:
 *   1. サブスクリプション情報を取得してログ記録
 *   2. Google Play の場合: 自動更新をキャンセル
 *   3. Firestore の全サブコレクションを再帰削除
 *
 * App Store のサブスクリプションはサーバー側でキャンセル不可。
 * ユーザーは設定アプリから手動キャンセルが必要。
 *
 * 呼び出し側(Flutter)はこの関数が成功してから Firebase Auth を削除すること。
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  console.log(`deleteUserAccount: started for userId=${userId}`);

  const db = admin.firestore();

  // 1. サブスクリプション情報を取得
  let paymentMethod = null;
  let subscriptionStatus = null;
  try {
    const subscriptionDoc = await db
      .collection('users').doc(userId)
      .collection('subscription').doc('current')
      .get();

    if (subscriptionDoc.exists) {
      const subscription = subscriptionDoc.data();
      paymentMethod = subscription.payment_method;
      subscriptionStatus = subscription.status;
      console.log(`deleteUserAccount: subscription found payment_method=${paymentMethod} status=${subscriptionStatus}`);

      // 2. Google Play のアクティブなサブスクリプションをキャンセル
      if (paymentMethod === 'google_play' && subscriptionStatus === 'active') {
        const purchaseToken = subscription.purchase_token;
        const productId = subscription.product_id;
        if (purchaseToken && productId) {
          try {
            await cancelGooglePlaySubscription(purchaseToken, productId);
            console.log(`deleteUserAccount: Google Play subscription cancelled userId=${userId}`);
          } catch (cancelError) {
            // キャンセル失敗はログに記録するが、アカウント削除は続行する
            console.error(`deleteUserAccount: Failed to cancel Google Play subscription userId=${userId}:`, cancelError.message);
          }
        }
      }

      // App Store はサーバー側でキャンセル不可（ユーザーが手動キャンセル必要）
      if (paymentMethod === 'app_store' && subscriptionStatus === 'active') {
        console.warn(`deleteUserAccount: App Store subscription must be manually cancelled by user userId=${userId}`);
      }
    } else {
      console.log(`deleteUserAccount: no subscription document found for userId=${userId}`);
    }
  } catch (subscriptionError) {
    // サブスクリプション処理のエラーはログに記録して削除を続行
    console.error(`deleteUserAccount: Error processing subscription for userId=${userId}:`, subscriptionError.message);
  }

  // 3. Firestore の全データを再帰削除（サブコレクションを含む）
  try {
    const userRef = db.collection('users').doc(userId);
    await db.recursiveDelete(userRef);
    console.log(`deleteUserAccount: Firestore data recursively deleted for userId=${userId}`);
  } catch (deleteError) {
    console.error(`deleteUserAccount: Failed to delete Firestore data for userId=${userId}:`, deleteError);
    throw new functions.https.HttpsError('internal', `Failed to delete user data: ${deleteError.message}`);
  }

  console.log(`deleteUserAccount: completed successfully for userId=${userId}`);

  return {
    success: true,
    // App Store の場合はクライアント側で手動キャンセルの案内を出すためのフラグ
    requiresManualSubscriptionCancel: paymentMethod === 'app_store' && subscriptionStatus === 'active',
  };
});

/**
 * Google Play Developer API でサブスクリプションをキャンセル（自動更新停止）
 * キャンセル後も現在の請求期間の終わりまではアクティブのまま。
 */
async function cancelGooglePlaySubscription(purchaseToken, productId) {
  const { google } = require('googleapis');

  const serviceAccountKey = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
  if (!serviceAccountKey) {
    throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_KEY not configured');
  }

  const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME;
  if (!packageName) {
    throw new Error('GOOGLE_PLAY_PACKAGE_NAME not configured');
  }

  const credentials = JSON.parse(serviceAccountKey);
  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const androidPublisher = google.androidpublisher({ version: 'v3', auth });

  await androidPublisher.purchases.subscriptions.cancel({
    packageName,
    subscriptionId: productId,
    token: purchaseToken,
  });
}
