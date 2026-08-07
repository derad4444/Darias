import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 画面外のシェアカードをPNG化して共有する
///
/// 画面ルートの `Stack` に `Positioned(left: -9999)` で置いた
/// `RepaintBoundary`（[cardKey]）をキャプチャして `Share.shareXFiles` に渡す。
/// 画像を作れない環境（web等）ではテキストのみにフォールバックする。
///
/// [buttonKey] は iOS の popover 位置に使う。渡さないと iOS16+ で無言失敗する。
/// [fileName] は一時ファイル名（機能ごとに変えて衝突を避ける）。
Future<void> shareCardWithText({
  required GlobalKey cardKey,
  required String text,
  required String fileName,
  GlobalKey? buttonKey,
  String? subject,
}) async {
  final box = buttonKey?.currentContext?.findRenderObject() as RenderBox?;
  final origin =
      box != null ? box.localToGlobal(Offset.zero) & box.size : null;

  try {
    final boundary =
        cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('share card not ready');

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('image encode failed');

    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/$fileName')
        .writeAsBytes(byteData.buffer.asUint8List());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      subject: subject,
      sharePositionOrigin: origin,
    );
  } catch (e) {
    debugPrint('Share card capture failed ($e), falling back to text share');
    try {
      await Share.share(text, subject: subject, sharePositionOrigin: origin);
    } catch (e2) {
      debugPrint('Share failed: $e2');
    }
  }
}
