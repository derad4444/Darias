import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/auth_provider.dart';

/// 報告するAIの内容の種類
enum AiContentType {
  chat('チャットの返信'),
  meeting('自分会議'),
  diary('日記');

  const AiContentType(this.label);
  final String label;
}

/// 報告の理由
enum _ReportReason {
  offensive('不快・攻撃的'),
  sexual('性的な内容'),
  harmful('危険・有害'),
  inaccurate('事実と違う'),
  other('その他');

  const _ReportReason(this.label);
  final String label;
}

/// AIが作った内容を運営へ報告するシートを開く（Google Play のAI生成コンテンツのポリシー対応）
///
/// 報告はお問い合わせと同じ `contacts` に保存し、`sendContactEmail` が運営へメールする。
/// [content] は報告されるAIの文章、[sourceText] はその元になったユーザーの発言や相談（任意）。
Future<void> showAiContentReportSheet({
  required BuildContext context,
  required AiContentType type,
  required String content,
  String? sourceText,
  String? refId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // 下のタブバーより手前に出す
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiContentReportSheet(
      type: type,
      content: content,
      sourceText: sourceText,
      refId: refId,
    ),
  );
}

/// 報告ボタン（🚩）。押すと報告シートを開く
class AiContentReportButton extends StatelessWidget {
  final AiContentType type;
  final String content;
  final String? sourceText;
  final String? refId;
  final double size;

  const AiContentReportButton({
    super.key,
    required this.type,
    required this.content,
    this.sourceText,
    this.refId,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.outlined_flag, size: size),
      tooltip: 'AIの内容を報告',
      color: Colors.grey,
      onPressed: () => showAiContentReportSheet(
        context: context,
        type: type,
        content: content,
        sourceText: sourceText,
        refId: refId,
      ),
    );
  }
}

class _AiContentReportSheet extends ConsumerStatefulWidget {
  final AiContentType type;
  final String content;
  final String? sourceText;
  final String? refId;

  const _AiContentReportSheet({
    required this.type,
    required this.content,
    this.sourceText,
    this.refId,
  });

  @override
  ConsumerState<_AiContentReportSheet> createState() => _AiContentReportSheetState();
}

class _AiContentReportSheetState extends ConsumerState<_AiContentReportSheet> {
  static const int _maxCommentLength = 500;
  final _commentController = TextEditingController();
  _ReportReason? _reason;
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (reason == null || userId == null || _isSending) return;

    setState(() => _isSending = true);
    try {
      final user = ref.read(userDocProvider).valueOrNull;
      final packageInfo = await PackageInfo.fromPlatform();
      final comment = _commentController.text.trim();
      final message = [
        '【報告の対象】${widget.type.label}',
        '【理由】${reason.label}',
        if (comment.isNotEmpty) '【コメント】$comment',
        if (widget.refId != null) '【ID】${widget.refId}',
        '',
        '■ AIの内容',
        widget.content,
        if (widget.sourceText != null && widget.sourceText!.isNotEmpty) ...[
          '',
          '■ 元になったユーザーの入力',
          widget.sourceText!,
        ],
      ].join('\n');

      await ref.read(firestoreProvider).collection('contacts').add({
        'userId': userId,
        'userEmail': user?.email ?? '',
        'userName': user?.name ?? '',
        'category': 'aiContentReport',
        'categoryDisplay': 'AIの内容の報告',
        'subject': '【DARIAS】AIの内容の報告',
        'message': message,
        'reportType': widget.type.name,
        'reportReason': reason.name,
        if (widget.refId != null) 'reportRefId': widget.refId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'adminEmailSent': false,
        'userEmailSent': false,
        'deviceInfo': {
          'appVersion': '${packageInfo.version} (${packageInfo.buildNumber})',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('報告を受け付けました。ご協力ありがとうございます')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送信できませんでした。もう一度お試しください')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'AIの内容を報告',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '不快な内容や不適切な内容があれば教えてください。報告は運営が確認し、AIの改善に使います。',
                  style: TextStyle(fontSize: 13, color: theme.hintColor),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(widget.content, style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('理由', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ReportReason.values
                      .map((r) => ChoiceChip(
                            label: Text(r.label),
                            selected: _reason == r,
                            onSelected: (_) => setState(() => _reason = r),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLength: _maxCommentLength,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'くわしい内容（任意）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _reason == null || _isSending ? null : _send,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('報告する'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
