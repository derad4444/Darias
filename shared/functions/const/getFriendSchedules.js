// functions/const/getFriendSchedules.js
// フレンドの共有スケジュールを取得する Cloud Function

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");

const db = getFirestore();

exports.getFriendSchedules = onCall(
    {region: "asia-northeast1", memory: "256MiB", timeoutSeconds: 30, enforceAppCheck: false},
    async (request) => {
      const {auth} = request;
      if (!auth) return {error: "Unauthorized"};

      const callerId = auth.uid;
      const {friendId, year, month} = request.data;

      if (!friendId || !year || !month) return {schedules: []};

      // フレンドが自分に共有しているか確認
      // users/{friendId}/friends/{callerId} の shareLevel を参照
      const friendDoc = await db
          .collection("users").doc(friendId)
          .collection("friends").doc(callerId)
          .get();

      if (!friendDoc.exists) return {schedules: []};

      const shareLevel = friendDoc.data().shareLevel;
      if (!shareLevel || shareLevel === "none") return {schedules: []};

      // 指定月のスケジュールを取得
      const firstDay = new Date(year, month - 1, 1);
      const lastDay = new Date(year, month, 0, 23, 59, 59);

      const snapshot = await db
          .collection("users").doc(friendId)
          .collection("schedules")
          .where("startDate", ">=", firstDay)
          .where("startDate", "<=", lastDay)
          .get();

      // タグ情報（色・非公開フラグ）を一括取得
      const tagsSnapshot = await db
          .collection("users").doc(friendId)
          .collection("tags")
          .get();
      const tagColorMap = {}; // name → colorHex
      const privateTags = new Set();
      tagsSnapshot.docs.forEach((doc) => {
        const t = doc.data();
        if (t.name) tagColorMap[t.name] = t.colorHex || null;
        // isPublicフィールドがあればそちらを優先、なければ旧isPrivateフィールドで判定
        const tagIsPublic = t.isPublic !== undefined
            ? t.isPublic !== false
            : t.isPrivate !== true;
        if (!tagIsPublic && shareLevel === "public") privateTags.add(t.name);
      });

      const schedules = [];
      for (const doc of snapshot.docs) {
        const d = doc.data();
        // isPublic フィールドがあればそちらを優先、なければ旧 isPrivate フィールドで判定
        const isPublic = d.isPublic !== undefined
            ? d.isPublic !== false
            : d.isPrivate !== true;
        const tagName = d.tag || "";

        // shareLevel に応じてフィルタリング
        if (shareLevel === "public") {
          if (!isPublic) continue; // 非公開予定はスキップ
          if (privateTags.has(tagName)) continue; // 非公開タグの予定はスキップ
        }
        // shareLevel === "full" の場合は全件含む

        // Timestamp を ISO 文字列に変換（JSON シリアライズのため）
        const startDate = d.startDate ? d.startDate.toDate().toISOString() : null;
        const endDate = d.endDate ? d.endDate.toDate().toISOString() : (startDate || null);

        schedules.push({
          id: doc.id,
          title: d.title || "",
          startDate,
          endDate,
          isAllDay: d.isAllDay || false,
          tag: tagName,
          tagColorHex: tagColorMap[tagName] || null,
          location: d.location || "",
          memo: d.memo || "",
          isPublic: isPublic,
          recurringGroupId: d.recurringGroupId || null,
        });
      }

      return {schedules};
    },
);
