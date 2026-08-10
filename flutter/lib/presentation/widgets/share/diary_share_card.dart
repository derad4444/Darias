import 'package:flutter/material.dart';

import '../../../core/constants/app_links.dart';
import '../../../data/models/diary_model.dart';
import 'share_card_scaffold.dart';

/// 日記のシェアカード
///
/// 日記には旧形式のフリーテキスト型と、現行のアクティビティ型
/// （`facts` ＋ `ai_comment`）がある。どちらも1枚に収まるようにしている。
class DiaryShareCard extends StatelessWidget {
  final DiaryModel diary;

  const DiaryShareCard({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    final facts = diary.facts ?? const <String>[];
    final aiComment = diary.aiComment ?? '';

    return ShareCardScaffold(
      heading: 'DARIAS の日記',
      children: [
        Center(
          child: Text(
            diary.dateString,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF444444),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (diary.isActivityType) ...[
          if (facts.isNotEmpty) ...[
            const ShareCardLabel('📝 今日やったこと'),
            const SizedBox(height: 6),
            ShareCardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < facts.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == facts.length - 1 ? 0 : 6,
                      ),
                      child: Text('・${facts[i]}', style: kShareCardBodyStyle),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (aiComment.isNotEmpty)
            // キャラクターの一言（250〜350文字）。読ませる文なので省略しない
            ShareCardPanel(child: Text(aiComment, style: kShareCardBodyStyle)),
        ] else
          // 旧形式のフリーテキスト日記
          ShareCardPanel(child: Text(diary.content, style: kShareCardBodyStyle)),

        if (diary.userComment.isNotEmpty) ...[
          const SizedBox(height: 16),
          const ShareCardLabel('✍️ ひとこと'),
          const SizedBox(height: 6),
          ShareCardPanel(
            bordered: true,
            child: Text(diary.userComment, style: kShareCardBodyStyle),
          ),
        ],
      ],
    );
  }
}

/// 日記の共有テキスト
String buildDiaryShareText(DiaryModel diary) {
  final buffer = StringBuffer();
  buffer.writeln('${diary.dateString}の日記\n');

  if (diary.isActivityType) {
    final facts = diary.facts ?? const <String>[];
    if (facts.isNotEmpty) {
      buffer.writeln('今日やったこと:');
      for (final fact in facts) {
        buffer.writeln('・$fact');
      }
      buffer.writeln();
    }
    if (diary.aiComment?.isNotEmpty == true) {
      buffer.writeln(diary.aiComment);
    }
  } else {
    buffer.writeln(diary.content);
  }

  if (diary.userComment.isNotEmpty) {
    buffer.writeln('\n---\nひとこと: ${diary.userComment}');
  }

  buffer.writeln('\n#DARIAS #日記');
  buffer.writeln(AppLinks.share);
  return buffer.toString().trim();
}
