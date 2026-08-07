import 'package:flutter/material.dart';

/// シェアカード共通の枠
///
/// 幅360・パステル縦グラデ・末尾に DARIAS 表記。
/// 進化ダイアログ（home_screen）とローグライク結果のカードも同じ配色で作られており、
/// 新しいカードはこの枠を使って見た目を揃える。
class ShareCardScaffold extends StatelessWidget {
  /// カード上部の小見出し（例: '自分会議 — 6人の私'）
  final String heading;

  /// 見出しとフッターの間に並べる中身
  final List<Widget> children;

  const ShareCardScaffold({
    super.key,
    required this.heading,
    required this.children,
  });

  /// 他のシェアカードと揃えた幅
  static const double width = 360;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1F6), Color(0xFFF1F7FF)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                heading,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...children,
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'DARIAS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// カード内の見出し（例: '💡 会議の結論'）
class ShareCardLabel extends StatelessWidget {
  final String text;
  const ShareCardLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF555555),
        ),
      );
}

/// カード内の白半透明パネル
class ShareCardPanel extends StatelessWidget {
  final Widget child;

  /// 枠線を付けるか（相談内容など、区切りを強調したいとき）
  final bool bordered;

  const ShareCardPanel({super.key, required this.child, this.bordered = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: bordered
              ? Border.all(color: Colors.black.withValues(alpha: 0.06))
              : null,
        ),
        child: child,
      );
}

/// カード本文の標準スタイル
const TextStyle kShareCardBodyStyle = TextStyle(
  fontSize: 12.5,
  height: 1.65,
  color: Color(0xFF333333),
);
