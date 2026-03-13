import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// キャラクター性別
enum CharacterGender {
  male('male'),
  female('female');

  final String value;
  const CharacterGender(this.value);
}

/// Firebase Storageからキャラクター画像を取得・管理するサービス
class FirebaseImageService {
  static final FirebaseImageService shared = FirebaseImageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  Directory? _cacheDirectory;
  bool _isInitialized = false;

  // キャッシュ設定
  static const int _maxCacheSize = 500 * 1024 * 1024; // 500MB
  static const int _cacheExpirationDays = 30;

  // ダウンロード中の画像を追跡
  final Map<String, Future<Uint8List>> _downloadTasks = {};

  // メモリキャッシュ（Web用）
  final Map<String, Uint8List> _memoryCache = {};

  // URLキャッシュ（Firebase Storage APIへのリクエストを削減）
  final Map<String, String> _urlCache = {};

  FirebaseImageService._();

  /// 初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Webではpath_providerが使えないのでメモリキャッシュのみ
    if (!kIsWeb) {
      try {
        final cacheDir = await getApplicationCacheDirectory();
        _cacheDirectory = Directory('${cacheDir.path}/CharacterImages');

        if (!await _cacheDirectory!.exists()) {
          await _cacheDirectory!.create(recursive: true);
        }

        // 起動時に期限切れキャッシュをクリーン
        await _cleanExpiredCache();
      } catch (e) {
        debugPrint('Failed to initialize file cache: $e');
      }
    }

    _isInitialized = true;
  }

  /// 画像を取得（キャッシュ優先）
  Future<Uint8List> fetchImage({
    required String fileName,
    required CharacterGender gender,
  }) async {
    // 初期化されていない場合は初期化
    if (!_isInitialized) {
      await initialize();
    }

    final cacheKey = '${gender.value}_$fileName';

    // 1. メモリキャッシュチェック（Web/モバイル共通）
    if (_memoryCache.containsKey(cacheKey)) {
      debugPrint('🖼️ メモリキャッシュから画像取得: $fileName');
      return _memoryCache[cacheKey]!;
    }

    // 2. ファイルキャッシュチェック（モバイルのみ）
    if (!kIsWeb) {
      final cachedImage = await _loadFromCache(cacheKey);
      if (cachedImage != null) {
        debugPrint('🖼️ ファイルキャッシュから画像取得: $fileName');
        _memoryCache[cacheKey] = cachedImage;
        return cachedImage;
      }
    }

    // 3. 既にダウンロード中かチェック
    if (_downloadTasks.containsKey(cacheKey)) {
      debugPrint('⏳ ダウンロード中の画像を待機: $fileName');
      return _downloadTasks[cacheKey]!;
    }

    // 4. 新規ダウンロードタスクを作成
    final task = _downloadImage(fileName: fileName, gender: gender)
        .then((data) async {
      // メモリキャッシュに保存
      _memoryCache[cacheKey] = data;

      // ファイルキャッシュに保存（モバイルのみ）
      if (!kIsWeb) {
        await _saveToCache(data, cacheKey);
      }

      _downloadTasks.remove(cacheKey);
      return data;
    }).catchError((error) {
      _downloadTasks.remove(cacheKey);
      throw error;
    });

    _downloadTasks[cacheKey] = task;
    return task;
  }

  /// 画像をプリロード（バックグラウンドダウンロード）
  Future<void> preloadImage({
    required String fileName,
    required CharacterGender gender,
  }) async {
    final cacheKey = '${gender.value}_$fileName';

    // 既にキャッシュにある場合はスキップ
    if (await _cacheExists(cacheKey)) {
      return;
    }

    try {
      await fetchImage(fileName: fileName, gender: gender);
      debugPrint('✅ プリロード完了: $fileName');
    } catch (e) {
      debugPrint('❌ プリロード失敗: $fileName - $e');
    }
  }

  /// 画像URLを取得（URLキャッシュ付き）
  Future<String> getImageUrl({
    required String fileName,
    required CharacterGender gender,
  }) async {
    final cacheKey = '${gender.value}_$fileName';
    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey]!;
    }
    final storagePath = 'character-images/${gender.value}/$fileName.png';
    final ref = _storage.ref().child(storagePath);
    final url = await ref.getDownloadURL();
    _urlCache[cacheKey] = url;
    return url;
  }

  /// キャッシュをクリア
  Future<void> clearCache() async {
    if (_cacheDirectory == null) return;

    final files = await _cacheDirectory!.list().toList();
    for (final file in files) {
      await file.delete();
    }
    debugPrint('🗑️ キャッシュをクリアしました');
  }

  /// キャッシュサイズを取得（バイト）
  Future<int> getCacheSize() async {
    if (_cacheDirectory == null) return 0;

    int totalSize = 0;
    final files = await _cacheDirectory!.list().toList();
    for (final file in files) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  /// キャッシュサイズを人間が読める形式で取得
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Firebase Storageから画像をダウンロード
  Future<Uint8List> _downloadImage({
    required String fileName,
    required CharacterGender gender,
  }) async {
    final storagePath = 'character-images/${gender.value}/$fileName.png';
    final ref = _storage.ref().child(storagePath);

    debugPrint('⬇️ Firebase Storageからダウンロード開始: $storagePath');

    try {
      // Webの場合はgetDownloadURLを使用してHTTP経由でダウンロード
      if (kIsWeb) {
        final url = await ref.getDownloadURL();
        debugPrint('📎 ダウンロードURL取得: $url');

        // HTTP経由で画像をダウンロード
        final response = await _httpGet(url);
        if (response != null) {
          debugPrint('✅ ダウンロード完了: $storagePath');
          return response;
        }
        throw FirebaseImageException.downloadFailed('HTTP download failed');
      } else {
        // モバイルの場合は直接getData
        const maxSize = 10 * 1024 * 1024;
        final data = await ref.getData(maxSize);

        if (data == null) {
          throw FirebaseImageException.invalidImageData();
        }

        debugPrint('✅ ダウンロード完了: $storagePath');
        return data;
      }
    } catch (e) {
      debugPrint('❌ ダウンロード失敗: $storagePath - $e');
      throw FirebaseImageException.downloadFailed(e.toString());
    }
  }

  /// HTTP経由で画像をダウンロード（Web用）
  Future<Uint8List?> _httpGet(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint('HTTP download failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('HTTP download error: $e');
    }
    return null;
  }

  /// キャッシュから画像を読み込み
  Future<Uint8List?> _loadFromCache(String cacheKey) async {
    if (_cacheDirectory == null) return null;

    final file = File('${_cacheDirectory!.path}/$cacheKey.png');

    if (!await file.exists()) {
      return null;
    }

    // ファイルの更新日時をチェック
    final stat = await file.stat();
    final daysSinceModification =
        DateTime.now().difference(stat.modified).inDays;

    if (daysSinceModification > _cacheExpirationDays) {
      // 期限切れのキャッシュは削除
      await file.delete();
      return null;
    }

    return await file.readAsBytes();
  }

  /// 画像をキャッシュに保存
  Future<void> _saveToCache(Uint8List data, String cacheKey) async {
    if (_cacheDirectory == null) return;

    final file = File('${_cacheDirectory!.path}/$cacheKey.png');

    try {
      await file.writeAsBytes(data);
      debugPrint('💾 キャッシュに保存: $cacheKey');

      // キャッシュサイズをチェックして必要に応じてクリーン
      await _checkCacheSizeAndClean();
    } catch (e) {
      debugPrint('❌ キャッシュ保存失敗: $cacheKey - $e');
    }
  }

  /// キャッシュが存在するかチェック
  Future<bool> _cacheExists(String cacheKey) async {
    if (_cacheDirectory == null) return false;

    final file = File('${_cacheDirectory!.path}/$cacheKey.png');
    return await file.exists();
  }

  /// 期限切れキャッシュをクリーン
  Future<void> _cleanExpiredCache() async {
    if (_cacheDirectory == null) return;

    final expirationDate =
        DateTime.now().subtract(const Duration(days: _cacheExpirationDays));

    final files = await _cacheDirectory!.list().toList();
    for (final file in files) {
      if (file is File) {
        final stat = await file.stat();
        if (stat.modified.isBefore(expirationDate)) {
          await file.delete();
        }
      }
    }
  }

  /// キャッシュサイズをチェックして制限を超えていたら古いファイルを削除
  Future<void> _checkCacheSizeAndClean() async {
    final currentSize = await getCacheSize();

    if (currentSize <= _maxCacheSize) {
      return;
    }

    debugPrint('⚠️ キャッシュサイズが制限を超えています: ${await getCacheSizeFormatted()}');

    if (_cacheDirectory == null) return;

    // 古いファイルから削除
    final files = await _cacheDirectory!.list().toList();
    final fileStats = <FileSystemEntity, FileStat>{};

    for (final file in files) {
      if (file is File) {
        fileStats[file] = await file.stat();
      }
    }

    final sortedFiles = files
      ..sort((a, b) {
        final statA = fileStats[a];
        final statB = fileStats[b];
        if (statA == null || statB == null) return 0;
        return statA.modified.compareTo(statB.modified);
      });

    int currentSizeAfterClean = currentSize;
    for (final file in sortedFiles) {
      if (currentSizeAfterClean <= _maxCacheSize) {
        break;
      }

      if (file is File) {
        final size = await file.length();
        await file.delete();
        currentSizeAfterClean -= size;
      }
    }

    debugPrint('🗑️ キャッシュクリーン完了');
  }
}

/// Firebase画像エラー
class FirebaseImageException implements Exception {
  final String message;

  FirebaseImageException._(this.message);

  factory FirebaseImageException.invalidImageData() {
    return FirebaseImageException._('画像データが無効です');
  }

  factory FirebaseImageException.downloadFailed(String error) {
    return FirebaseImageException._('ダウンロードに失敗しました: $error');
  }

  factory FirebaseImageException.cacheError() {
    return FirebaseImageException._('キャッシュエラーが発生しました');
  }

  @override
  String toString() => message;
}
