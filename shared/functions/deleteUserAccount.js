const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore} = require('./src/utils/firebaseInit');
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
exports.deleteUserAccount = onCall(
  {region: 'asia-northeast1', memory: '256MiB', timeoutSeconds: 60, enforceAppCheck: true},
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = request.auth.uid;
  console.log(`deleteUserAccount: started for userId=${userId}`);

  const db = getFirestore();

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

  // 3. フレンドリストから自分のエントリーを削除（フレンドの一覧に残り続けないよう）
  try {
    const userRef = db.collection('users').doc(userId);

    // 承認済みフレンド: 各フレンドの friends/{userId} を削除
    const friendsSnap = await userRef.collection('friends').get();
    const friendCleanupOps = friendsSnap.docs.map((doc) =>
      db.collection('users').doc(doc.id).collection('friends').doc(userId).delete(),
    );

    // 送信済み申請: 相手の incomingRequests/{userId} を削除
    const outgoingSnap = await userRef.collection('outgoingRequests').get();
    const outgoingCleanupOps = outgoingSnap.docs.map((doc) =>
      db.collection('users').doc(doc.id).collection('incomingRequests').doc(userId).delete(),
    );

    // 受信済み申請: 相手の outgoingRequests/{userId} を削除
    const incomingSnap = await userRef.collection('incomingRequests').get();
    const incomingCleanupOps = incomingSnap.docs.map((doc) =>
      db.collection('users').doc(doc.id).collection('outgoingRequests').doc(userId).delete(),
    );

    await Promise.all([...friendCleanupOps, ...outgoingCleanupOps, ...incomingCleanupOps]);
    console.log(`deleteUserAccount: friend references cleaned up for userId=${userId} (friends=${friendsSnap.size}, outgoing=${outgoingSnap.size}, incoming=${incomingSnap.size})`);
  } catch (friendCleanupError) {
    // クリーンアップ失敗はログに記録するがアカウント削除は続行
    console.error(`deleteUserAccount: Failed to clean up friend references for userId=${userId}:`, friendCleanupError.message);
  }

  // 4. Firestore の全データを再帰削除（サブコレクションを含む）
  try {
    const userRef = db.collection('users').doc(userId);
    await db.recursiveDelete(userRef);
    console.log(`deleteUserAccount: Firestore data recursively deleted for userId=${userId}`);
  } catch (deleteError) {
    console.error(`deleteUserAccount: Failed to delete Firestore data for userId=${userId}:`, deleteError);
    throw new HttpsError('internal', `Failed to delete user data: ${deleteError.message}`);
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
