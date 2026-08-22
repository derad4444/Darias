#!/usr/bin/env node
/**
 * 既存キャラクターの口癖（favorite_word）だけを新しい生成条件で作り直す一回限りのスクリプト。
 *
 * 背景: 以前の `characterDetails` プロンプトは口癖に条件を課していなかったため、
 * 相手への相づち（`「面白いね！」`）・名詞だけ（`安定`）・鉤括弧込みの値が混ざっていた。
 * 日記の ai_comment はキャラクターの独白なので、これらは文脈に合わない。
 *
 * 口癖以外（長所・趣味・好きな色）と夢には一切触らない。
 * 夢を触らないため `pendingDreamProposal`（夢の再提案）は立たない。
 *
 * 使い方:
 *   node scripts/backfillFavoriteWord.js          # ドライラン（書き込みなし）
 *   node scripts/backfillFavoriteWord.js --apply  # Firestore へ反映
 */
require("dotenv").config({path: __dirname + "/../.env"});
const OpenAI = require("openai");
const admin = require("firebase-admin");
const {formatBig5WithTraits, stripQuotes} = require("../src/prompts/templates");

const APPLY = process.argv.includes("--apply");
const MODEL = "gpt-4o-2024-11-20";

admin.initializeApp({credential: admin.credential.cert(require("../keys/serviceAccountKey.json"))});
const db = admin.firestore();
const openai = new OpenAI({apiKey: process.env.OPENAI_API_KEY.trim()});

/** 口癖の生成条件。`src/prompts/templates.js` の `characterDetails` と同じ内容を保つ */
const RULES = `- 12文字以内
- 独り言としても会話の中でも自然に使える言い回しにする
- 相手の発言への相づち（面白いね！ / それいいね！ / うん、わかる！ など、会話相手がいないと成立しない言葉）は不可
- 名詞や単語だけ（安定 / 挑戦 など）は不可。文として言い切る形にする
- 性格に合ったトーンにする。外向的なら前向きで勢いのある言葉、内省的なら落ち着いた言葉
- 迷い・不安の調子（どうしよう / また考えすぎた）は、神経症傾向が高い性格のときだけ使う
- 鉤括弧（「」）や引用符を含めない`;

/** 単語だけの値を弾くための語尾チェック用。名詞1語は助詞・語尾を持たない */
const NOUN_ONLY = /^[ぁ-んァ-ヶ一-龠ー]{1,4}$/;

/**
 * 相手の発言がないと成立しない相づち。
 * 「面白い」という語そのものは問題ではない（`面白くなってきた` は独白として自然）。
 * 弾きたいのは同意を返す形（`面白いね！` / `それいいね！` / `うん、わかる！`）。
 */
const AIZUCHI = /(いいね|^それ|^これいい|^うん[、,]|わかる[！!]$|[ねよ][！!]$)/;

/**
 * 生成された口癖が条件を満たすか判定する
 * @param {string} w 生成された口癖
 * @return {boolean} 使えるなら true
 */
function isValid(w, big5) {
  if (typeof w !== "string") return false;
  const t = w.trim();
  if (!t || t.length > 12) return false;
  if (/[「」『』"']/.test(t)) return false;
  if (AIZUCHI.test(t)) return false;
  // 「安定」「成長」のような名詞1語は不可。ただし「なるほど」「やっぱり」等の副詞は許容する
  if (NOUN_ONLY.test(t) && !/^(なるほど|やっぱり|たしかに|なんとか|そっか|だよね)$/.test(t)) return false;
  // 迷い・不安の調子は神経症傾向が高い性格のときだけ許す
  const anxious = /どうしよう|どうしたもの|考えすぎ|どうすれば|どうなるん/.test(t);
  if (anxious && (big5.neuroticism || 3) < 4) return false;
  return true;
}

/**
 * 性格に合う口癖を1つ生成する
 * @param {Object} big5 Big5スコア
 * @param {string} gender 性別
 * @return {Promise<string>} 生成された口癖（失敗時は空文字）
 */
async function generate(big5, gender, current) {
  const genderText = gender === "female" ? "女性" : gender === "male" ? "男性" : "中性";
  const prompt = `性格: ${formatBig5WithTraits(big5)}
性別: ${genderText}
現在の口癖: ${current}

このキャラクターの口癖を作り直す。現在の口癖は、会話の相づちだったり単語だけだったりして、
一人で書く日記の文章に入れると不自然になる。雰囲気は活かしたまま、独白でも使える形に直す。

条件:
${RULES}

まず方向性の違う案を3つ挙げ、その中から性格に最も合うものを1つ選ぶ。
JSONのみで出力:
{"candidates":["案1","案2","案3"],"favorite_word":"選んだ口癖"}`;

  for (let i = 0; i < 3; i++) {
    const res = await openai.chat.completions.create({
      model: MODEL,
      messages: [{role: "user", content: prompt}],
      response_format: {type: "json_object"},
      max_tokens: 150,
      temperature: 0.9,
    });
    let parsed;
    try {
      parsed = JSON.parse(res.choices[0].message.content);
    } catch (e) {
      continue;
    }
    // 選ばれた案がダメでも、他の候補が条件を満たしていれば拾う
    const cands = [parsed.favorite_word, ...(parsed.candidates || [])];
    for (const c of cands) {
      const w = stripQuotes(c || "");
      if (isValid(w, big5)) return w;
    }
    console.log(`    ↺ 条件を満たす案が無いため再試行: ${cands.join(" / ")}`);
  }
  return "";
}

(async () => {
  // 口癖を持つキャラクターを集めて性格キーごとにまとめる
  const groups = new Map();
  for (const uref of await db.collection("users").listDocuments()) {
    for (const cref of await uref.collection("characters").listDocuments()) {
      const ref = cref.collection("details").doc("current");
      const snap = await ref.get();
      if (!snap.exists) continue;
      const d = snap.data();
      if (!d.favorite_word) continue;
      const key = d.personalityKey || "(未設定)";
      if (!groups.has(key)) {
        groups.set(key, {
          big5: d.convertedBig5Scores || d.confirmedBig5Scores || d.big5Scores,
          gender: d.gender || "neutral",
          chars: [],
        });
      }
      groups.get(key).chars.push({ref, old: d.favorite_word});
    }
  }
  console.log(`対象: ${groups.size}キー / ${[...groups.values()].reduce((n, g) => n + g.chars.length, 0)}キャラ`);
  console.log(APPLY ? "モード: 反映（--apply）\n" : "モード: ドライラン（書き込みなし）\n");

  let updated = 0; let skipped = 0;
  for (const [key, g] of groups) {
    if (!g.big5) {
      console.log(`⏭  ${key} : Big5スコアが無いためスキップ`);
      skipped += g.chars.length;
      continue;
    }
    // キーを共有するキャラで旧口癖が異なる場合は最も多いものを種にする
    const freq = {};
    g.chars.forEach((c) => {
      freq[c.old] = (freq[c.old] || 0) + 1;
    });
    const seed = Object.entries(freq).sort((a, b) => b[1] - a[1])[0][0];
    const next = await generate(g.big5, g.gender, seed);
    if (!next) {
      console.log(`⏭  ${key} : 条件を満たす口癖を生成できずスキップ`);
      skipped += g.chars.length;
      continue;
    }
    const olds = [...new Set(g.chars.map((c) => c.old))].join(" / ");
    console.log(`✔  ${key} (${g.chars.length}件) : ${olds} → ${next}`);

    if (APPLY) {
      for (const c of g.chars) {
        await c.ref.update({favorite_word: next});
      }
      // 共有テンプレートがあれば口癖だけ差し替える（夢・他の属性はそのまま）
      const tplRef = db.collection("CharacterDetailsTemplate").doc(key);
      const tpl = await tplRef.get();
      if (tpl.exists) {
        await tplRef.update({"attributes.favorite_word": next});
      }
    }
    updated += g.chars.length;
  }

  console.log(`\n完了: ${updated}キャラ更新${APPLY ? "" : "（予定）"} / ${skipped}キャラスキップ`);
  process.exit(0);
})();
