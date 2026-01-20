import 'package:flutter/material.dart';

/// 確認ダイアログを表示するユーティリティ
class ConfirmDialog {
  /// シンプルな確認ダイアログを表示
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText ?? 'キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText ?? 'OK'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 削除確認ダイアログを表示
  static Future<bool> showDelete({
    required BuildContext context,
    required String itemName,
  }) async {
    return show(
      context: context,
      title: '削除の確認',
      content: '「$itemName」を削除しますか？この操作は取り消せません。',
      confirmText: '削除',
      isDestructive: true,
    );
  }

  /// ログアウト確認ダイアログを表示
  static Future<bool> showLogout({
    required BuildContext context,
  }) async {
    return show(
      context: context,
      title: 'ログアウト',
      content: 'ログアウトしますか？',
      confirmText: 'ログアウト',
    );
  }

  /// 破棄確認ダイアログを表示
  static Future<bool> showDiscard({
    required BuildContext context,
  }) async {
    return show(
      context: context,
      title: '変更の破棄',
      content: '保存されていない変更があります。変更を破棄しますか？',
      confirmText: '破棄',
      isDestructive: true,
    );
  }

  /// カスタムアクション付きダイアログを表示
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: actions,
      ),
    );
  }
}

/// 入力ダイアログを表示するユーティリティ
class InputDialog {
  /// テキスト入力ダイアログを表示
  static Future<String?> showText({
    required BuildContext context,
    required String title,
    String? hintText,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            validator: validator,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText ?? 'キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text);
              }
            },
            child: Text(confirmText ?? 'OK'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }
}

/// 選択ダイアログを表示するユーティリティ
class SelectDialog {
  /// 単一選択ダイアログを表示
  static Future<T?> showSingle<T>({
    required BuildContext context,
    required String title,
    required List<SelectOption<T>> options,
    T? selectedValue,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              final isSelected = option.value == selectedValue;
              return ListTile(
                leading: option.icon != null ? Icon(option.icon) : null,
                title: Text(option.label),
                subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                selected: isSelected,
                onTap: () => Navigator.pop(context, option.value),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// 選択オプション
class SelectOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}
