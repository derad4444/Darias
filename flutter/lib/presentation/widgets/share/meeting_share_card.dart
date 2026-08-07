import 'package:flutter/material.dart';

import '../../../data/models/six_person_meeting_model.dart';
import 'share_card_scaffold.dart';

/// 自分会議の結果シェアカード
///
/// 会議の実行直後（`meeting_screen.dart`）と履歴の詳細（`unified_history_screen.dart`）の
/// 両方から使う。見た目を1箇所で管理するためのウィジェット。
class MeetingShareCard extends StatelessWidget {
  final String concern;
  final MeetingConclusion conclusion;

  const MeetingShareCard({
    super.key,
    required this.concern,
    required this.conclusion,
  });

  static const _members =
      '今の自分・真逆の自分・理想の自分\n本音の自分・子供の頃の自分・未来の自分';

  @override
  Widget build(BuildContext context) {
    return ShareCardScaffold(
      heading: '自分会議 — 6人の私',
      children: [
        // 相談内容（長文になりうるので3行で省略する）
        ShareCardPanel(
          bordered: true,
          child: Text(
            '💭 $concern',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
        ),
        const SizedBox(height: 16),

        const ShareCardLabel('💡 会議の結論'),
        const SizedBox(height: 6),
        // 結論は200〜300文字あるが、途中で切れているほうが体裁が悪いため省略しない
        ShareCardPanel(
          child: Text(conclusion.summary, style: kShareCardBodyStyle),
        ),

        if (conclusion.recommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          const ShareCardLabel('🎯 アドバイス'),
          const SizedBox(height: 6),
          ShareCardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < conclusion.recommendations.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == conclusion.recommendations.length - 1 ? 0 : 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conclusion.recommendations[i],
                            style: kShareCardBodyStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        const Center(
          child: Text(
            _members,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, height: 1.5, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

/// 会議結果の共有テキスト（実行直後・履歴で共通）
String buildMeetingShareText({
  required String concern,
  required MeetingConclusion conclusion,
}) {
  final recommendations = conclusion.recommendations
      .asMap()
      .entries
      .map((e) => '${e.key + 1}. ${e.value}')
      .join('\n');

  return '''
【自分会議の結論】

📋 相談内容:
$concern

💡 会議の結論:
${conclusion.summary}

🎯 アドバイス:
$recommendations

---
#DARIAS #自分会議
'''
      .trim();
}
