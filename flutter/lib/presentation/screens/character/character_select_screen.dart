import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/character_model.dart';
import '../../providers/auth_provider.dart';

class CharacterSelectScreen extends ConsumerStatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  ConsumerState<CharacterSelectScreen> createState() =>
      _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends ConsumerState<CharacterSelectScreen> {
  CharacterGender? _selectedGender;
  bool _isLoading = false;

  Future<void> _handleSelect() async {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('性別を選択してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final firestore = ref.read(firestoreProvider);
      final now = DateTime.now();

      // キャラクターを作成
      final characterRef = firestore
          .collection('users')
          .doc(userId)
          .collection('characters')
          .doc();

      final character = CharacterModel(
        id: characterRef.id,
        name: _selectedGender == CharacterGender.male ? '彼' : '彼女',
        gender: _selectedGender!,
        createdAt: now,
        updatedAt: now,
      );

      await characterRef.set(character.toMap());

      // ユーザードキュメントを更新
      await firestore.collection('users').doc(userId).update({
        'characterId': characterRef.id,
        'hasCompletedOnboarding': true,
        'updatedAt': now,
      });

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('キャラクター選択'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'パートナーを選んでください',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'あなたの相棒となるキャラクターの性別を選択してください',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 性別選択
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _GenderCard(
                        gender: CharacterGender.male,
                        isSelected: _selectedGender == CharacterGender.male,
                        onTap: () {
                          setState(() => _selectedGender = CharacterGender.male);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _GenderCard(
                        gender: CharacterGender.female,
                        isSelected: _selectedGender == CharacterGender.female,
                        onTap: () {
                          setState(
                              () => _selectedGender = CharacterGender.female);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 選択ボタン
              FilledButton(
                onPressed: _selectedGender == null || _isLoading
                    ? null
                    : _handleSelect,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('この相棒と始める'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final CharacterGender gender;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.gender,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = gender == CharacterGender.male;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (isMale ? Colors.blue[50] : Colors.pink[50])
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isMale ? Colors.blue : Colors.pink)
                : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMale ? Icons.face : Icons.face_3,
              size: 80,
              color: isSelected
                  ? (isMale ? Colors.blue : Colors.pink)
                  : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isMale ? '男性' : '女性',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isMale ? Colors.blue : Colors.pink)
                        : Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isMale ? '彼があなたをサポート' : '彼女があなたをサポート',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
