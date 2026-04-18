import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 2), () => _navigate());
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final hasSeenSlides = doc.data()?['hasSeenOnboardingSlides'] as bool? ?? false;
      if (mounted) {
        context.go(hasSeenSlides ? '/' : '/onboarding');
        return;
      }
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: kIsWeb ? null : () => _navigate(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // バージョン表記（左上）
              Positioned(
                top: 16,
                left: 16,
                child: Text(
                  _version.isEmpty ? '' : 'Ver$_version',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),

              // メインコンテンツ（中央）
              SizedBox.expand(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 280,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    if (!kIsWeb)
                      const Text(
                        '画面をタップしてはじめる',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Text(
                        '© 2025 AS WANT LLC',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
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
