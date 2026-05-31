import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:darias/presentation/providers/game_provider.dart';
import 'package:darias/presentation/widgets/character/element_effect_widget.dart';

class GameLobbyScreen extends ConsumerStatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  ConsumerState<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends ConsumerState<GameLobbyScreen> {
  final _p1NameCtrl = TextEditingController(text: 'プレイヤー1');
  final _p2NameCtrl = TextEditingController(text: 'プレイヤー2');
  ElementType _p1Element = ElementType.fire;
  ElementType _p2Element = ElementType.water;

  @override
  void dispose() {
    _p1NameCtrl.dispose();
    _p2NameCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    if (_p1NameCtrl.text.trim().isEmpty || _p2NameCtrl.text.trim().isEmpty) {
      return;
    }
    ref.read(gameProvider.notifier).startGame(
          p1Name: _p1NameCtrl.text.trim(),
          p1Element: _p1Element,
          p2Name: _p2NameCtrl.text.trim(),
          p2Element: _p2Element,
        );
    context.push('/game/battle');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          '元素陣取り対戦',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タイトル
            const Center(
              child: Column(
                children: [
                  Text('⚔️', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 8),
                  Text(
                    '認知戦型・元素陣取りカードゲーム',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '5×5の盤面を属性カードで占領せよ',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Player 1
            _PlayerSetupCard(
              label: 'プレイヤー 1',
              accentColor: Colors.blue.shade400,
              nameController: _p1NameCtrl,
              selectedElement: _p1Element,
              onElementChanged: (e) => setState(() => _p1Element = e),
              disableElement: _p2Element,
            ),

            const SizedBox(height: 16),

            Center(
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.2),
                  letterSpacing: 4,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Player 2
            _PlayerSetupCard(
              label: 'プレイヤー 2',
              accentColor: Colors.red.shade400,
              nameController: _p2NameCtrl,
              selectedElement: _p2Element,
              onElementChanged: (e) => setState(() => _p2Element = e),
              disableElement: _p1Element,
            ),

            const SizedBox(height: 32),

            // ルール説明
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📖 ルール',
                      style: TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _RuleRow('• 5×5ボードを属性カードで占領'),
                  _RuleRow('• 各ターン同時にカードとマスを選択'),
                  _RuleRow('• 同じマスに配置 → 攻撃力で決着'),
                  _RuleRow('• 属性相性で攻撃力+1ボーナス'),
                  _RuleRow('• 15ターン後、より多いマスを持つ方が勝利'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 開始ボタン
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C3FC7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'ゲームスタート',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PlayerSetupCard extends StatelessWidget {
  final String label;
  final Color accentColor;
  final TextEditingController nameController;
  final ElementType selectedElement;
  final ValueChanged<ElementType> onElementChanged;
  final ElementType? disableElement;

  const _PlayerSetupCard({
    required this.label,
    required this.accentColor,
    required this.nameController,
    required this.selectedElement,
    required this.onElementChanged,
    this.disableElement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '名前を入力',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Text('属性を選択',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ElementType.values
                .where((e) => e != ElementType.none)
                .map((e) {
              final isSelected = selectedElement == e;
              final isDisabled = disableElement == e;
              return GestureDetector(
                onTap: isDisabled ? null : () => onElementChanged(e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? e.color.withOpacity(0.7)
                        : isDisabled
                            ? Colors.black26
                            : e.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? e.color
                          : isDisabled
                              ? Colors.white12
                              : e.color.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    '${_elementEmoji(e)} ${e.label}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDisabled ? Colors.white24 : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String text;
  const _RuleRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(text,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}

String _elementEmoji(ElementType e) => switch (e) {
      ElementType.fire    => '🔥',
      ElementType.water   => '💧',
      ElementType.wind    => '🌀',
      ElementType.earth   => '🪨',
      ElementType.ice     => '❄️',
      ElementType.thunder => '⚡',
      ElementType.light   => '✨',
      ElementType.dark    => '🌑',
      ElementType.none    => '⭕',
    };
