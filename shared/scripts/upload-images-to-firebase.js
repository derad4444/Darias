#!/usr/bin/env node

/**
 * Firebase Storageへ画像をアップロードするスクリプト
 *
 * 使用方法:
 * 1. Firebase Admin SDKの認証情報を設定
 * 2. node upload-images-to-firebase.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Firebase Admin SDKの初期化
// サービスアカウントキーのパスを指定してください
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY || './serviceAccountKey.json';

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ サービスアカウントキーが見つかりません: ' + serviceAccountPath);
  console.error('環境変数 FIREBASE_SERVICE_ACCOUNT_KEY を設定するか、serviceAccountKey.json を配置してください。');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

// バケット名を環境変数または自動検出
const storageBucket = process.env.FIREBASE_STORAGE_BUCKET || `${serviceAccount.project_id}.firebasestorage.app`;

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: storageBucket
});

const bucket = admin.storage().bucket();

console.log(`📦 使用するStorage Bucket: ${storageBucket}\n`);

// Assets.xcassetsのパス
const assetsPath = path.join(__dirname, '../Character/Assets.xcassets');

// アップロード対象のパターン
const genderPatterns = {
  female: /^Female_[LMHLMH]{5}\.imageset$/,
  male: /^Male_[LMHLMH]{5}\.imageset$/
};

/**
 * imagesetディレクトリから画像ファイルを取得
 */
function getImageFromImageset(imagesetPath) {
  const files = fs.readdirSync(imagesetPath);
  const imageFile = files.find(file => file.endsWith('.png') || file.endsWith('.jpg') || file.endsWith('.jpeg'));

  if (!imageFile) {
    return null;
  }

  return path.join(imagesetPath, imageFile);
}

/**
 * Firebase Storageにアップロード
 */
async function uploadImage(localPath, storagePath) {
  try {
    await bucket.upload(localPath, {
      destination: storagePath,
      metadata: {
        contentType: 'image/png',
        cacheControl: 'public, max-age=31536000', // 1年間キャッシュ
      }
    });
    console.log(`✅ アップロード成功: ${storagePath}`);
    return true;
  } catch (error) {
    console.error(`❌ アップロード失敗: ${storagePath}`, error.message);
    return false;
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('🚀 Firebase Storageへの画像アップロードを開始します...\n');

  if (!fs.existsSync(assetsPath)) {
    console.error('❌ Assets.xcassetsが見つかりません: ' + assetsPath);
    process.exit(1);
  }

  const dirs = fs.readdirSync(assetsPath);

  let uploadCount = 0;
  let failCount = 0;
  let skipCount = 0;

  for (const dir of dirs) {
    const fullPath = path.join(assetsPath, dir);

    if (!fs.statSync(fullPath).isDirectory()) {
      continue;
    }

    // 性別とパターンをチェック
    let gender = null;
    let pattern = null;

    if (genderPatterns.female.test(dir)) {
      gender = 'female';
      pattern = dir.match(/^(Female_[LMHLMH]{5})\.imageset$/)[1];
    } else if (genderPatterns.male.test(dir)) {
      gender = 'male';
      pattern = dir.match(/^(Male_[LMHLMH]{5})\.imageset$/)[1];
    } else {
      // アップロード対象外
      skipCount++;
      continue;
    }

    // imagesetから画像ファイルを取得
    const imagePath = getImageFromImageset(fullPath);

    if (!imagePath) {
      console.warn(`⚠️ 画像ファイルが見つかりません: ${dir}`);
      failCount++;
      continue;
    }

    // Firebase Storageのパスを生成
    const storagePath = `character-images/${gender}/${pattern}.png`;

    // アップロード
    const success = await uploadImage(imagePath, storagePath);

    if (success) {
      uploadCount++;
    } else {
      failCount++;
    }

    // 少し待機（レート制限対策）
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  console.log('\n📊 アップロード結果:');
  console.log(`   成功: ${uploadCount}件`);
  console.log(`   失敗: ${failCount}件`);
  console.log(`   スキップ: ${skipCount}件`);
  console.log('\n✨ 完了しました！');
}

// デフォルト画像もアップロード
async function uploadDefaultImages() {
  console.log('\n📦 デフォルト画像をアップロード中...');

  const defaultImages = [
    { local: 'character_female.imageset', storage: 'character-images/defaults/character_female.png' },
    { local: 'character_male.imageset', storage: 'character-images/defaults/character_male.png' }
  ];

  for (const { local, storage } of defaultImages) {
    const imagesetPath = path.join(assetsPath, local);

    if (!fs.existsSync(imagesetPath)) {
      console.warn(`⚠️ デフォルト画像が見つかりません: ${local}`);
      continue;
    }

    const imagePath = getImageFromImageset(imagesetPath);

    if (imagePath) {
      await uploadImage(imagePath, storage);
    }
  }
}

// 実行
(async () => {
  try {
    await main();
    await uploadDefaultImages();
    process.exit(0);
  } catch (error) {
    console.error('❌ エラーが発生しました:', error);
    process.exit(1);
  }
})();
