# アカウント登録時メール送信機能 セットアップガイド

## 概要
ユーザーがDARIASアプリにアカウント登録した際に、自動的に登録完了メールを送信する機能です。

## 機能の詳細

### 送信されるメール内容
- **件名**: 【DARIAS】アカウント登録完了のお知らせ
- **内容**:
  - ユーザー名での個別挨拶
  - 登録情報（ユーザーID、名前、登録日時）
  - アプリの主な機能紹介（AI予定管理、AI性格診断等）
  - 重要事項と注意事項
  - サポート情報

### トリガー条件
- Firestoreの `users` コレクションに新しいドキュメントが作成されたとき
- ユーザーデータに `email` と `name` フィールドが含まれている場合のみ

## セットアップ手順

### 1. Gmailアプリパスワードの設定

1. **Googleアカウントの2段階認証を有効化**
   - [Google アカウント設定](https://myaccount.google.com/) にアクセス
   - 「セキュリティ」→「2段階認証プロセス」を有効化

2. **アプリパスワードの生成**
   - [アプリパスワード設定画面](https://myaccount.google.com/apppasswords) にアクセス
   - 「アプリを選択」で「メール」を選択
   - 「デバイスを選択」で「その他（カスタム名）」を選択
   - 「DARIAS App」などの名前を入力
   - 生成された16文字のパスワードをメモ

### 2. Firebase Secretsの設定

```bash
# Firebase CLIでsecretsを設定
firebase functions:secrets:set GMAIL_USER
# プロンプトが表示されたら、送信用のGmailアドレスを入力

firebase functions:secrets:set GMAIL_APP_PASSWORD
# プロンプトが表示されたら、上記で生成したアプリパスワードを入力
```

### 3. デプロイ

```bash
# 関数をデプロイ
firebase deploy --only functions:sendRegistrationEmail
```

## 使用方法

### 自動実行
アプリでユーザー登録が行われ、Firestoreの `users` コレクションにドキュメントが作成されると自動的にメールが送信されます。

### 必要なユーザーデータ形式
```javascript
// users/{userId} ドキュメントの必須フィールド
{
  email: "user@example.com",        // 送信先メールアドレス
  name: "田中太郎",                   // ユーザー名
  createdAt: Timestamp,            // 登録日時（オプション）
  // その他のフィールド...
}
```

## 動作確認

### ログの確認
```bash
# Firebase Functionsのログを確認
firebase functions:log --only sendRegistrationEmail
```

### 送信状況の確認
メール送信後、該当ユーザードキュメントに以下のフィールドが追加されます：
```javascript
{
  emailSent: true,                 // 送信成功フラグ
  emailSentAt: Timestamp,          // 送信日時
  emailMessageId: "message-id",    // メッセージID
  // エラーの場合
  emailError: "error message",     // エラーメッセージ
  emailErrorAt: Timestamp          // エラー発生日時
}
```

## トラブルシューティング

### よくある問題

1. **メールが送信されない**
   - Firebase Secretsが正しく設定されているか確認
   - Gmailアプリパスワードが有効か確認
   - ユーザーデータに `email` と `name` が含まれているか確認

2. **「認証エラー」が発生する**
   - Googleアカウントの2段階認証が有効か確認
   - アプリパスワードが正しく設定されているか確認

3. **関数がトリガーされない**
   - Firestoreのコレクション名が `users` になっているか確認
   - 関数が正しくデプロイされているか確認

### ログでの確認方法
```bash
# エラーログの確認
firebase functions:log --only sendRegistrationEmail --lines 50

# 特定の期間のログ確認
firebase functions:log --only sendRegistrationEmail --since 2025-01-01
```

## セキュリティ考慮事項

- Gmailアプリパスワードは絶対に公開しない
- Firebase Secretsを使用してパスワードを安全に管理
- 送信先メールアドレスの検証を行う
- 送信頻度の制限（同一ユーザーへの重複送信防止）

## カスタマイズ

### メールテンプレートの変更
`src/functions/sendRegistrationEmail.js` の `createEmailTemplate` 関数を編集してください。

### 送信条件の変更
関数内の条件分岐を修正することで、送信条件をカスタマイズできます。

### 他のメールサービスの使用
Gmail以外のSMTPサービスを使用する場合は、`createTransporter` 関数の設定を変更してください。