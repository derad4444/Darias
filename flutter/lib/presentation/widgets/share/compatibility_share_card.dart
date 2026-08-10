import 'package:flutter/material.dart';

import '../../../core/constants/app_links.dart';
import '../../../data/models/friend_model.dart';
import '../../screens/friend/compatibility_screen.dart'
    show CompatibilityCategoryMeta;
import '../character_avatar_widget.dart';
import 'share_card_scaffold.dart';

/// 相性診断のシェアカード
///
/// 自分とフレンドのアバターを並べ、間にカテゴリアイコンを置く。
/// アバターは `Image.asset`（アプリ同梱）なのでキャプチャ時の読み込み待ちは発生しない。
class CompatibilityShareCard extends StatelessWidget {
  final CompatibilityCategoryMeta category;
  final CategoryDiagnosis diagnosis;
  final String myUserId;
  final String myName;
  final String friendUserId;
  final String friendName;

  const CompatibilityShareCard({
    super.key,
    required this.category,
    required this.diagnosis,
    required this.myUserId,
    required this.myName,
    required this.friendUserId,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardScaffold(
      heading: '相性診断 — ${category.icon} ${category.label}',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Person(userId: myUserId, name: myName, color: category.color),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(category.icon, style: const TextStyle(fontSize: 22)),
            ),
            _Person(
              userId: friendUserId,
              name: friendName,
              color: category.color,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${diagnosis.score}%',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: category.color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // スコアバー（0〜100を0.0〜1.0に変換。範囲外の値でもはみ出さないようクランプする）
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (diagnosis.score / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.75),
            valueColor: AlwaysStoppedAnimation<Color>(category.color),
          ),
        ),
        const SizedBox(height: 14),
        // コメントは30文字以内の短文（diagnoseCompatibility.js のプロンプト制約）。
        // パネルに入れると間延びするのでカードの見出しとして中央に大きく置く。
        Center(
          child: Text(
            '「${diagnosis.comment}」',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.bold,
              color: category.color,
            ),
          ),
        ),
        if (diagnosis.conversation.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(color: Colors.black.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),
          // 会話は4〜5ターン。カードで一番情報量のある部分なので全件載せる
          for (final message in diagnosis.conversation)
            _Bubble(
              message: message,
              myUserId: myUserId,
              friendUserId: friendUserId,
              accentColor: category.color,
            ),
        ],
        if (diagnosis.advice.isNotEmpty) ...[
          const SizedBox(height: 4),
          const ShareCardLabel('💡 アドバイス'),
          const SizedBox(height: 6),
          ShareCardPanel(
            child: Text(diagnosis.advice, style: kShareCardBodyStyle),
          ),
        ],
      ],
    );
  }
}

/// カード用の静的チャットバブル
///
/// 画面側の `CompatibilityChatBubble` と配色を揃えるが、
/// キャプチャ対象なのでアニメーションは持たない。
class _Bubble extends StatelessWidget {
  final CompatibilityMessage message;
  final String myUserId;
  final String friendUserId;
  final Color accentColor;

  const _Bubble({
    required this.message,
    required this.myUserId,
    required this.friendUserId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMyCharacter;
    final tint = isMe ? accentColor : Colors.indigo;
    final avatar = CharacterAvatarWidget(
      userId: isMe ? myUserId : friendUserId,
      size: 26,
      fallbackText: '',
      fallbackBackgroundColor: tint.withValues(alpha: 0.2),
      fallbackTextColor: tint,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isMe) ...[avatar, const SizedBox(width: 7)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: isMe ? 0.15 : 0.08),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 4 : 13),
                  topRight: Radius.circular(isMe ? 13 : 4),
                  bottomLeft: const Radius.circular(13),
                  bottomRight: const Radius.circular(13),
                ),
                border: Border.all(
                  color: tint.withValues(alpha: isMe ? 0.3 : 0.2),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ),
          if (!isMe) ...[const SizedBox(width: 7), avatar],
        ],
      ),
    );
  }
}

/// アバターと名前の縦並び
class _Person extends StatelessWidget {
  final String userId;
  final String name;
  final Color color;

  const _Person({
    required this.userId,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterAvatarWidget(
            userId: userId,
            size: 56,
            fallbackText: '',
            fallbackBackgroundColor: color.withValues(alpha: 0.2),
            fallbackTextColor: color,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相性診断の共有テキスト
String buildCompatibilityShareText({
  required CompatibilityCategoryMeta category,
  required CategoryDiagnosis diagnosis,
  required String friendName,
}) {
  final buffer = StringBuffer();
  buffer.writeln('${category.icon} $friendNameとの${category.label}の相性\n');
  buffer.writeln('相性スコア: ${diagnosis.score}%\n');
  buffer.writeln(diagnosis.comment);
  if (diagnosis.advice.isNotEmpty) {
    buffer.writeln('\n💡 ${diagnosis.advice}');
  }
  buffer.writeln('\n#DARIAS #相性診断');
  buffer.writeln(AppLinks.share);
  return buffer.toString().trim();
}
