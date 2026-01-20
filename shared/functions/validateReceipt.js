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
    subscription_status: subscriptionInfo.status,
    subscription_plan: subscriptionInfo.plan,
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
        subscription_status: 'expired',
        subscription_plan: 'free',
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