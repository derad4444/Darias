// functions/const/generateVoice.js
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {Storage} = require("@google-cloud/storage");
const textToSpeech = require("@google-cloud/text-to-speech");
const fs = require("fs").promises;
const path = require("path");
const crypto = require("crypto");

const storage = new Storage();
const bucketName = process.env.FIREBASE_STORAGE_BUCKET ||
  `${process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT}.firebasestorage.app`;

// 性別に応じた音声名（Google Cloud TTS Neural2）
const VOICE_MAP = {
  female: "ja-JP-Neural2-B", // 女性
  male: "ja-JP-Neural2-D",   // 男性
};

/**
 * キャラクター音声生成 Cloud Function
 * テキストをMP3に変換しCloud Storageにキャッシュして返す
 */
exports.generateVoice = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 60,
      minInstances: 0,
    },
    async (request) => {
      // 認証チェック
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "認証が必要です");
      }

      const {text, gender = "female"} = request.data;

      if (!text || typeof text !== "string" || text.trim().length === 0) {
        throw new HttpsError("invalid-argument", "テキストが必要です");
      }

      // 500文字に制限
      const trimmedText = text.trim().substring(0, 500);
      const voiceName = VOICE_MAP[gender] || VOICE_MAP.female;

      // テキスト+音声名のハッシュでキャッシュキーを生成
      const hash = crypto.createHash("md5")
          .update(trimmedText + voiceName)
          .digest("hex");
      const storageFile = `voices/${hash}.mp3`;

      const bucket = storage.bucket(bucketName);
      const file = bucket.file(storageFile);

      const publicUrl =
        `https://storage.googleapis.com/${bucketName}/${storageFile}`;

      try {
        // キャッシュが存在すれば公開URLを返す
        const [exists] = await file.exists();
        if (exists) {
          console.log(`✅ キャッシュから音声返却: ${hash}`);
          return {voiceUrl: publicUrl, cached: true};
        }

        // Google Cloud TTS で音声生成
        const client = new textToSpeech.TextToSpeechClient();
        const ttsRequest = {
          input: {text: trimmedText},
          voice: {
            languageCode: "ja-JP",
            name: voiceName,
          },
          audioConfig: {
            audioEncoding: "MP3",
            speakingRate: 1.0,
            pitch: 0,
          },
        };

        const [response] = await client.synthesizeSpeech(ttsRequest);

        const localPath = path.join("/tmp", `${hash}.mp3`);
        await fs.writeFile(localPath, response.audioContent, "binary");

        await bucket.upload(localPath, {
          destination: storageFile,
          metadata: {
            contentType: "audio/mpeg",
            cacheControl: "public, max-age=86400",
          },
        });

        // ファイルを公開アクセス可能にする
        await file.makePublic();

        console.log(`✅ 音声生成・保存完了: ${hash} (${voiceName})`);
        return {voiceUrl: publicUrl, cached: false};
      } catch (error) {
        console.error("🔥 generateVoice エラー:", error);
        throw new HttpsError("internal", "音声生成に失敗しました");
      }
    },
);
