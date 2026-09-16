import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// アプリ内で表示する利用規約。
///
/// **内容の正は `shared/docs/public/terms-of-use.md`**（GitHub Pagesで公開し、
/// App Store Connect にURLを登録しているもの）。この画面はその内容をアプリ内で
/// 読めるようにした写しなので、**片方だけを更新しないこと**。
/// 見出し番号・文言・最終更新日を常に一致させる。
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: const [
          _TermsSection(
            title: '1. はじめに',
            content:
                '本利用規約（以下「本規約」）は、DARIAS（以下「本アプリ」）の利用条件を定めるものです。本アプリをダウンロード、インストール、または使用することにより、お客様は本規約に同意したものとみなされます。',
          ),
          _TermsSection(
            title: '2. サービス内容',
            content: '本アプリは、AI技術を活用したキャラクターチャット、性格診断、日記などの機能を提供します。\n\n'
                '【2.1 提供機能】\n'
                '• AIキャラクターとのチャット機能\n'
                '• BIG5性格診断\n'
                '• 日記機能\n'
                '• 音声生成機能（プレミアムプラン）\n\n'
                '【2.2 サービスの変更・停止】\n'
                '当社は、事前の通知なくサービスの内容を変更、または一時的に停止する場合があります。',
          ),
          _TermsSection(
            title: '3. アカウント',
            content: '【3.1 アカウント登録】\n'
                '本アプリの一部機能を利用するには、アカウント登録が必要です。登録情報は正確かつ最新のものを提供してください。\n\n'
                '【3.2 アカウントの管理責任】\n'
                'お客様は、自身のアカウント情報およびパスワードを適切に管理する責任を負います。\n\n'
                '【3.3 アカウントの停止・削除】\n'
                '以下の場合、当社はアカウントを停止または削除することがあります：\n'
                '• 本規約に違反した場合\n'
                '• 不正利用が確認された場合\n'
                '• 長期間利用がない場合',
          ),
          _TermsSection(
            title: '4. サブスクリプション（自動更新購読）',
            content: '【4.1 プレミアムプラン】\n'
                '本アプリは、月額サブスクリプション「プレミアムプラン」を提供しています。\n\n'
                'プレミアムプランの特典：\n'
                '• 広告完全非表示\n'
                '• 最新AIモデル (GPT-4o-2024-11-20) の利用\n'
                '• 無制限チャット履歴\n'
                '• より高度な性格分析\n'
                '• 音声生成機能\n\n'
                '【4.2 価格と期間】\n'
                '• 月額料金: ¥980\n'
                '• 購読期間: 1ヶ月間\n'
                '• 自動更新: 期間終了の24時間前までに解約しない限り、自動的に更新されます\n\n'
                '【4.3 支払い】\n'
                '• 購入確定時にApple IDアカウントに課金されます\n'
                '• サブスクリプションは自動更新されます\n'
                '• 自動更新は、現在の期間が終了する少なくとも24時間前までにオフにすることができます\n\n'
                '【4.4 解約方法】\n'
                'iPhone の「設定」→「Apple ID」→「サブスクリプション」から、いつでも解約できます。\n\n'
                '【4.5 返金ポリシー】\n'
                '原則として返金は行いません。ただし、App Storeの返金ポリシーに従い、Apple Inc.を通じて返金をリクエストすることができます。',
          ),
          _TermsSection(
            title: '5. 禁止事項',
            content: 'お客様は、以下の行為を行ってはなりません：\n'
                '1. 法令または公序良俗に違反する行為\n'
                '2. 犯罪行為に関連する行為\n'
                '3. 本アプリのサーバーやネットワークに過度な負荷をかける行為\n'
                '4. 本アプリの運営を妨害する行為\n'
                '5. 他のユーザーに関する個人情報を収集する行為\n'
                '6. 他のユーザーになりすます行為\n'
                '7. 本アプリのリバースエンジニアリング、逆コンパイル、逆アセンブル\n'
                '8. 本アプリを商業目的で利用する行為\n'
                '9. その他、当社が不適切と判断する行為',
          ),
          _TermsSection(
            title: '6. 知的財産権',
            content: '【6.1 著作権】\n'
                '本アプリおよび本アプリ上のコンテンツに関する知的財産権は、当社または正当な権利者に帰属します。\n\n'
                '【6.2 ユーザーコンテンツ】\n'
                'お客様が本アプリに投稿したコンテンツ（チャット内容、日記等）の著作権は、お客様に帰属します。ただし、サービス提供のために必要な範囲で、当社がこれを使用することを許諾するものとします。',
          ),
          _TermsSection(
            title: '7. 免責事項',
            content: '【7.1 サービスの提供】\n'
                '本アプリは「現状有姿」で提供され、当社は本アプリの完全性、正確性、有用性について保証しません。\n\n'
                '【7.2 損害賠償の制限】\n'
                '当社は、本アプリの利用に起因してお客様に生じた損害について、当社に故意または重過失がある場合を除き、一切の責任を負いません。\n\n'
                '【7.3 第三者サービス】\n'
                '本アプリは、OpenAI API、Google AdMob、Firebase等の第三者サービスを利用しています。これらのサービスの提供中断や変更により生じた損害について、当社は責任を負いません。',
          ),
          _TermsSection(
            title: '8. AI生成コンテンツに関する注意事項',
            content: '【8.1 AI応答の性質】\n'
                '本アプリのAI機能は、OpenAI APIを使用しています。AI生成コンテンツは参考情報として提供されるものであり、その正確性や適切性を保証するものではありません。\n\n'
                '【8.2 利用者の責任】\n'
                'AI生成コンテンツに基づいて行動する場合、お客様ご自身の責任と判断で行ってください。',
          ),
          _TermsSection(
            title: '9. プライバシー',
            content:
                'お客様の個人情報の取り扱いについては、設定画面の「プライバシーポリシー」をご確認ください。',
          ),
          _TermsSection(
            title: '10. 規約の変更',
            content:
                '当社は、必要に応じて本規約を変更することがあります。変更後の規約は、本アプリ上または当社ウェブサイトに掲載した時点で効力を生じます。',
          ),
          _TermsSection(
            title: '11. 分離可能性',
            content: '本規約のいずれかの条項が無効または執行不能と判断された場合でも、その他の条項は引き続き有効です。',
          ),
          _TermsSection(
            title: '12. 準拠法および管轄裁判所',
            content: '【12.1 準拠法】\n'
                '本規約は日本国の法律に準拠します。\n\n'
                '【12.2 管轄裁判所】\n'
                '本アプリに関する一切の紛争については、東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
          ),
          _TermsSection(
            title: '13. お問い合わせ',
            content: '本規約に関するご質問は、以下までご連絡ください：\n'
                '• サポートページ: https://derad4444.github.io/Darias/support\n'
                '• GitHub Issues: https://github.com/derad4444/Darias/issues\n'
                '• アプリ内: 設定 → お問い合わせ',
          ),
          SizedBox(height: 24),
          Text(
            '発行者：DARIAS 開発チーム',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          SizedBox(height: 4),
          Text(
            '最終更新日：2026年5月10日',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({required this.title, required this.content});

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
