import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// アプリ内で表示するプライバシーポリシー。
///
/// **内容の正は `shared/docs/public/privacy-policy.md`**（GitHub Pagesで公開し、
/// App Store Connect にURLを登録しているもの）。この画面はその内容をアプリ内で
/// 読めるようにした写しなので、**片方だけを更新しないこと**。
/// 見出し番号・文言・最終更新日を常に一致させる。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: const [
          _PrivacySection(
            title: 'はじめに',
            content:
                'DARIAS（以下「本アプリ」）は、ユーザーの皆様のプライバシーを尊重し、個人情報の保護に努めています。本プライバシーポリシーは、本アプリがどのような情報を収集し、どのように使用・保護するかを説明するものです。',
          ),
          _PrivacySection(
            title: '1. 収集する情報',
            content: '【1.1 アカウント情報】\n'
                '• メールアドレス\n'
                '• ユーザーID\n'
                '• 登録日時\n\n'
                '【1.2 利用情報】\n'
                '• チャット履歴\n'
                '• BIG5性格診断の回答\n'
                '• カレンダーの予定情報\n'
                '• 日記データ\n'
                '• キャラクター設定\n\n'
                '【1.3 技術情報】\n'
                '• デバイス情報（機種、OSバージョン）\n'
                '• アプリ使用状況（クラッシュレポート等）\n'
                '• 広告ID（Google AdMob）',
          ),
          _PrivacySection(
            title: '1.4 利用状況の分析データ（Firebase Analytics）',
            content:
                '本アプリは、利用状況の分析およびサービス改善のためにFirebase Analytics（Google）を使用しています。\n\n'
                '収集する内容は次のとおりです：\n'
                '• 画面の表示（どの画面が表示されたか）\n'
                '• 機能の利用（新規登録、ログイン、チュートリアルの閲覧、チャットの送信、日記・自分会議・冒険などの機能の利用、課金画面の表示、購入手続きの開始・完了）\n'
                '• 利用状況の区分（チャットの解析進捗の区分、キャラクターの成長段階、元素、有料プランかどうか）\n'
                '• アプリの利用回数・利用時間などの統計情報\n'
                '• 端末ごとに自動発行される識別子\n\n'
                '収集しない情報：本アプリは、チャットの本文、日記の本文、自分会議で入力した悩みの内容、メモ・予定・タスクの内容、タグ名、フレンドに関する情報、氏名、メールアドレス、ユーザーIDをFirebase Analyticsに送信しません。入力内容の文字数も送信しません。',
          ),
          _PrivacySection(
            title: '2. 情報の使用目的',
            content: '収集した情報は以下の目的で使用されます：\n'
                '• アプリ機能の提供（AIチャット、性格診断、予定管理等）\n'
                '• ユーザー体験の向上\n'
                '• アプリの改善・不具合修正\n'
                '• 広告配信（無料版ユーザー向け）\n'
                '• サービスの分析・統計\n'
                '• 利用状況の分析およびサービス改善',
          ),
          _PrivacySection(
            title: '3. 情報の共有',
            content: '【3.1 第三者サービス】\n'
                '本アプリは以下の第三者サービスを使用しています：\n'
                '• Firebase（Google）: データ保存・認証\n'
                '• Firebase Analytics（Google）: 利用状況の分析およびサービス改善\n'
                '• Google AdMob: 広告配信\n'
                '• OpenAI API: AI応答生成\n\n'
                'これらのサービスは独自のプライバシーポリシーに従って運用されています。\n\n'
                '【3.2 情報開示】\n'
                '法的義務がある場合を除き、ユーザーの同意なく第三者に個人情報を提供することはありません。',
          ),
          _PrivacySection(
            title: '4. データの保存と保護',
            content: '• データはFirebase（Google Cloud）に暗号化されて保存されます\n'
                '• 業界標準のセキュリティ対策を実施しています\n'
                '• ユーザーはいつでもアカウント削除が可能です',
          ),
          _PrivacySection(
            title: '5. 広告について',
            content:
                '本アプリは無料版ユーザー向けにGoogle AdMobを使用して広告を表示します。AdMobはユーザーの興味に基づいた広告を配信するため、広告IDを使用する場合があります。\n\n'
                '広告のパーソナライゼーションをオプトアウトするには、デバイスの設定から変更できます。',
          ),
          _PrivacySection(
            title: '6. 子供のプライバシー',
            content:
                '本アプリは13歳未満の子供を対象としていません。13歳未満の子供から意図的に個人情報を収集することはありません。',
          ),
          _PrivacySection(
            title: '7. ユーザーの権利',
            content: 'ユーザーは以下の権利を有します：\n'
                '• 自分の個人情報へのアクセス\n'
                '• 個人情報の訂正・削除\n'
                '• データのエクスポート\n'
                '• アカウントの削除',
          ),
          _PrivacySection(
            title: '7.1 アカウント・データの削除方法',
            content: 'アプリ内から直接アカウントを削除できます：\n'
                '1. アプリを開き、設定画面に移動する\n'
                '2. 「アカウントを削除」をタップする\n'
                '3. 確認ダイアログで「削除する」を選択する\n\n'
                '削除が完了すると、以下のデータがすべて完全に消去され、復元できません：\n'
                '• チャット履歴・日記・メモ・スケジュール・TODOなどのコンテンツデータ\n'
                '• キャラクター設定・性格診断データ\n'
                '• アカウント情報（メールアドレス・ユーザーID）\n'
                '• サブスクリプション情報\n\n'
                '削除が完了しない場合や、アプリにアクセスできない場合は、以下までご連絡ください：\n'
                '• GitHub Issues: https://github.com/derad4444/Darias/issues\n'
                '• アプリ内: 設定 → お問い合わせ',
          ),
          _PrivacySection(
            title: '8. プライバシーポリシーの変更',
            content:
                '本プライバシーポリシーは予告なく変更される場合があります。重要な変更がある場合は、アプリ内またはメールで通知します。',
          ),
          _PrivacySection(
            title: '9. お問い合わせ',
            content: 'プライバシーに関するご質問やご要望は、以下までご連絡ください：\n'
                '• GitHub Issues: https://github.com/derad4444/Darias/issues\n'
                '• アプリ内: 設定 → お問い合わせ',
          ),
          _PrivacySection(
            title: '10. 準拠法',
            content: '本プライバシーポリシーは日本国の法律に準拠します。',
          ),
          SizedBox(height: 24),
          Text(
            '最終更新日：2026年8月19日',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String content;

  const _PrivacySection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
