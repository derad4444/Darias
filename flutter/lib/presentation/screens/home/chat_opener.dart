import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';



enum OpenerType { memory, previousQuestion, daily }

class ChatOpener {
  final String text;
  final OpenerType type;
  const ChatOpener({required this.text, required this.type});
}

String _sharedPrefKeyQuestion(String userId) => 'chat_last_question_$userId';
String _sharedPrefKeyUsed(String userId) => 'chat_question_used_$userId';
String _sharedPrefKeyMemoryUsed(String userId) => 'memory_opener_used_date_$userId';

// バリエーション豊富なデイリープロンプト（日付ハッシュで毎日1つ選ぶ）
const List<String> dailyPrompts = [
  // 朝・スタート系
  '今日どんな一日にしたい？',
  '今日の自分に一言かけるとしたら何て言う？',
  '今朝の気分、どんな感じ？',
  '今日やることの中で、一番気になってるのは何？',
  '今週、何を大切にして過ごしたい？',
  '今日の自分のテーマを一言で言うと？',
  '今日チャレンジしてみたいことある？',

  // 振り返り系
  '最近うまくいってると感じることある？',
  '今週を振り返って、一番の発見は何？',
  '今日自分を褒めてあげたいことはある？',
  '最近笑ったのはいつ？どんなこと？',
  '今週、誰かに感謝したいことあった？',
  '最近「やってよかった」と思えたことは？',

  // 自己探求系
  '最近、何かもやもやしてることある？',
  '今、一番エネルギーを使ってることって何？',
  '最近の自分、どんな変化があった？',
  '今の自分に足りてないと感じるものって何かな？',
  '最近、心が軽くなった瞬間はあった？',
  '最近、直感に従って動けたことある？',
  '今、一番避けていることって何だろう？',
  '理想の自分と今の自分、どこが一番違う？',
  '1年後の自分に会えるとしたら、何を聞く？',
  '今の自分を動物に例えると何だろう？',
  '最近「本当はこうしたい」と思ったことある？',

  // 思考整理系
  '頭の中でぐるぐるしてることを、一つだけ言葉にしてみて',
  '最近決断できないでいることはある？',
  '今、自分に正直に言えてないことって何かな？',
  'やりたいけどできてないこと、何かある？',
  '最近、誰かに言えなかったことはある？',
  '今の気分を天気で例えると？',
  '最近「これでいいのかな」って思ったことある？',

  // 軽め・雑談系
  '最近ハマってることや気になってることある？',
  '最近、時間を忘れて没頭できたことある？',
  '今週、自分のためにしてあげたいことある？',
  '最近、新しく気づいたこととか発見はある？',
  'もし今日一日やり直せるとしたら、何を変える？',
  '今の自分に必要だと思うものって何？',

  // 深掘り系
  '今一番大切にしたいことって何？',
  '最近、何かをあきらめたことはある？',
  '自分のどんなところが好き？',
  '最近「成長したな」と感じた瞬間はある？',
  'もし誰にも気を使わなくていいとしたら、今何したい？',
  '今、怖いと感じていることってある？',
  '最近、誰かの言葉で心に残ったものある？',
];

/// 優先度 M → F → A でオープナーを決定する
///
/// [characterId] を渡すと、前夜の日記生成で用意された「昨日の続き」の問いかけ
/// （M）を最優先で使う。取得できない場合は従来の F → A にフォールバックする。
Future<ChatOpener> computeChatOpener({
  required String userId,
  String? characterId,
}) async {
  final today = DateTime.now();

  // M: 日記生成が用意した、昨日までの話題に触れる問いかけ
  if (userId.isNotEmpty && characterId != null && characterId.isNotEmpty) {
    final memoryOpener = await _fetchMemoryOpener(userId, characterId);
    if (memoryOpener != null) {
      return ChatOpener(type: OpenerType.memory, text: memoryOpener);
    }
  }

  // F: 使用済みでない前回の問いがある
  final prefs = await SharedPreferences.getInstance();
  final lastQuestion = prefs.getString(_sharedPrefKeyQuestion(userId));
  final questionUsed = prefs.getBool(_sharedPrefKeyUsed(userId)) ?? true;

  if (lastQuestion != null && lastQuestion.isNotEmpty && !questionUsed) {
    await prefs.setBool(_sharedPrefKeyUsed(userId), true);
    return ChatOpener(
      type: OpenerType.previousQuestion,
      text: '前回の問い、その後どうなった？\n「$lastQuestion」',
    );
  }

  // A: 日付ベースのデイリープロンプト（毎日同じプロンプトを1日中表示）
  final dayIndex = today.difference(DateTime(2024, 1, 1)).inDays.abs();
  final prompt = dailyPrompts[dayIndex % dailyPrompts.length];
  return ChatOpener(type: OpenerType.daily, text: prompt);
}

/// 前夜の日記生成が用意したオープナーを取得する
///
/// `memory/current.opener` は「いつ出すか」を `openerDate`（JSTの YYYY-MM-DD）
/// で持っている。その日のうちに1回だけ使い、使ったことは端末側に記録する
/// （Firestoreを書き換えないので、機内モードや読み取り失敗でも壊れない）。
///
/// 取得できない場合は null を返し、呼び出し側が従来のオープナーへ進む。
Future<String?> _fetchMemoryOpener(String userId, String characterId) async {
  final now = DateTime.now();
  final today = '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  final prefs = await SharedPreferences.getInstance();
  // 今日はもう出した
  if (prefs.getString(_sharedPrefKeyMemoryUsed(userId)) == today) return null;

  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('memory')
        .doc('current')
        .get();
    if (!snap.exists) return null;

    final data = snap.data();
    final opener = (data?['opener'] as String? ?? '').trim();
    final openerDate = data?['openerDate'] as String? ?? '';
    // 日付が違うものは出さない（前に使い残したオープナーを何日も出さないため）
    if (opener.isEmpty || openerDate != today) return null;

    await prefs.setString(_sharedPrefKeyMemoryUsed(userId), today);
    return opener;
  } catch (e) {
    debugPrint('記憶オープナーの取得に失敗: $e');
    return null;
  }
}

/// AI返答の末尾から問いかけ文を抽出してSharedPreferencesに保存する
Future<void> saveLastQuestion(String aiReply, String userId) async {
  if (userId.isEmpty) return;
  // 読点・改行で文を分割し、？で終わる最後の文を探す
  final sentences = aiReply.split(RegExp(r'[。！\n]'));
  final question = sentences
      .map((s) => s.trim())
      .lastWhere(
        (s) => s.endsWith('？') || s.endsWith('?'),
        orElse: () => '',
      );

  if (question.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_sharedPrefKeyQuestion(userId), question);
  await prefs.setBool(_sharedPrefKeyUsed(userId), false);
}
