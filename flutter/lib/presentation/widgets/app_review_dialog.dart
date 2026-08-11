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
            'よろしければ、ストアでの評価で\n応援していただけると嬉しいです。',
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
  if (result != true) {
    await svc.postpone();
    return;
  }

  await svc.openReview();

  // OS標準の評価画面はアプリ内に重なって出るが、**表示や送信の完了を
  // アプリ側で受け取る手段がない**。少し待ってから次のお願いを出す。
  await Future.delayed(const Duration(seconds: 5));
  if (!context.mounted) return;
  await _askWrittenReview(context, svc);
}

/// 星のあとに、文章レビューを任意でお願いする2段目。
///
/// **アプリ内の評価画面では星しか付けられない。** 文章レビューは検索順位や
/// 新規ユーザーの判断に効くため、協力してくれた人にだけ続けてお願いする。
/// こちらは**アプリを離れる**ので、断りやすい見せ方にしている。
Future<void> _askWrittenReview(BuildContext context, AppReviewService svc) async {
  final write = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🙏', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            'ありがとうございます',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'もしよろしければ、ひとこと感想も\nいただけると励みになります。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF555555)),
          ),
          SizedBox(height: 12),
          Text(
            'ストアのページが開きます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Color(0xFF999999)),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('このままでいい', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE08AAE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.edit, size: 17),
          label: const Text('感想を書く'),
        ),
      ],
    ),
  );
  if (write == true) await svc.openStoreListing();
}
