import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// オンボーディング画面
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.smart_toy,
      iconColor: Colors.deepPurple,
      title: 'AIパートナーと一緒に',
      description: 'あなたの毎日をサポートする\nAIキャラクターと出会いましょう',
      backgroundColor: Colors.deepPurple.shade50,
    ),
    OnboardingPage(
      icon: Icons.chat_bubble_outline,
      iconColor: Colors.blue,
      title: '会話を楽しむ',
      description: 'キャラクターとの楽しい会話が\n自動で日記になります',
      backgroundColor: Colors.blue.shade50,
    ),
    OnboardingPage(
      icon: Icons.calendar_today,
      iconColor: Colors.green,
      title: '予定を管理',
      description: 'TODO、スケジュール、メモを\n一元管理できます',
      backgroundColor: Colors.green.shade50,
    ),
    OnboardingPage(
      icon: Icons.psychology,
      iconColor: Colors.orange,
      title: '自分を知る',
      description: 'BIG5性格診断で\n自分の性格を分析しましょう',
      backgroundColor: Colors.orange.shade50,
    ),
    OnboardingPage(
      icon: Icons.groups,
      iconColor: Colors.pink,
      title: '6人会議',
      description: 'AIキャラクターたちとの\n会議シミュレーションを体験',
      backgroundColor: Colors.pink.shade50,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text('スキップ'),
                ),
              ),
            ),

            // ページビュー
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageWidget(page: _pages[index]);
                },
              ),
            ),

            // インジケーターとボタン
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // ページインジケーター
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _PageIndicator(
                        isActive: index == _currentPage,
                        color: _pages[index].iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 次へ / 始めるボタン
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _currentPage == _pages.length - 1
                          ? _completeOnboarding
                          : _nextPage,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _pages[_currentPage].iconColor,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? '始める' : '次へ',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _completeOnboarding() {
    // TODO: オンボーディング完了フラグを保存
    context.go('/character-select');
  }
}

class OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Color backgroundColor;

  OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.backgroundColor,
  });
}

class _OnboardingPageWidget extends StatelessWidget {
  final OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: page.backgroundColor,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.iconColor.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.iconColor,
            ),
          ),
          const SizedBox(height: 48),

          // タイトル
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: page.iconColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 説明
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black87,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _PageIndicator({
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
