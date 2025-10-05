const functions = require('firebase-functions');
const admin = require('firebase-admin');

// App Store レシート検証エンドポイント
const APPLE_RECEIPT_VERIFICATION_URL = {
  sandbox: 'https://sandbox.itunes.apple.com/verifyReceipt',
  production: 'https://buy.itunes.apple.com/verifyReceipt'
};

/**
 * App Store レシートを検証し、サブスクリプション状態を更新
 */
exports.validateAppStoreReceipt = functions.https.onCall(async (data, context) => {
  // 認証チェック
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { receiptData, transactionId } = data;
  const userId = context.auth.uid;

  if (!receiptData) {
    throw new functions.https.HttpsError('invalid-argument', 'Receipt data is required');
  }

  try {
    // App Store with Apple でレシート検証
    const verificationResult = await verifyReceiptWithApple(receiptData);

    if (verificationResult.status !== 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid receipt');
    }

    // レシート情報を解析
    const latestReceiptInfo = verificationResult.latest_receipt_info;
    const subscriptionInfo = parseSubscriptionInfo(latestReceiptInfo, transactionId);

    // Firestoreにサブスクリプション情報を保存
    await updateUserSubscription(userId, subscriptionInfo);

    return {
      success: true,
      subscription: subscriptionInfo
    };

  } catch (error) {
    console.error('Receipt validation failed:', error);
    throw new functions.https.HttpsError('internal', 'Receipt validation failed');
  }
});

/**
 * Apple サーバーでレシート検証
 */
async function verifyReceiptWithApple(receiptData) {
  const axios = require('axios');

  // まず本番環境で試行
  let response = await axios.post(APPLE_RECEIPT_VERIFICATION_URL.production, {
    'receipt-data': receiptData,
    'password': functions.config().apple.shared_secret,
    'exclude-old-transactions': true
  });

  // sandbox環境へのフォールバック (status 21007)
  if (response.data.status === 21007) {
    response = await axios.post(APPLE_RECEIPT_VERIFICATION_URL.sandbox, {
      'receipt-data': receiptData,
      'password': functions.config().apple.shared_secret,
      'exclude-old-transactions': true
    });
  }

  return response.data;
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
 */
exports.checkSubscriptionStatus = functions.pubsub.schedule('0 0 * * *')
  .timeZone('Asia/Tokyo')
  .onRun(async (context) => {
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