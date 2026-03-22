import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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
            title: '第1条（適用）',
            content: '本利用規約は、当社が提供するDARIASアプリ（以下「本サービス」）の利用条件を定めるものです。',
          ),
          _TermsSection(
            title: '第2条（利用登録）',
            content: '本サービスの利用を希望する方は、本規約に同意の上、当社の定める方法によって利用登録を申請し、当社がこれを承認することによって、利用登録が完了するものとします。',
          ),
          _TermsSection(
            title: '第3条（サブスクリプション）',
            content: 'プレミアムプランは月額制のサブスクリプションサービスです。料金は事前にApp Store / Google Play経由でお支払いいただきます。サブスクリプションは自動的に更新されます。',
          ),
          _TermsSection(
            title: '第4条（禁止事項）',
            content: 'ユーザーは、本サービスの利用にあたり、以下の行為をしてはなりません。\n• 法令または公序良俗に違反する行為\n• 犯罪行為に関連する行為\n• 当社、本サービスの他のユーザー、または第三者のサーバーまたはネットワークの機能を破壊したり、妨害したりする行為',
          ),
          _TermsSection(
            title: '第5条（本サービスの提供の停止等）',
            content: '当社は、以下のいずれかの事由があると判断した場合、ユーザーに事前に通知することなく本サービスの全部または一部の提供を停止または中断することができるものとします。',
          ),
          _TermsSection(
            title: '第6条（利用制限および登録抹消）',
            content: '当社は、ユーザーが以下のいずれかに該当する場合には、事前の通知なく、ユーザーに対して、本サービスの全部もしくは一部の利用を制限し、またはユーザーとしての登録を抹消することができるものとします。',
          ),
          _TermsSection(
            title: '第7条（免責事項）',
            content: '当社は、本サービスに事実上または法律上の瑕疵（安全性、信頼性、正確性、完全性、有効性、特定の目的への適合性、セキュリティなどに関する欠陥、エラーやバグ、権利侵害などを含みます。）がないことを明示的にも黙示的にも保証しておりません。',
          ),
          _TermsSection(
            title: '第8条（サービス内容の変更等）',
            content: '当社は、ユーザーに通知することなく、本サービスの内容を変更しまたは本サービスの提供を中止することができるものとし、これによってユーザーに生じた損害について一切の責任を負いません。',
          ),
          _TermsSection(
            title: '第9条（利用規約の変更）',
            content: '当社は、必要と判断した場合には、ユーザーに通知することなくいつでも本規約を変更することができるものとします。なお、本規約の変更後、本サービスの利用を開始した場合には、当該ユーザーは変更後の規約に同意したものとみなします。',
          ),
          _TermsSection(
            title: '第10条（準拠法・裁判管轄）',
            content: '本規約の解釈にあたっては、日本法を準拠法とします。本サービスに関して紛争が生じた場合には、当社の本店所在地を管轄する裁判所を専属的合意管轄とします。',
          ),
          SizedBox(height: 24),
          Text(
            '最終更新日：2024年1月1日',
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
