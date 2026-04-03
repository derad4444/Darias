import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// iOS版ContactViewと同じデザインのお問い合わせ画面
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _messageController = TextEditingController();
  ContactCategory _selectedCategory = ContactCategory.other;
  bool _isLoading = false;
  static const int _maxMessageLength = 1000;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';

    String deviceModel = '不明';
    String iosVersion = '不明';
    String deviceName = '不明';

    if (!kIsWeb) {
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceModel = iosInfo.model;
        iosVersion = iosInfo.systemVersion;
        deviceName = iosInfo.name;
      } catch (_) {}
    }

    return {
      'appVersion': appVersion,
      'iosVersion': iosVersion,
      'deviceModel': deviceModel,
      'deviceName': deviceName,
    };
  }

  bool get _isFormValid {
    final message = _messageController.text.trim();
    return message.isNotEmpty && message.length <= _maxMessageLength;
  }

  Future<void> _sendContact() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(userDocProvider).valueOrNull;
      final userId = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final userEmail = user?.email ?? '';
      final userName = user?.name ?? '';

      final contactId = DateTime.now().millisecondsSinceEpoch.toString();
      final contactData = {
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'category': _selectedCategory.name,
        'categoryDisplay': _selectedCategory.displayName,
        'subject': _selectedCategory.emailSubject,
        'message': _messageController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'adminEmailSent': false,
        'userEmailSent': false,
        'deviceInfo': await _getDeviceInfo(),
      };

      await ref.read(firestoreProvider)
          .collection('contacts')
          .doc(contactId)
          .set(contactData);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('送信完了'),
            content: const Text(
              '問い合わせメールを送信しました。\n\n'
              '・確認メールが届いているかご確認ください\n'
              '・迷惑メールフォルダもチェックしてください\n'
              '・通常2-3営業日以内に返答いたします',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop();
                },
                child: const Text('確認'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('送信エラー'),
            content: Text('お問い合わせの送信に失敗しました: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
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
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final textColor = colorSettings.textColor;
    final accentColor = colorSettings.accentColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ナビゲーションヘッダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    // 閉じるボタン
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.close, color: textColor),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),

                    const Spacer(),

                    // タイトル
                    Text(
                      'お問い合わせ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    const Spacer(),

                    // 送信ボタン
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: _isFormValid ? _sendContact : null,
                        child: Text(
                          '送信',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _isFormValid
                                ? accentColor
                                : textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // メインコンテンツ
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 8),

                    // カテゴリ選択
                    Text(
                      'お問い合わせ種類',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CategoryDropdown(
                      selectedCategory: _selectedCategory,
                      textColor: textColor,
                      onChanged: (category) {
                        setState(() => _selectedCategory = category);
                      },
                    ),

                    const SizedBox(height: 24),

                    // メッセージ入力
                    Text(
                      'お問い合わせ内容',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 6,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'お問い合わせ内容を入力してください',
                          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 文字数カウント
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_messageController.text.length} / $_maxMessageLength',
                        style: TextStyle(
                          fontSize: 12,
                          color: _messageController.text.length > _maxMessageLength
                              ? Colors.red
                              : textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// カテゴリドロップダウン
class _CategoryDropdown extends StatelessWidget {
  final ContactCategory selectedCategory;
  final Color textColor;
  final ValueChanged<ContactCategory> onChanged;

  const _CategoryDropdown({
    required this.selectedCategory,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCategoryPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              selectedCategory.displayName,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.keyboard_arrow_down,
              color: textColor.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'お問い合わせ種類',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: ContactCategory.values.map((category) => ListTile(
                      title: Text(category.displayName),
                      trailing: selectedCategory == category
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        onChanged(category);
                        Navigator.pop(context);
                      },
                    )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// お問い合わせカテゴリ
enum ContactCategory {
  bug,
  feature,
  usage,
  account,
  personality,
  calendar,
  character,
  premium,
  other;

  String get displayName {
    switch (this) {
      case ContactCategory.bug:
        return 'バグ報告・不具合';
      case ContactCategory.feature:
        return '機能要望・改善提案';
      case ContactCategory.usage:
        return '使い方・操作方法';
      case ContactCategory.account:
        return 'アカウント・ログイン';
      case ContactCategory.personality:
        return 'AI性格診断について';
      case ContactCategory.calendar:
        return 'カレンダー・予定管理';
      case ContactCategory.character:
        return 'キャラクター機能';
      case ContactCategory.premium:
        return 'プレミアム機能・課金';
      case ContactCategory.other:
        return 'その他';
    }
  }

  String get emailSubject => '【DARIAS】$displayName';
}
