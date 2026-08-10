// lib/presentation/widgets/app_review_dialog.dart

import 'package:flutter/material.dart';

import '../../data/services/app_review_service.dart';

/// アプリ評価を促すポップアップ。
///
/// **OS標準の評価ダイアログをいきなり出さず、これを1枚挟む。**
/// iOSの評価ダイアログは1年に3回までしか出せないため、
/// 「評価する」を押した前向きな人にだけ枠を使う（詳細は `AppReviewService`）。
///
/// **強制しない。** 「また今度」でも、外側をタップしても閉じられる。
///
/// [achievement] にはその瞬間の成果を渡す（例:「『先延ばし』を克服しました」）。
/// 何を褒められているのかが具体的だと、唐突なお願いに感じられにくい。
Future<void> showAppReviewDialog(
  BuildContext context, {
  required String emoji,
  required String headline,
  required String achievement,
  AppReviewService? service,
}) async {
  final svc = service ?? AppReviewService();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            achievement,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 14),
          const Text(
            'よろしければ、お店での評価で\n応援していただけると嬉しいです。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: Color(0xFF777777)),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('また今度', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE08AAE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.star, size: 18),
          label: const Text('評価する'),
        ),
      ],
    ),
  );

  // 外側タップで閉じた場合（result == null）も「また今度」と同じ扱いにする。
  if (result == true) {
    await svc.openReview();
  } else {
    await svc.postpone();
  }
}
