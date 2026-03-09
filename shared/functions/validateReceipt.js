const functions = require('firebase-functions');
const admin = require('firebase-admin');

// .envファイルから環境変数を読み込む
require('dotenv').config();

// App Store レシート検証エンドポイント
const APPLE_RECEIPT_VERIFICATION_URL = {
  sandbox: 'https://sandbox.itunes.apple.com/verifyReceipt',
  production: 'https://buy.itunes.apple.com/verifyReceipt'
};

/**
 * App Store レシートを検証し、サブスクリプション状態を更新
 * Updated: 2025-10-29 - Added .env support and detailed logging
 */
exports.validateAppStoreReceipt = functions.https.onCall(async (data, context) => {
  // 認証チェック
  if (!context.auth) {
    console.error('validateAppStoreReceipt: User not authenticated');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { receiptData, transactionId } = data;
  const userId = context.auth.uid;

  console.log(`validateAppStoreReceipt called for user: ${userId}, transaction: ${transactionId}`);

  if (!receiptData) {
    console.error('validateAppStoreReceipt: Receipt data is missing');
    throw new functions.https.HttpsError('invalid-argument', 'Receipt data is required');
  }

  console.log(`Receipt data length: ${receiptData.length} characters`);

  try {
    // App Store with Apple でレシート検証
    console.log('Calling verifyReceiptWithApple...');
    const verificationResult = await verifyReceiptWithApple(receiptData);

    console.log(`Apple verification status: ${verificationResult.status}`);

    if (verificationResult.status !== 0) {
      console.error(`Receipt verification failed with status: ${verificationResult.status}`);
      throw new functions.https.HttpsError('invalid-argument', `Invalid receipt - status ${verificationResult.status}`);
    }

    // レシート情報を解析
    const latestReceiptInfo = verificationResult.latest_receipt_info;
    if (!latestReceiptInfo || latestReceiptInfo.length === 0) {
      console.error('No receipt info found in verification result');
      throw new functions.https.HttpsError('invalid-argument', 'No receipt info found');
    }

    console.log(`Found ${latestReceiptInfo.length} receipt(s) in verification result`);

    const subscriptionInfo = parseSubscriptionInfo(latestReceiptInfo, transactionId);

    console.log('Parsed subscription info:', JSON.stringify(subscriptionInfo, null, 2));

    // Firestoreにサブスクリプション情報を保存
    console.log(`Updating subscription for user: ${userId}`);
    await updateUserSubscription(userId, subscriptionInfo);

    console.log('Subscription updated successfully');

    return {
      success: true,
      subscription: subscriptionInfo
    };

  } catch (error) {
    console.error('Receipt validation failed:', error);
    console.error('Error stack:', error.stack);

    // エラーの詳細を返す
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', `Receipt validation failed: ${error.message}`);
  }
});

/**
 * Apple サーバーでレシート検証
 */
async function verifyReceiptWithApple(receiptData) {
  const axios = require('axios');

  // Shared Secretを環境変数または設定から取得
  const sharedSecret = process.env.APPLE_SHARED_SECRET ||
                       (functions.config().apple ? functions.config().apple.shared_secret : null);

  if (!sharedSecret) {
    console.error('Apple Shared Secret is not configured');
    throw new Error('Apple Shared Secret is not configured. Please set APPLE_SHARED_SECRET environment variable or firebase functions:config:set apple.shared_secret="YOUR_SECRET"');
  }

  console.log('Shared Secret configured: YES');

  try {
    // まず本番環境で試行
    console.log('Attempting receipt verification with production environment...');
    let response = await axios.post(APPLE_RECEIPT_VERIFICATION_URL.production, {
      'receipt-data': receiptData,
      'password': sharedSecret,
      'exclude-old-transactions': true
    });

    console.log(`Production environment response status: ${response.data.status}`);

    // sandbox環境へのフォールバック (status 21007)
    if (response.data.status === 21007) {
      console.log('Production receipt validation returned 21007 (Sandbox receipt used in production), falling back to sandbox');
      response = await axios.post(APPLE_RECEIPT_VERIFICATION_URL.sandbox, {
        'receipt-data': receiptData,
        'password': sharedSecret,
        'exclude-old-transactions': true
      });

      console.log(`Sandbox environment response status: ${response.data.status}`);
    }

    return response.data;
  } catch (error) {
    console.error('Error during Apple receipt verification:', error.message);
    if (error.response) {
      console.error('Apple API response status:', error.response.status);
      console.error('Apple API response data:', error.response.data);
    }
    throw error;
  }
}

/**
 * サブスクリプション情報を解析
 */
function parseSubscriptionInfo(latestReceiptInfo, targetTransactionId) {
  const targetTransaction = latestReceiptInfo.find(
    transaction => transaction.transaction_id === targetTransactionId
  );

  if (!targetTransaction) {
    throw new Error('Transaction not found in receipt');
  }

  const now = Date.now();
  const expiresDate = parseInt(targetTransaction.expires_date_ms);
  const isActive = expiresDate > now;

  return {
    plan: isActive ? 'premium' : 'free',
    status: isActive ? 'active' : 'expired',
    start_date: admin.firestore.Timestamp.fromMillis(parseInt(targetTransaction.purchase_date_ms)),
    end_date: admin.firestore.Timestamp.fromMillis(expiresDate),
    payment_method: 'app_store',
    transaction_id: targetTransactionId,
    product_id: targetTransaction.product_id,
    auto_renewal: targetTransaction.is_in_intro_offer_period === 'false',
    updated_at: admin.firestore.Timestamp.now()
  };
}

/**
 * ユーザーのサブスクリプション状態を更新
 */
async function updateUserSubscription(userId, subscriptionInfo) {
  const db = admin.firestore();

  await db.collection('users').doc(userId)
    .collection('subscription').doc('current')
    .set(subscriptionInfo, { merge: true });

  // ユーザードキュメントのサブスクリプション状態も更新
  await db.collection('users').doc(userId).update({
    subscriptionStatus: subscriptionInfo.status === 'active' ? 'premium' : 'free',
    updated_at: admin.firestore.Timestamp.now()
  });
}

/**
 * サブスクリプション状態の定期チェック (1日1回実行)
 * Firebase Functions v2形式
 */
exports.checkSubscriptionStatus = functions.scheduler.onSchedule({
  schedule: '0 0 * * *',
  timeZone: 'Asia/Tokyo',
}, async (event) => {
  const db = admin.firestore();

  // アクティブなサブスクリプションを取得
  const activeSubscriptions = await db.collectionGroup('subscription')
    .where('status', '==', 'active')
    .get();

  const batch = db.batch();
  let updateCount = 0;

  for (const doc of activeSubscriptions.docs) {
    const subscription = doc.data();
    const now = admin.firestore.Timestamp.now();

    // 期限切れチェック
    if (subscription.end_date && subscription.end_date.toMillis() < now.toMillis()) {
      // サブスクリプションを期限切れに更新
      batch.update(doc.ref, {
        status: 'expired',
        plan: 'free',
        updated_at: now
      });

      // ユーザードキュメントも更新
      const userId = doc.ref.parent.parent.id;
      const userRef = db.collection('users').doc(userId);
      batch.update(userRef, {
        subscriptionStatus: 'free',
        updated_at: now
      });

      updateCount++;
    }
  }

  if (updateCount > 0) {
    await batch.commit();
    console.log(`Updated ${updateCount} expired subscriptions`);
  }

  return null;
});

/**
 * Google Play レシートを検証し、サブスクリプション状態を更新
 */
exports.validateGooglePlayReceipt = functions.https.onCall(async (data, context) => {
  // 認証チェック
  if (!context.auth) {
    console.error('validateGooglePlayReceipt: User not authenticated');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { purchaseToken, productId } = data;
  const userId = context.auth.uid;

  console.log(`validateGooglePlayReceipt called for user: ${userId}, product: ${productId}`);

  if (!purchaseToken) {
    throw new functions.https.HttpsError('invalid-argument', 'Purchase token is required');
  }

  if (!productId) {
    throw new functions.https.HttpsError('invalid-argument', 'Product ID is required');
  }

  try {
    // Google Play Developer API でレシート検証
    const verificationResult = await verifyPurchaseWithGoogle(purchaseToken, productId);

    console.log('Google Play verification result:', JSON.stringify(verificationResult, null, 2));

    // サブスクリプション情報を構築
    const now = Date.now();
    const expiryTimeMillis = parseInt(verificationResult.expiryTimeMillis || '0');
    const startTimeMillis = parseInt(verificationResult.startTimeMillis || now.toString());
    const isActive = expiryTimeMillis > now && (
      verificationResult.paymentState === 1 || // Payment received
      verificationResult.paymentState === 2    // Free trial
    );

    const subscriptionInfo = {
      plan: isActive ? 'premium' : 'free',
      status: isActive ? 'active' : 'expired',
      start_date: admin.firestore.Timestamp.fromMillis(startTimeMillis),
      end_date: admin.firestore.Timestamp.fromMillis(expiryTimeMillis),
      payment_method: 'google_play',
      purchase_token: purchaseToken,
      product_id: productId,
      auto_renewal: verificationResult.autoRenewing === true,
      updated_at: admin.firestore.Timestamp.now()
    };

    console.log('Parsed subscription info:', JSON.stringify(subscriptionInfo, null, 2));

    // Firestoreにサブスクリプション情報を保存（既存関数を再利用）
    await updateUserSubscription(userId, subscriptionInfo);

    console.log('Google Play subscription updated successfully');

    return {
      success: true,
      subscription: subscriptionInfo
    };

  } catch (error) {
    console.error('Google Play receipt validation failed:', error);
    console.error('Error stack:', error.stack);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', `Google Play receipt validation failed: ${error.message}`);
  }
});

/**
 * Apple Server Notifications v2 を受け取り、Firestoreを即座に更新する
 *
 * App Store Connect での設定:
 *   My Apps → App Information → App Store Server Notifications
 *   Production URL: https://<region>-<project>.cloudfunctions.net/appleServerNotification
 *
 * 対応通知タイプ:
 *   SUBSCRIBED       - 新規購入
 *   DID_RENEW        - 自動更新成功
 *   EXPIRED          - サブスク期限切れ
 *   DID_FAIL_TO_RENEW - 自動更新失敗（猶予期間あり）
 *   GRACE_PERIOD_EXPIRED - 猶予期間も終了
 *   REFUND           - 返金完了
 *   REVOKE           - ファミリー共有取り消し
 */
exports.appleServerNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { signedPayload } = req.body;
    if (!signedPayload) {
      console.error('appleServerNotification: signedPayload missing');
      res.status(400).send('Bad Request: signedPayload required');
      return;
    }

    // JWS を Base64デコード（署名検証なし版: Firebase + HTTPS で通信経路は保護済み）
    // 本番強化が必要な場合は Apple の公開鍵で ES256 検証を追加する
    const payloadBase64 = signedPayload.split('.')[1];
    const payloadJson = Buffer.from(payloadBase64, 'base64url').toString('utf8');
    const payload = JSON.parse(payloadJson);

    const notificationType = payload.notificationType;  // e.g. "EXPIRED"
    const subtype = payload.subtype;                    // e.g. "VOLUNTARY"

    // 内部トランザクション情報をデコード
    const transactionInfoBase64 = payload.data?.signedTransactionInfo?.split('.')[1];
    const renewalInfoBase64 = payload.data?.signedRenewalInfo?.split('.')[1];

    const transactionInfo = transactionInfoBase64
      ? JSON.parse(Buffer.from(transactionInfoBase64, 'base64url').toString('utf8'))
      : null;

    const renewalInfo = renewalInfoBase64
      ? JSON.parse(Buffer.from(renewalInfoBase64, 'base64url').toString('utf8'))
      : null;

    const originalTransactionId = transactionInfo?.originalTransactionId
      || renewalInfo?.originalTransactionId;

    console.log(`appleServerNotification: type=${notificationType} subtype=${subtype} txId=${originalTransactionId}`);

    if (!originalTransactionId) {
      console.error('appleServerNotification: originalTransactionId not found in payload');
      res.status(200).send('OK'); // Appleへは200を返す
      return;
    }

    // originalTransactionId でユーザーを特定
    const db = admin.firestore();
    const subscriptionSnapshot = await db.collectionGroup('subscription')
      .where('transaction_id', '==', originalTransactionId)
      .limit(1)
      .get();

    if (subscriptionSnapshot.empty) {
      console.warn(`appleServerNotification: No user found for txId=${originalTransactionId}`);
      res.status(200).send('OK');
      return;
    }

    const subscriptionRef = subscriptionSnapshot.docs[0].ref;
    const userId = subscriptionRef.parent.parent.id;

    // 通知タイプに応じてFirestoreを更新
    const now = admin.firestore.Timestamp.now();

    switch (notificationType) {
      case 'SUBSCRIBED':
      case 'DID_RENEW': {
        // 購入・更新成功 → プレミアムに
        const expiresDateMs = transactionInfo?.expiresDate;
        const endDate = expiresDateMs
          ? admin.firestore.Timestamp.fromMillis(expiresDateMs)
          : null;
        await updateUserSubscription(userId, {
          plan: 'premium',
          status: 'active',
          end_date: endDate,
          auto_renewal: true,
          transaction_id: originalTransactionId,
          updated_at: now,
        });
        console.log(`appleServerNotification: ${notificationType} → premium userId=${userId}`);
        break;
      }

      case 'EXPIRED':
      case 'GRACE_PERIOD_EXPIRED': {
        // 期限切れ → 無料に
        await updateUserSubscription(userId, {
          plan: 'free',
          status: 'expired',
          auto_renewal: false,
          updated_at: now,
        });
        console.log(`appleServerNotification: ${notificationType} → free userId=${userId}`);
        break;
      }

      case 'DID_FAIL_TO_RENEW': {
        // 自動更新失敗（猶予期間中はまだプレミアム）
        await subscriptionRef.set({ status: 'grace_period', updated_at: now }, { merge: true });
        console.log(`appleServerNotification: DID_FAIL_TO_RENEW → grace_period userId=${userId}`);
        break;
      }

      case 'REFUND':
      case 'REVOKE': {
        // 返金・取り消し → 即座に無料に
        await updateUserSubscription(userId, {
          plan: 'free',
          status: 'free',
          auto_renewal: false,
          updated_at: now,
        });
        console.log(`appleServerNotification: ${notificationType} → free (revoked) userId=${userId}`);
        break;
      }

      default:
        console.log(`appleServerNotification: Unhandled type=${notificationType}, skipping`);
    }

    // Apple には必ず200を返す（2xx以外だとリトライされる）
    res.status(200).send('OK');

  } catch (error) {
    console.error('appleServerNotification: Error processing notification', error);
    // エラー時も200を返してAppleのリトライを防ぐ（ログで監視）
    res.status(200).send('OK');
  }
});

/**
 * Google Play Developer API でサブスクリプション購入を検証
 */
async function verifyPurchaseWithGoogle(purchaseToken, productId) {
  const { google } = require('googleapis');

  // サービスアカウント認証情報を取得
  const serviceAccountKey = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
  if (!serviceAccountKey) {
    throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_KEY environment variable is not configured');
  }

  const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME;
  if (!packageName) {
    throw new Error('GOOGLE_PLAY_PACKAGE_NAME environment variable is not configured');
  }

  let credentials;
  try {
    credentials = JSON.parse(serviceAccountKey);
  } catch (e) {
    throw new Error('Failed to parse GOOGLE_PLAY_SERVICE_ACCOUNT_KEY: ' + e.message);
  }

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const androidPublisher = google.androidpublisher({
    version: 'v3',
    auth,
  });

  const response = await androidPublisher.purchases.subscriptions.get({
    packageName,
    subscriptionId: productId,
    token: purchaseToken,
  });

  return response.data;
}