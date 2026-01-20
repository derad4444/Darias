import 'package:share_plus/share_plus.dart';

/// シェアサービス
class ShareService {
  /// テキストをシェア
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  /// ファイルをシェア
  Future<void> shareFile(
    String filePath, {
    String? text,
    String? subject,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: text,
      subject: subject,
    );
  }

  /// 複数ファイルをシェア
  Future<void> shareFiles(
    List<String> filePaths, {
    String? text,
    String? subject,
  }) async {
    final xFiles = filePaths.map((path) => XFile(path)).toList();
    await Share.shareXFiles(
      xFiles,
      text: text,
      subject: subject,
    );
  }

  /// 日記をシェア
  Future<void> shareDiary({
    required DateTime date,
    required String content,
    required int mood,
  }) async {
    final moodEmoji = _getMoodEmoji(mood);
    final dateStr = '${date.year}/${date.month}/${date.day}';
    final text = '''
【$dateStr の日記】$moodEmoji

$content

#DARIAS #日記アプリ
''';
    await shareText(text, subject: '$dateStrの日記');
  }

  /// TODOをシェア
  Future<void> shareTodo({
    required String title,
    required String? description,
    required bool isCompleted,
    required DateTime? dueDate,
  }) async {
    final status = isCompleted ? '完了' : '未完了';
    final dueDateStr = dueDate != null
        ? '期限: ${dueDate.year}/${dueDate.month}/${dueDate.day}'
        : '';
    final text = '''
【TODO】$title
状態: $status
${dueDateStr.isNotEmpty ? dueDateStr : ''}
${description ?? ''}

#DARIAS #TODOアプリ
''';
    await shareText(text, subject: 'TODO: $title');
  }

  /// メモをシェア
  Future<void> shareMemo({
    required String title,
    required String content,
  }) async {
    final text = '''
【メモ】$title

$content

#DARIAS
''';
    await shareText(text, subject: 'メモ: $title');
  }

  /// 会議結果をシェア
  Future<void> shareMeetingResult({
    required String topic,
    required String conclusion,
    required List<String> participants,
  }) async {
    final participantsStr = participants.join('、');
    final text = '''
【6人会議の結果】

テーマ: $topic

参加者: $participantsStr

結論:
$conclusion

#DARIAS #6人会議
''';
    await shareText(text, subject: '会議: $topic');
  }

  String _getMoodEmoji(int mood) {
    switch (mood) {
      case 5:
        return '😄';
      case 4:
        return '😊';
      case 3:
        return '😐';
      case 2:
        return '😔';
      case 1:
        return '😢';
      default:
        return '😐';
    }
  }
}
