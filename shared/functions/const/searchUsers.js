// functions/const/searchUsers.js
// ユーザー検索Cloud Function（管理者権限でFirestoreを検索）

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");

const db = getFirestore();

exports.searchUsers = onCall(
    {
      region: "asia-northeast1",
      memory: "256MiB",
      timeoutSeconds: 30,
      minInstances: 0,
      enforceAppCheck: false,
    },
    async (request) => {
      const {auth} = request;
      if (!auth) return {users: []};

      const {query} = request.data;
      if (!query || query.trim().length === 0) return {users: []};

      const trimmed = query.trim();
      const isEmail = trimmed.includes("@");
      const currentUserId = auth.uid;

      try {
        let snap;

        if (isEmail) {
          // メールアドレス完全一致
          snap = await db.collection("users")
              .where("email", "==", trimmed.toLowerCase())
              .limit(10)
              .get();
        } else {
          // 名前の前方一致（インデックス不要な範囲クエリ）
          const end = trimmed.slice(0, -1) +
            String.fromCharCode(trimmed.charCodeAt(trimmed.length - 1) + 1);
          snap = await db.collection("users")
              .where("name", ">=", trimmed)
              .where("name", "<", end)
              .limit(20)
              .get();
        }

        const users = snap.docs
            .filter((doc) => doc.id !== currentUserId)
            .map((doc) => {
              const data = doc.data();
              return {
                id: doc.id,
                name: data.name ?? "",
                email: data.email ?? "",
              };
            });

        return {users};
      } catch (e) {
        console.error("searchUsers error:", e);
        return {users: []};
      }
    },
);
