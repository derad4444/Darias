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
        children: [
          if (section.imageAsset != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                section.imageAsset!,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...section.items.map(
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
          ),
        ],
      ),
    );
  }
}

class _HelpSection {
  final String title;
  final IconData icon;
  final List<String> items;
  final String? imageAsset;
  const _HelpSection({
    required this.title,
    required this.icon,
    required this.items,
    this.imageAsset,
  });
}

const _kSections = [
  _HelpSection(
    title: 'チャット',
    icon: Icons.chat_bubble_outline,
    items: [
      '"この機能の使い方は？"などアプリの操作方法もチャットで質問できます',
      '過去の会話履歴はホーム画面の「履歴」ボタンで確認できます',
    ],
  ),
  _HelpSection(
    title: '冒険（心の迷宮）',
    icon: Icons.explore_outlined,
    items: [
      '「冒険」タブから、悩みをテーマにしたダンジョン「心の迷宮」に挑戦できます',
      '枝道を選んで進み、敵（悩み）を乗り越えると、選んだ行動の傾向からあなたの心を診断します',
      '全てのダンジョンを踏破すると、キャラクター詳細画面「冒険の性格」タブで総合診断が受け取れます',
      '結果画面の「記録」から過去の冒険の記録も確認できます',
    ],
  ),
  _HelpSection(
    title: '冒険：相棒（絆）について',
    icon: Icons.handshake_outlined,
    items: [
      '冒険中の「助けを求める声」イベントで、傷ついた冒険者レオが仲間（相棒）になることがあります',
      '相棒がいると「絆」🤝 が有効になり、上部のリソースバーに表示されます（相棒がいない間は絆は増減せず、表示もされません）',
      '相棒がいると、戦闘で強力な特効技（「仲間と力を合わせる」など）が使えます。絆を消費しますが大ダメージを狙えます',
      '休憩に出る「仲間の疲労」など、相棒がいる時だけのイベントで絆を深められます',
      '一部の敵は反撃で絆を削ってきます。絆が0になると相棒は去っていきます',
    ],
  ),
  _HelpSection(
    title: '日記（自動生成）',
    icon: Icons.auto_stories_outlined,
    items: [
      '毎晩23:50頃に、当日のチャットや冒険（心の迷宮）などの活動をもとにアクティビティ型日記が自動生成されます',
      'ホーム画面の「履歴」ボタン → 日記タブで確認できます',
      '日記をタップするとコメントを追記できます',
      '設定 → 通知設定 → 日記通知をオンにすると、日記生成後にプッシュ通知が届きます（アプリが閉じていても届きます）',
    ],
  ),
  _HelpSection(
    title: '性格解析',
    icon: Icons.psychology_outlined,
    items: [
      'チャットを続けると自動的に性格が解析されていきます（質問への回答は不要です）',
      '30回以上チャットすると性格タイプ（元素）が判定され、キャラクターが幼少期に成長します',
      '100回以上チャットすると性格がより安定し、キャラクターが大人へと成長します',
      'ホーム画面の成長ゲージで次のステージまでの進捗を確認できます',
      'キャラクター詳細画面でも成長ゲージと性格タイプを確認できます',
      '解析結果がキャラクターの返答・日記・6人会議・相性診断に反映されます',
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
      '無料ユーザーは生涯1回まで、プレミアムユーザーは無制限に利用できます',
    ],
  ),
  _HelpSection(
    title: 'フレンド',
    icon: Icons.people_outline,
    items: [
      'フレンド画面の検索ボタンから名前またはメールアドレスで検索して申請できます',
      '受信した申請はフレンド画面の通知バッジで確認・承認/拒否できます',
    ],
  ),
  _HelpSection(
    title: '相性診断',
    icon: Icons.favorite_border,
    items: [
      'フレンドタブ → フレンド詳細 → 相性診断ボタンからアクセスできます',
      '友情・恋愛・仕事・信頼の4カテゴリをそれぞれ個別に診断できます',
      '無料ユーザーは各カテゴリを動画広告の視聴で解放できます。プレミアムユーザーは広告なしで診断できます',
      '診断には自分とフレンド双方の性格解析が必要です（30回以上チャットが目安）',
      '双方の性格スコアをもとに0〜100%でスコア化され、キャラクター会話・コメント・アドバイスが表示されます',
    ],
  ),
  _HelpSection(
    title: '元素と性格について',
    icon: Icons.hub_outlined,
    items: [
      '性格解析によって9種類の元素のいずれかが判定されます。30回以上チャットすると自分の元素が確定します。',
      '炎属性 — 喜怒哀楽がそのまま言葉や行動に出る情熱型。感情が外に溢れやすく周囲を熱狂させるエネルギーがある。決断が速く行動力もある。',
      '水属性 — 相手の気持ちを敏感に察する共感型。感情を内側でじっくり受け止め、優しさと穏やかさで場を包む。深いところで人と繋がれる。',
      '風属性 — 枠にはまらない自由人型。好奇心旺盛でひらめきが得意。感情にも論理にも縛られず軽やかに動き、変化を楽しんで周囲を明るくする。',
      '土属性 — 揺るがない芯を持つ安定型。じっくり考えてから動き、一度決めたことをやり遂げる粘り強さがある。周囲に安心感を与える存在。',
      '氷属性 — 感情を表に出さず内側で研ぎ澄ます冷静型。独自の基準を持ち、近づくほど深みとこだわりが見えてくる。',
      '雷属性 — 直感と行動力が爆発する瞬発型。エネルギッシュで存在感があり、場の空気を一瞬で変えるカリスマ性がある。',
      '光属性 — 分析力と行動力を外に向けるリーダー型。計画的で明晰、情報を整理して周囲を導く推進力がある。',
      '闇属性 — 物事の本質を内側で追求する思索型。独自の視点と分析力を持ち、深く語り合うほど豊かな世界が見えてくる。',
      '無属性 — どんな状況にも自然に溶け込む適応型。強い主張より観察と受容を大切にし、すべての元素と一定の相性がある。',
    ],
  ),
  _HelpSection(
    title: '元素の相性について',
    icon: Icons.favorite_border,
    imageAsset: 'assets/images/element_chart.png',
    items: [
      '双方向矢印の元素同士は特に相性が良い対ペアです。無はすべての元素と一定の相性があります。',
      '炎↔水: 感情で深く繋がる。時にぶつかるほどの熱量',
      '雷↔氷: 同じ直感型。熱量の差が惹かれ合いを生む',
      '光↔闇: 同じ分析型。外向きと内向きで視点が逆',
      '風↔土: 完全対極。自由と安定が刺激し合う',
    ],
  ),
  _HelpSection(
    title: 'プレミアム機能',
    icon: Icons.star_outline,
    items: [
      '設定画面の「プレミアムに登録」からApp Store / Google Playで月額課金できます',
      'プレミアムになるとキャラクター返答が高品質AIモデル（GPT-4o）になります',
      '日記生成も高品質AIモデルを使用します',
      'キャラクターの返答を声で聞けます（プレミアム専用）',
      '6人会議が無制限に利用できます（無料は生涯1回）',
      '相性診断・フレンドへの質問が広告なしで利用できます',
      '解約はApp Store / Google Playのサブスクリプション設定から行えます',
    ],
  ),
  _HelpSection(
    title: '設定・カスタマイズ',
    icon: Icons.settings_outlined,
    items: [
      'テーマカラー：設定 → 背景色・文字色 からグラデーションや単色を変更できます',
      '音量設定：設定 → 音量設定 でBGM・キャラクター音声を個別に調整できます',
      '通知設定：設定 → 通知設定 で日記通知のオン/オフを設定できます',
    ],
  ),
];
