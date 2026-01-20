import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/services/ad_service.dart';
import 'data/services/notification_service.dart';
import 'firebase_options.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // バックグラウンドメッセージハンドラを設定
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 広告SDK初期化（Webでは不要）
  if (!kIsWeb) {
    await AdService().initialize();
  }

  // 通知サービス初期化（Webでは不要）
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(
    const ProviderScope(
      child: DariasApp(),
    ),
  );
}

class DariasApp extends ConsumerWidget {
  const DariasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorSeed = ref.watch(colorSeedProvider);

    return MaterialApp.router(
      title: 'DARIAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorSeed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // 日本語フォント設定
        fontFamily: 'Hiragino Sans',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorSeed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Hiragino Sans',
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
