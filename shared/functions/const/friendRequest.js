// functions/const/friendRequest.js
// フレンド申請の送受信をCloud Functionで管理（管理者権限でFirestoreに書き込む）

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {v4: uuidv4} = require("uuid");

const db = getFirestore();

// ============================================================
// フレンド申請を送る
// ============================================================
exports.sendFriendRequest = onCall(
    {region: "asia-northeast1", memory: "256MiB", timeoutSeconds: 30, enforceAppCheck: false},
    async (request) => {
      const {auth} = request;
      if (!auth) return {error: "Unauthorized"};

      const {toUserId, toUserName, myName, myEmail} = request.data;
      const fromUserId = auth.uid;

      if (!toUserId) return {error: "Missing toUserId"};

      // 既にフレンドか確認
      const friendDoc = await db.collection("users").doc(fromUserId)
          .collection("friends").doc(toUserId).get();
      if (friendDoc.exists) return {result: "already_friend"};

      // 既に申請済みか確認
      const existing = await db.collection("users").doc(fromUserId)
          .collection("outgoingRequests").doc(toUserId).get();
      if (existing.exists) return {result: "already_sent"};

      const now = new Date();
      const requestData = {
        id: uuidv4(),
        fromUserId,
        fromUserName: myName ?? "",
        fromUserEmail: myEmail ?? "",
        toUserId,
        toUserName: toUserName ?? "",
        status: "pending",
        createdAt: now,
      };

      const batch = db.batch();

      // 相手の受信ボックスに書き込む（管理者権限なので可能）
      batch.set(
          db.collection("users").doc(toUserId)
              .collection("incomingRequests").doc(fromUserId),
          requestData,
      );

      // 自分の送信ボックスに書き込む
      batch.set(
          db.collection("users").doc(fromUserId)
              .collection("outgoingRequests").doc(toUserId),
          requestData,
      );

      await batch.commit();
      return {result: "sent"};
    },
);

// ============================================================
// フレンド申請を承認
// ============================================================
exports.acceptFriendRequest = onCall(
    {region: "asia-northeast1", memory: "256MiB", timeoutSeconds: 30, enforceAppCheck: false},
    async (request) => {
      const {auth} = request;
      if (!auth) return {error: "Unauthorized"};

      const {fromUserId} = request.data;
      const toUserId = auth.uid;

      if (!fromUserId) return {error: "Missing fromUserId"};

      // 申請データを取得
      const reqDoc = await db.collection("users").doc(toUserId)
          .collection("incomingRequests").doc(fromUserId).get();
      if (!reqDoc.exists) return {error: "Request not found"};

      const reqData = reqDoc.data();

      // 自分のユーザー情報を取得
      const myDoc = await db.collection("users").doc(toUserId).get();
      const myData = myDoc.data() ?? {};

      const batch = db.batch();

      // 申請ドキュメントを削除（両者）
      batch.delete(
          db.collection("users").doc(toUserId)
              .collection("incomingRequests").doc(fromUserId),
      );
      batch.delete(
          db.collection("users").doc(fromUserId)
              .collection("outgoingRequests").doc(toUserId),
      );

      const now = new Date();

      // 自分のフレンドリストに相手を追加
      batch.set(
          db.collection("users").doc(toUserId)
              .collection("friends").doc(fromUserId),
          {
            id: fromUserId,
            name: reqData.fromUserName ?? "",
            email: reqData.fromUserEmail ?? "",
            shareLevel: "none",
            createdAt: now,
          },
      );

      // 相手のフレンドリストに自分を追加
      batch.set(
          db.collection("users").doc(fromUserId)
              .collection("friends").doc(toUserId),
          {
            id: toUserId,
            name: myData.name ?? "",
            email: myData.email ?? "",
            shareLevel: "none",
            createdAt: now,
          },
      );

      await batch.commit();
      return {result: "accepted"};
    },
);

// ============================================================
// フレンド申請を拒否
// ============================================================
exports.rejectFriendRequest = onCall(
    {region: "asia-northeast1", memory: "256MiB", timeoutSeconds: 30, enforceAppCheck: false},
    async (request) => {
      const {auth} = request;
      if (!auth) return {error: "Unauthorized"};

      const {fromUserId} = request.data;
      const toUserId = auth.uid;

      const batch = db.batch();
      batch.delete(
          db.collection("users").doc(toUserId)
              .collection("incomingRequests").doc(fromUserId),
      );
      batch.delete(
          db.collection("users").doc(fromUserId)
              .collection("outgoingRequests").doc(toUserId),
      );
      await batch.commit();
      return {result: "rejected"};
    },
);

// ============================================================
// フレンド申請を取消（送信者側）
// ============================================================
exports.cancelFriendRequest = onCall(
    {region: "asia-northeast1", memory: "256MiB", timeoutSeconds: 30, enforceAppCheck: false},
    async (request) => {
      const {auth} = request;
      if (!auth) return {error: "Unauthorized"};

      const {toUserId} = request.data;
      const fromUserId = auth.uid;

      const batch = db.batch();
      batch.delete(
          db.collection("users").doc(fromUserId)
              .collection("outgoingRequests").doc(toUserId),
      );
      batch.delete(
          db.collection("users").doc(toUserId)
              .collection("incomingRequests").doc(fromUserId),
      );
      await batch.commit();
      return {result: "cancelled"};
    },
);
