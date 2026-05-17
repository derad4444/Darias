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

  static const _pages = [
    _OnboardingPage(
      icon: Icons.psychology_outlined,
      title: '話すだけで、自分がわかる',
      body: 'DARIASは、キャラクターとチャットするだけで\nAIが自動的にあなたの性格を解析します。\n\nテストも質問もなし。\n普段の言葉から、あなたを読み取ります。',
    ),
    _OnboardingPage(
      icon: Icons.local_fire_department,
      title: '性格タイプが明らかに',
      body: '30回チャットすると、あなたの性格タイプが\n判定されます。\n\n炎・水・風・土など9つの元素タイプで\n「自分ってこういう人間なんだ」\nという気づきが生まれます。\n\n性格が確定すると、キャラクターの返答・\n日記・自分会議にも反映されていきます。',
    ),
    _OnboardingPage(
      icon: Icons.groups,
      title: '6人の自分で悩みを解決',
      body: '悩みを入力すると、あなたの性格を持った\n6人の分身が会議を開きます。\n\n「論理派の自分」「感情派の自分」が\nリアルに議論するから、\nどこか納得感がある答えが見つかります。',
    ),
    _OnboardingPage(
      icon: Icons.edit_calendar_outlined,
      title: 'チャットで予定・メモ・タスクも',
      body: '"明日14時に会議"と送ると予定を自動登録。\n"メモして""タスクに追加して"も\n話すだけでOK。\n\nアプリのことがわからなければ\nチャットで質問するとキャラクターが答えます。',
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_outline,
      title: 'さあ、話しかけてみよう',
      body: 'まずはキャラクターにひと言\n送ってみてください。\n\n何気ない一言から、\nあなたの性格解析がはじまります。\n\n分析が進むほど、DARIASは\nあなたのことをもっとよく知っていきます。',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingPage({required this.icon, required this.title, required this.body});
}
