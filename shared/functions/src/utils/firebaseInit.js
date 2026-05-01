// src/utils/firebaseInit.js - 完全遅延初期化版

let adminInstance = null;
let firestoreInstance = null;

/**
 * Firebase Admin SDKの完全遅延初期化
 * 初回使用時のみ初期化される
 */
function getAdmin() {
  if (!adminInstance) {
    const admin = require("firebase-admin");
    // admin.apps.length ではなくデフォルトアプリの存在を確認する。
    // Firebase Functions v2 ランタイムが内部的に名前付きアプリを初期化するため
    // apps.length > 0 でもデフォルトアプリが存在しないケースがある。
    try {
      admin.app();
    } catch (e) {
      admin.initializeApp();
    }
    adminInstance = admin;
  }
  return adminInstance;
}

/**
 * Firestoreインスタンスの遅延取得
 */
function getFirestore() {
  if (!firestoreInstance) {
    const admin = getAdmin();
    firestoreInstance = admin.firestore();
  }
  return firestoreInstance;
}

/**
 * レガシー互換性のため
 */
function initializeFirebase() {
  return getAdmin();
}

module.exports = {
  initializeFirebase,
  getFirestore,
  get admin() {
    return getAdmin();
  },
};
