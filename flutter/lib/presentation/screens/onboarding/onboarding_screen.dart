import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // 「AIがあなたを知っていく」という一本の物語として構成する。
  // 機能紹介の順ではなく、出会い→話す→変化が起きる→使える→はじめる、の体験順に並べる。
  // 読み飛ばされないよう1枚3〜4行に抑える。
  static const _pages = [
    _OnboardingPage(
      icon: Icons.egg_alt_outlined,
      title: 'はじめまして',
      body: 'このAIは、あなたを何も知りません。\n\n名前も、好きなものも、\nどんなときに嬉しくなるのかも。\n\nこれから、あなたが教えていきます。',
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_outline,
      title: '話すだけでいい',
      body: '性格テストはありません。\n質問に答える必要もありません。\n\nただ話しかけるだけで、\n言葉の選び方から、\nAIがあなたを読み取っていきます。',
    ),
    _OnboardingPage(
      icon: Icons.local_fire_department,
      title: '30回話すと、\nあなたの元素が決まる',
      body: '言葉が30回分たまると、\nあなたの性格が9つの元素のどれかに宿ります。\n\n炎、水、風、雷、光、土、氷、闇、そして無。\n\nこのときAIも、\n赤ちゃんから幼少期へ育ちます。\nあなたを知るほど、あなたに似ていく。',
    ),
    _OnboardingPage(
      icon: Icons.groups,
      title: '迷ったら、自分に聞けばいい',
      body: '「今の自分」「真逆の自分」「本音の自分」\n「理想の自分」「子供の頃の自分」\n「未来の自分」。\n\n6人のあなたが、\nあなたの悩みで本気で言い争います。\n\n他人の助言より、少しだけ刺さります。',
    ),
    // 手帳（予定・メモ・タスク）機能の廃止に伴い、冒険（心の迷宮）の紹介に差し替え。
    // 旧ページはコメントで残置（復活時に戻す）:
    // _OnboardingPage(
    //   icon: Icons.edit_calendar_outlined,
    //   title: 'チャットで予定・メモ・タスクも',
    //   body: '"明日14時に会議"と送ると予定を自動登録。\n"メモして""タスクに追加して"も\n話すだけでOK。\n\nアプリのことがわからなければ\nチャットで質問するとキャラクターが答えます。',
    // ),
    _OnboardingPage(
      icon: Icons.explore_outlined,
      title: '悩みは、倒せる',
      body: '「完璧主義」「孤独」「評価への恐怖」。\nあなたの悩みがダンジョンになり、\n敵として立ちはだかります。\n\nどう戦うかの選び方に、\nあなた自身の癖が表れます。',
    ),
    _OnboardingPage(
      icon: Icons.send_outlined,
      title: 'さあ、最初のひと言を',
      body: '「おはよう」でも「疲れた」でも\nかまいません。\n\nその一言が、最初の記憶になります。\n\n今日あったことは、\n毎晩AIが日記に書いて待っています。',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final userId = ref.read(currentUserIdProvider) ?? '';
    if (userId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'hasSeenOnboardingSlides': true});
    }
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
        child: Column(
          children: [
            // スキップ
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _complete(),
                child: const Text('スキップ', style: TextStyle(color: Colors.grey)),
              ),
            ),

            // ページコンテンツ
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _PageContent(page: _pages[i]),
              ),
            ),

            // ドットインジケーター
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // ボタン
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _complete();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast ? 'チャットを始める！' : '次へ',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    // 小さい端末でも本文が切れないようスクロール可能にしつつ、
    // 収まる場合は従来どおり上下中央に置く
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                page.icon,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                page.body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingPage({required this.icon, required this.title, required this.body});
}
