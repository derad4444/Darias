import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';

class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await ref
        .read(friendControllerProvider.notifier)
        .searchUsers(query.trim());
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios, color: accentColor),
                    ),
                    Text(
                      'フレンドを追加',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              // タブ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: accentColor,
                    unselectedLabelColor: AppColors.textLight,
                    indicator: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '検索'),
                      Tab(text: 'QRコード'),
                    ],
                  ),
                ),
              ),

              // タブコンテンツ
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SearchTab(
                      controller: _searchController,
                      results: _searchResults,
                      isSearching: _isSearching,
                      accentColor: accentColor,
                      onSearch: _search,
                    ),
                    _QrTab(accentColor: accentColor),
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

/// 検索タブ
class _SearchTab extends ConsumerWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> results;
  final bool isSearching;
  final Color accentColor;
  final Future<void> Function(String) onSearch;

  const _SearchTab({
    required this.controller,
    required this.results,
    required this.isSearching,
    required this.accentColor,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // 検索フィールド
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '名前またはメールアドレスで検索',
              prefixIcon: Icon(Icons.search, color: accentColor),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.85),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: onSearch,
            onChanged: (v) {
              if (v.isEmpty) onSearch('');
            },
          ),
        ),

        if (isSearching)
          const CircularProgressIndicator()
        else if (results.isEmpty && controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'ユーザーが見つかりませんでした',
              style: TextStyle(color: AppColors.textLight),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (ctx, i) {
                final user = results[i];
                return _UserResultCard(
                  userId: user['id'] as String,
                  name: user['name'] as String,
                  email: user['email'] as String,
                  accentColor: accentColor,
                );
              },
            ),
          ),
      ],
    );
  }
}

/// ユーザー検索結果カード
class _UserResultCard extends ConsumerWidget {
  final String userId;
  final String name;
  final String email;
  final Color accentColor;

  const _UserResultCard({
    required this.userId,
    required this.name,
    required this.email,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDocProvider);
    final friendsAsync = ref.watch(friendsProvider);

    final myUser = userAsync.valueOrNull;
    final friends = friendsAsync.valueOrNull ?? [];
    final isAlreadyFriend = friends.any((f) => f.id == userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: accentColor.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(email, style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          if (isAlreadyFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'フレンド',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ElevatedButton(
              onPressed: myUser == null
                  ? null
                  : () async {
                      await ref
                          .read(friendControllerProvider.notifier)
                          .sendFriendRequest(
                            toUserId: userId,
                            toUserName: name,
                            myName: myUser.name ?? '',
                            myEmail: myUser.email,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('フレンド申請を送りました')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('申請', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// QRコードタブ
class _QrTab extends ConsumerStatefulWidget {
  final Color accentColor;
  const _QrTab({required this.accentColor});

  @override
  ConsumerState<_QrTab> createState() => _QrTabState();
}

class _QrTabState extends ConsumerState<_QrTab> {
  bool _showScanner = false;
  bool _scanned = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDocProvider);
    final userId = userAsync.valueOrNull?.id ?? '';

    if (_showScanner) {
      return _buildScanner(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 自分のQRコード
          Text(
            '自分のQRコードを見せる',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '相手にスキャンしてもらいましょう',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (userId.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: 'darias://friend?userId=$userId',
                version: QrVersions.auto,
                size: 220,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: widget.accentColor,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: widget.accentColor,
                ),
              ),
            )
          else
            const CircularProgressIndicator(),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),

          // QRスキャンボタン
          Text(
            '相手のQRコードをスキャン',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '相手のQRコードを読み取ります',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showScanner = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('カメラを起動', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final userAsync = ref.watch(userDocProvider);
    final myUser = userAsync.valueOrNull;

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) async {
            if (_scanned) return;
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final raw = barcode.rawValue;
              if (raw == null) continue;
              final uri = Uri.tryParse(raw);
              if (uri == null) continue;
              if (uri.scheme == 'darias' && uri.host == 'friend') {
                final friendId = uri.queryParameters['userId'];
                if (friendId == null || friendId.isEmpty) continue;
                _scanned = true;

                // フレンド情報を取得して申請
                try {
                  final firestore = ref.read(firestoreProvider);
                  final doc = await firestore.collection('users').doc(friendId).get();
                  if (!doc.exists) return;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? '';

                  await ref.read(friendControllerProvider.notifier).sendFriendRequest(
                    toUserId: friendId,
                    toUserName: name,
                    myName: myUser?.name ?? '',
                    myEmail: myUser?.email ?? '',
                  );

                  if (context.mounted) {
                    setState(() => _showScanner = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$nameさんにフレンド申請を送りました')),
                    );
                  }
                } catch (e) {
                  _scanned = false;
                }
              }
            }
          },
        ),
        // オーバーレイ
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: widget.accentColor, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'QRコードを枠内に合わせてください',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        // 閉じるボタン
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _showScanner = false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
