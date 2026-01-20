# プレミアムプラン仕様と改善内容

## 📋 現在の仕様まとめ

### 基本仕様
- **商品ID**: `com.character.premium.monthly`
- **料金**: 月額課金（App Store経由）
- **管理単位**: Firebaseアカウント（userId）単位
- **端末間同期**: ✅ 対応済み（Firestoreで管理）

### データ保存場所
```
users/{userId}/subscription/current
```

### サブスクリプションデータ構造
```json
{
  "plan": "premium" | "free",
  "status": "active" | "free",
  "payment_method": "app_store",
  "auto_renewal": true | false,
  "end_date": Timestamp | null,
  "updated_at": Timestamp
}
```

### end_dateの設定
- **購入時**: StoreKitの`expirationDate`から取得（例: 1ヶ月後）
- **自動更新時**: 新しい期限に更新（例: さらに1ヶ月後）
- **キャンセル時**: そのまま（期限まで利用可能）
- **無料プラン**: `null`

### キャンセル時の動作
1. ユーザーがApp Storeでキャンセル
2. `end_date`はそのまま（変更なし）
3. 期限まではプレミアムとして利用可能 ✅
4. 期限到達後、自動的に無料プランに

---

## 🔧 実施した改善内容

### 改善1: 返金（revocation）の適切な処理

#### 問題
返金されたトランザクションがあっても、Firestoreの保護機能により、プレミアムが継続していた。

#### 解決策
```swift
// PurchaseManager.swift

// ✅ revocationDateを検知
private func checkPurchasedProducts() async {
    var hasRevocation = false

    for await verification in StoreKit.Transaction.currentEntitlements {
        let transaction = try checkVerified(verification)

        if transaction.revocationDate == nil {
            // 通常のアクティブな購入
            purchasedIDs.insert(transaction.productID)
        } else {
            // 返金された購入
            hasRevocation = true
        }
    }

    await updateSubscriptionStatus(hasRevocation: hasRevocation)
}

// ✅ 返金がある場合は保護機能をスキップ
private func updateSubscriptionStatus(hasRevocation: Bool = false) async {
    if !isPremium && !hasRevocation, let data = firestoreData {
        // 保護機能: StoreKitが空でもFirestoreのプレミアムを保持
    } else if hasRevocation {
        // 返金がある場合は強制的に無料に更新
        print("🚫 Revocation detected - forcing update to free")
    }
}
```

#### 効果
- 返金後、即座にプレミアムが無効化される
- 不正利用を防止

---

### 改善2: アプリがフォアグラウンドに戻った時の自動チェック

#### 問題
- アプリを長時間起動していないと、キャンセルや期限切れを検知できない
- StoreKitの同期が遅れることがある

#### 解決策
```swift
// PurchaseManager.swift

private func setupAppStateObserver() {
    // アプリがフォアグラウンドに戻るたびにチェック
    appStateObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.willEnterForegroundNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.checkPurchasedProducts()
            await self?.performDailyReceiptValidation()
        }
    }
}
```

#### 効果
- アプリを開くたびに最新のサブスクリプション状態をチェック
- StoreKitの同期遅延を軽減
- バックグラウンドで変更があっても即座に反映

---

### 改善3: 1日1回の定期レシート検証

#### 問題
- 購入時のみレシート検証を実行
- キャンセル、自動更新失敗、返金を定期的に検知できない

#### 解決策
```swift
// PurchaseManager.swift

@AppStorage("lastReceiptValidationDate")
private var lastReceiptValidationDate: Double = 0

private func performDailyReceiptValidation() async {
    let now = Date().timeIntervalSince1970
    let oneDayInSeconds: TimeInterval = 24 * 60 * 60

    // 24時間以上経過している場合のみ実行
    guard now - lastReceiptValidationDate > oneDayInSeconds else {
        return
    }

    // アクティブなサブスクリプションのレシートを検証
    for await verification in StoreKit.Transaction.currentEntitlements {
        let transaction = try checkVerified(verification)
        if transaction.productID == "com.character.premium.monthly" {
            await validateReceiptWithFirebase(transaction)
            lastReceiptValidationDate = now
            return
        }
    }
}
```

#### 効果
- 1日1回、Firebase Functionsでレシート検証
- Appleサーバーの最新状態を確認
- キャンセル、更新失敗、返金を定期的に検知

---

## 🎯 改善後の動作フロー

### ケース1: 通常の購入・利用
```
1. ユーザーが購入
   ↓
2. StoreKit: expirationDate = 1ヶ月後
   ↓
3. Firestore: end_date = 1ヶ月後
   ↓
4. プレミアム機能が利用可能 ✅
```

### ケース2: キャンセル
```
1. ユーザーがキャンセル
   ↓
2. StoreKit: expirationDate = そのまま（期限まで有効）
   ↓
3. Firestore: end_date = そのまま
   ↓
4. 期限までプレミアム利用可能 ✅
   ↓
5. 期限到達
   ↓
6. アプリ起動時に自動的に無料に ✅
```

### ケース3: 返金
```
1. Appleが返金を承認
   ↓
2. StoreKit: revocationDate が設定される
   ↓
3. アプリをフォアグラウンドに
   ↓
4. checkPurchasedProducts() 実行
   ↓
5. hasRevocation = true を検知
   ↓
6. 保護機能をスキップ
   ↓
7. Firestoreを強制的に無料に更新 ✅
```

### ケース4: 自動更新失敗
```
1. 自動更新の日
   ↓
2. 支払い失敗（クレカ期限切れなど）
   ↓
3. StoreKit: currentEntitlements が空に
   ↓
4. アプリをフォアグラウンドに
   ↓
5. checkPurchasedProducts() 実行
   ↓
6. purchasedIDs が空
   ↓
7. Firestore: end_date チェック → 期限切れ
   ↓
8. 無料プランに更新 ✅
```

### ケース5: 新しい端末でログイン
```
1. 端末Aで購入済み
   ↓
2. 端末Bで初回ログイン
   ↓
3. Firestoreから既存のプレミアムデータを取得 ✅
   ↓
4. StoreKitは同期中...
   ↓
5. 保護機能が働く → プレミアムのまま ✅
   ↓
6. バックグラウンドでStoreKit同期完了
   ↓
7. 次回フォアグラウンド時に再チェック ✅
```

---

## ✅ テスト項目

実機で以下をテストすることを推奨：

### 1. 基本機能
- [ ] プレミアム購入が成功する
- [ ] 購入後、すぐにプレミアム機能が使える
- [ ] 別端末で同じアカウントでログインしてもプレミアム

### 2. キャンセル
- [ ] App Storeでキャンセル
- [ ] キャンセル後も期限まで利用可能
- [ ] 期限到達後、無料プランに戻る

### 3. 返金（サンドボックス環境）
- [ ] 返金後、即座に無料プランに戻る
- [ ] アプリを再起動しても無料プランのまま

### 4. 自動更新
- [ ] 自動更新が成功すると期限が延長される
- [ ] 自動更新が失敗すると無料プランに戻る

### 5. 定期検証
- [ ] 1日1回のレシート検証が実行される
- [ ] フォアグラウンドに戻るたびにチェックされる

---

## 🔒 セキュリティ考慮事項

### 現在の保護機能
1. **StoreKit検証**: Appleの署名付きトランザクションのみ受け入れ
2. **Firebase Functions**: サーバー側でレシート検証
3. **Firestore Rules**: ユーザー自身のデータのみアクセス可能
4. **定期検証**: 1日1回、サーバー側で再検証

### 潜在的なリスクと対策
| リスク | 現在の対策 | 追加推奨対策 |
|--------|------------|--------------|
| レシートの偽造 | StoreKitの署名検証 | ✅ 実装済み |
| アカウント共有 | 特に制限なし | 将来的に検討 |
| オフライン時の不正利用 | Firestore保護機能 | ✅ 実装済み |
| 返金詐欺 | revocationDate検知 | ✅ 今回追加 |

---

## 📝 今後の検討事項

### 優先度: 高
- [ ] Apple Server Notificationsの実装（リアルタイム更新）
- [ ] 管理画面でのサブスクリプション状態の確認機能

### 優先度: 中
- [ ] サブスクリプション解析（チャーン率、LTV計算）
- [ ] プッシュ通知（期限切れ前のリマインダー）

### 優先度: 低
- [ ] 家族共有への対応
- [ ] 複数デバイスでの同時利用制限

---

## 📚 参考資料

- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
