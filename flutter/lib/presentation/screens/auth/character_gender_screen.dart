import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../main/main_shell_screen.dart';

/// Google / Apple で初めてサインインした人に、キャラクターの性別を選んでもらう画面
///
/// メール登録には性別の選択欄があるが、Google・Appleのサインインには入力欄が無い。
/// ここを通さないと、キャラクターの性別が決まらないままデータが作られてしまう。
class CharacterGenderScreen extends ConsumerStatefulWidget {
  const CharacterGenderScreen({super.key});

  @override
  ConsumerState<CharacterGenderScreen> createState() =>
      _CharacterGenderScreenState();
}

class _CharacterGenderScreenState extends ConsumerState<CharacterGenderScreen> {
  static const _genderOptions = ['男性', '女性'];

  String _selectedGender = '女性';
  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _handleStart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeInitialSetup(characterGender: _selectedGender);
      if (!mounted) return;
      ref.read(selectedTabProvider.notifier).state = homeTabIndex;
      context.go('/');
    } catch (e) {
      debugPrint('初期設定エラー: $e');
      if (mounted) {
        setState(() => _errorMessage = 'データの作成に失敗しました。通信環境を確認してもう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'はじめまして',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'これから対話するキャラクターの性別を選んでください',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: _genderOptions.map((gender) {
                        final isSelected = _selectedGender == gender;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedGender = gender),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                gender,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA084CA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          : const Text(
                              'はじめる',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isLoading ? null : _handleSignOut,
                    child: Text(
                      '別のアカウントでやり直す',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
