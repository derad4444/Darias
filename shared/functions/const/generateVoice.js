// functions/const/generateVoice.js
const {onCall} = require("firebase-functions/v2/https");
const {Storage} = require("@google-cloud/storage");
const textToSpeech = require("@google-cloud/text-to-speech");
const fs = require("fs").promises;
const path = require("path");

// Cloud Storage を使う場合
const storage = new Storage();
const bucketName = process.env.FIREBASE_STORAGE_BUCKET ||
  `${process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT}.appspot.com`;

/**
 * 音声生成Firebase関数
 */
exports.generateVoice = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 180,
      minInstances: 0,
    },
    async (request) => {
      const {data} = request;
      try {
        const {text, filename} = data;

        if (!text || !filename) {
          return {error: "Missing text or filename"};
        }

        const client = new textToSpeech.TextToSpeechClient();

        const request = {
          input: {text: text},
          voice: {
            languageCode: "ja-JP",
            name: "ja-JP-Neural2-B", // 男女で切替可
          },
          audioConfig: {
            audioEncoding: "MP3",
          },
        };

        const [response] = await client.synthesizeSpeech(request);

        const localPath = path.join("/tmp", filename);
        await fs.writeFile(localPath, response.audioContent, "binary");

        await storage.bucket(bucketName).upload(localPath, {
          destination: `voices/${filename}`,
        });

        const publicUrl = `https://storage.googleapis.com/${bucketName}/voices/${filename}`;

        console.log(`✅ 音声ファイル ${filename} をCloud Storageに保存しました。`);

        return {
          success: true,
          message: "Voice generated successfully",
          voiceUrl: publicUrl,
        };
      } catch (error) {
        console.error("🔥 Error in generateVoice:", error);
        return {error: "Internal server error"};
      }
    },
);
