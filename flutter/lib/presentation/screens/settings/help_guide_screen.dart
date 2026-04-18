import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';

class HelpGuideScreen extends ConsumerStatefulWidget {
  const HelpGuideScreen({super.key});

  @override
  ConsumerState<HelpGuideScreen> createState() => _HelpGuideScreenState();
}

class _HelpGuideScreenState extends ConsumerState<HelpGuideScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _filteredSections(_query);
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('使い方ガイド'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '機能を検索...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.85),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? const Center(child: Text('該当する機能が見つかりませんでした'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: sections.length,
                    itemBuilder: (_, i) => _SectionTile(section: sections[i]),
                  ),
          ),
        ],
        ),
      ),
    );
  }

  List<_HelpSection> _filteredSections(String query) {
    if (query.isEmpty) return _kSections;
    final q = query.toLowerCase();
    return _kSections
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.items.any((item) => item.toLowerCase().contains(q)))
        .toList();
  }
}

class _SectionTile extends StatelessWidget {
  final _HelpSection section;
  const _SectionTile({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.85),
      child: ExpansionTile(
        leading: Icon(section.icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          section.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: section.items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HelpSection {
  final String title;
  final IconData icon;
  final List<String> items;
  const _HelpSection({required this.title, required this.icon, required this.items});
}

const _kSections = [
  _HelpSection(
    title: 'チャット',
    icon: Icons.chat_bubble_outline,
    items: [
      '"明日14時に会議"と送ると予定を自動登録できます',
      '"〇〇をメモして"と送るとメモに保存できます',
      '"〇〇をタスクに追加して"と送るとTODOに追加できます',
      '"この機能の使い方は？"などアプリの操作方法もチャットで質問できます',
      '過去の会話履歴はホーム画面の「履歴」ボタンで確認できます',
    ],
  ),
  _HelpSection(
    title: '予定（カレンダー）',
    icon: Icons.calendar_today_outlined,
    items: [
      'カレンダー画面の ＋ ボタンまたは右上メニュー（≡）→「予定を追加」で新規追加できます',
      '右上メニュー（≡）→「画像から予定を一括読み取り」でチラシやカレンダーの写真から複数の予定をまとめて登録できます（無料ユーザーは動画広告視聴後に利用可能）',
      '予定作成・編集画面のカメラアイコンで画像からAIがタイトル・日時・場所を自動入力します（無料ユーザーは動画広告視聴後に利用可能）',
      '繰り返し設定（毎日・毎週・毎月・毎年）が設定できます',
      '予定ごとにリマインダー通知のタイミングを設定できます',
      'フレンドが予定を公開している場合、右上メニュー（≡）→「フレンド予定の設定」でフレンドの予定をカレンダーに重ねて表示できます',
      '予定一覧の左の本アイコンをタップするとその日の日記を確認できます。日記は毎晩23:50頃に自動生成されます',
    ],
  ),
  _HelpSection(
    title: 'メモ',
    icon: Icons.note_outlined,
    items: [
      'ノートタブ → メモ から新規作成できます',
      'メモ作成・編集画面のカメラアイコンで画像からAIがタイトルと内容を自動入力します（無料ユーザーは動画広告視聴後に利用可能）',
      'ツールバーの「タスク」ボタンを押すと行頭にタスクマークが付きます。タスクマーク付きの行が1件以上あると「タスクに登録」ボタンが表示され、チェックした行をタスク（TODO）に一括登録できます',
      'タグやピン留めをメモ詳細画面で設定できます',
    ],
  ),
  _HelpSection(
    title: 'タスク（TODO）',
    icon: Icons.check_box_outlined,
    items: [
      'ノートタブ → タスク から新規作成できます',
      'タスク作成・編集画面のカメラアイコンで画像からAIがタイトル・期限・優先度を自動入力します（無料ユーザーは動画広告視聴後に利用可能）',
      '優先度（高・中・低）と期限を設定できます',
      'タスク一覧でチェックボックスをタップすると完了になります',
    ],
  ),
  _HelpSection(
    title: '日記（自動生成）',
    icon: Icons.auto_stories_outlined,
    items: [
      '毎晩23:50頃に当日のチャット・タスク・メモ・予定をもとにアクティビティ型日記が自動生成されます',
      'ホーム画面の「履歴」ボタン → 日記タブで確認できます',
      'カレンダー画面で日付をタップしたとき、予定一覧の左にある本アイコンからも確認できます',
      '日記をタップするとコメントを追記できます',
      '設定 → 通知設定 → 日記通知をオンにすると、日記生成後にプッシュ通知が届きます（アプリが閉じていても届きます）',
    ],
  ),
  _HelpSection(
    title: '性格診断（BIG5）',
    icon: Icons.psychology_outlined,
    items: [
      'チャットで"性格診断して"と送ると100問の診断が始まります',
      '1〜5の数字で答え、100問完了するとBIG5スコアが確定します',
      'スコアがキャラクターの返答・日記・6人会議・相性診断に反映されます',
      '詳細タブで診断結果（BIG5スコア・性格タイプ・強み・弱みなど）を確認できます',
      '設定 → 性格診断をリセット でやり直せます',
    ],
  ),
  _HelpSection(
    title: '自分会議（6人会議）',
    icon: Icons.groups_outlined,
    items: [
      '自分の6つの分身（今の自分・真逆の自分・理想の自分・本音の自分・子供の頃の自分・未来の自分）が悩みについてディスカッションしてくれます',
      'ホーム画面のメニューから「会議を開く」で利用できます',
      '悩みのカテゴリを選択 → 悩みを入力 → 6人が3ラウンドで議論 → 結論が表示されます',
      '「完了」ボタンでホームに戻ると次のチャット返答に会議の内容が自動で反映されます',
      '無料ユーザーは生涯1回まで、プレミアムユーザーは月30回まで利用できます',
    ],
  ),
  _HelpSection(
    title: 'フレンド',
    icon: Icons.people_outline,
    items: [
      'フレンド画面の検索ボタンから名前またはメールアドレスで検索して申請できます',
      '受信した申請はフレンド画面の通知バッジで確認・承認/拒否できます',
      'フレンドごとに予定の共有レベルを設定できます：非公開（見せない）・公開（公開設定の予定のみ）・全公開（すべて見せる）',
      'カレンダー画面でフレンドを選択してオンにすると、フレンドの予定がカレンダーに重ねて表示されます',
    ],
  ),
  _HelpSection(
    title: '相性診断',
    icon: Icons.favorite_border,
    items: [
      'フレンドタブ → フレンド詳細 → 相性診断ボタンからアクセスできます',
      '友情・恋愛・仕事・信頼の4カテゴリをそれぞれ個別に診断できます',
      '無料ユーザーは各カテゴリを動画広告の視聴で解放できます。プレミアムユーザーは広告なしで診断できます',
      '診断には自分とフレンド双方のBIG5診断完了が必要です',
      '双方のBIG5スコアをもとに0〜100%でスコア化され、キャラクター会話・コメント・アドバイスが表示されます',
    ],
  ),
  _HelpSection(
    title: 'プレミアム機能',
    icon: Icons.star_outline,
    items: [
      '設定画面の「プレミアムに登録」からApp Store / Google Playで月額課金できます',
      'プレミアムになるとキャラクター返答が高品質AIモデル（GPT-4o）になります',
      '日記生成も高品質AIモデルを使用します',
      '6人会議が月30回まで利用できます（無料は生涯1回）',
      '相性診断が広告なしで利用できます',
      '解約はApp Store / Google Playのサブスクリプション設定から行えます',
    ],
  ),
  _HelpSection(
    title: '設定・カスタマイズ',
    icon: Icons.settings_outlined,
    items: [
      'テーマカラー：設定 → 背景色・文字色 からグラデーションや単色を変更できます',
      '音量設定：設定 → 音量設定 でBGM・キャラクター音声を個別に調整できます',
      '通知設定：設定 → 通知設定 で予定リマインダーと日記通知のオン/オフを設定できます',
      'タグ管理：設定 → タグ管理 でメモ・タスク・予定に設定するタグを作成・編集できます',
      'データエクスポート：設定 → データエクスポート でメモ・タスクを書き出せます',
    ],
  ),
];
