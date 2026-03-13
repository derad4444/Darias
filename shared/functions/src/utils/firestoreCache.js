// src/utils/firestoreCache.js
// Cloud Functions インスタンス内でのメモリキャッシュ（TTL付き）
// 同一インスタンムへのウォームリクエスト間でキャッシュが共有される

const DEFAULT_TTL_MS = 5 * 60 * 1000; // 5分

class FirestoreCache {
  constructor() {
    this._cache = new Map();
  }

  /**
   * キャッシュにデータを保存
   * @param {string} key - キャッシュキー
   * @param {*} value - 保存する値（null も有効）
   * @param {number} ttlMs - TTL（ミリ秒）
   */
  set(key, value, ttlMs = DEFAULT_TTL_MS) {
    this._cache.set(key, {
      value,
      expiresAt: Date.now() + ttlMs,
    });
  }

  /**
   * キャッシュからデータを取得
   * @param {string} key
   * @returns {*} キャッシュヒット時はvalue、ミス時はundefined
   */
  get(key) {
    const entry = this._cache.get(key);
    if (!entry) return undefined;
    if (Date.now() > entry.expiresAt) {
      this._cache.delete(key);
      return undefined;
    }
    return entry.value;
  }

  /**
   * 指定キーのキャッシュを削除（書き込み後に呼ぶ）
   * @param {string} key
   */
  invalidate(key) {
    this._cache.delete(key);
  }

  /**
   * キャッシュサイズを取得（デバッグ用）
   */
  get size() {
    return this._cache.size;
  }
}

// モジュールシングルトンとしてエクスポート（インスタンス間で共有）
module.exports = new FirestoreCache();
