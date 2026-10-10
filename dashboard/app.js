// DARIAS 運営ダッシュボード
// データは reels-bot の collector が毎朝 admin_metrics に保存したものを読むだけ。
// 読めるのは運営者だけ（firestore.rules の admin_metrics）。画面側の判定は表示の出し分けにすぎない。
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  getAuth, GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import {
  getFirestore, doc, getDoc, collection, query, orderBy, limit, getDocs,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyCiQ_AG2ui896nPJNcNieaHnie6tghsZDk",
  authDomain: "my-character-app.firebaseapp.com",
  projectId: "my-character-app",
  appId: "1:881831618841:web:78d64a34cb486160f67d88",
};
// 運営者のアカウント（kaosud@gmail.com）の UID。firestore.rules の admin_metrics と同じ
const ADMIN_UID = "l5M6D7XvjwSvC15HJYHFdKZo0bz1";
const COLLECT_URL = "https://reels-bot-oh2poc3uba-an.a.run.app/collect-metrics-now";
// 自分会議の実施数は Firestore の記録から全期間を数えているので、記録の無い日は0件として扱う（アプリの公開日から）
const MEETINGS_START = "2025-10-01";
// Firebase Analytics（GA4）の計測を始めた日。これより前のアプリ内の数字は無い
const GA4_START = "2026-08-19";
// 日別の文書を読む上限（全期間の表示に足りる日数）
const MAX_DAYS = 800;

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const $ = (id) => document.getElementById(id);

// 読み込んだデータと、いま選んでいる期間
const state = { L: {}, S: {}, daily: [], persona: null, period: "30", from: "", to: "" };

// ───────── 項目ごとの説明（ヘルプ）: [見出し, 何の数字？, どう見る？] ─────────
const HELP = {
  highlights: ["今回のハイライト", "選んだ期間のなかで目立った出来事を自動で拾ったものです。", "いちばん伸びた数字・いちばん見られた投稿などが並びます。良い変化は続ける、悪い変化は原因を探すきっかけにしてください。"],
  kpiSns: ["SNSでの表示", "Instagram と Threads のアカウント全体で、投稿が画面に表示された回数の合計です（毎朝、前日1日分を記録しています）。", "DARIAS を知ってもらう入口の大きさです。ここが増えないと、ストアの表示やダウンロードも増えません。記録は2026年10月10日から。"],
  kpiStoreImp: ["ストアでの表示", "App Store の検索結果やおすすめなどで、DARIAS が表示された回数です。", "見つけてもらえているかの指標です。表示が多いのにダウンロードが少なければ、アイコン・タイトル・スクショの見直しが効きます。"],
  kpiPageViews: ["ストアのページ閲覧", "App Store で DARIAS のページが開かれた回数です。", "表示からページを開いた割合が低いなら、検索結果で見えるアイコンとタイトル・サブタイトルを見直します。"],
  kpiDl: ["初回ダウンロード", "その期間に初めて DARIAS をダウンロードした数です（再ダウンロードは含みません）。", "新しく来てくれた人の数です。ページ閲覧に対する割合（転換率）とあわせて見ます。"],
  kpiConv: ["ストアの転換率", "ページ閲覧のうち、初回ダウンロードにつながった割合です。", "ストアのページ（スクショ・説明文・評価）の説得力を表します。評価のリセットやスクショの変更の効果はここに出ます。"],
  kpiNew: ["新規ユーザー（日本）", "アプリを初めて起動した端末の数です。審査用やテスト用の端末を除くため、日本のユーザーだけを数えています。", "ダウンロードしたあと実際に開いてくれた人の数です。初回ダウンロードより大きく少ないなら、入れたまま開かれていません。"],
  kpiActive: ["使った人（重複なし）", "期間内に一度でもアプリを開いた人の数です（日本のみ）。同じ人が何日開いても1人と数えます。プレミアムの人・Web版の人・開発用の端末も含みます。", "新規が少なくても、ここが保たれていれば使い続けてもらえています。広告が出るのはこのうち iPhone 版の無料ユーザーだけなので、広告の表示人数はこれより少なくなります。"],
  kpiAd: ["広告の推定収益", "AdMob の推定収益（円）です。確定額は月末に少し変わることがあります。", "無料ユーザーの数と、広告が実際に表示された回数で決まります。"],
  kpiAdImp: ["広告の表示回数", "広告が実際に画面に表示された回数です。", "読み込んだのに表示されない広告が多いと、ここがリクエスト数より大きく下回ります。"],
  kpiCtr: ["広告のクリック率", "表示された広告のうち、タップされた割合です。", "1%前後が目安です。極端に高い場合は誤タップを誘う配置になっていないか確認します。"],
  kpiEcpm: ["eCPM", "広告が1000回表示されたときの収益（円）です。", "広告の単価です。表示回数が少ない期間はぶれやすいので、長めの期間で見ます。"],
  kpiIgFollowers: ["Instagram のフォロワー", "期間の最後の日のフォロワー数と、期間のはじめからの増減です。", "投稿を続けてファンが増えているかを見ます。"],
  kpiThFollowers: ["Threads のフォロワー", "期間の最後の日のフォロワー数と、期間のはじめからの増減です。", "投稿を続けてファンが増えているかを見ます。"],
  kpiMeetings: ["自分会議の実施", "期間内に実際に作られた自分会議の数です（運営者自身の分は除く）。Firestore の会議の記録から数えています。", "目玉機能が使われているかを直接見る数字です。ファネルの「自分会議」は画面を開いた人数なので、こちらと合わせて見ます。"],
  kpiMeetingReady: ["自分会議を使える人", "性格タイプが決まり（成長段階が幼少期以上）、自分会議のロックが外れている人の数です。性格の集計と同じく最新の状態を表示します。", "ここが少ないと、自分会議まで届く人も少なくなります。バッジ診断の第1弾をそろえてもらえているかの目安にもなります。"],
  kpiIgLinkTaps: ["プロフィールのリンクのタップ", "Instagram のプロフィールに置いたリンク（App Store など）がタップされた回数です（毎朝、前日1日分を記録しています）。", "リールを見た人が「アプリを入れてみよう」と動いた数です。プロフィールの1行目や投稿の締めを変えたら、ここが増えたかで効果を見ます（2026-10-10 にプロフィールの1行目を変更）。"],
  kpiIgViews: ["Instagram 投稿の再生", "期間内に投稿したリール・投稿の再生（表示）回数の合計です。", "1本あたりの再生が伸びない場合は、冒頭の1〜2秒で離脱されていないか（平均視聴）も確認します。"],
  kpiThViews: ["Threads 投稿の表示", "期間内に投稿した Threads の表示回数の合計です。", "どんな内容が見られているかは、下の表を「表示」で並べ替えると分かります。"],
  kpiCharacters: ["キャラクター数", "性格の解析が始まっているキャラクターの数です（テスト用や削除済みアカウントのものを含みます）。", "アプリで遊んだことのある人のおおよその数です。"],
  kpiDecided: ["元素が決まった数", "バッジ診断などで元素まで決まったキャラクターの数です。", "ここが少ないなら、元素が決まるところまで続けてもらえていません。"],
  kpiTypes: ["タイプ名の種類", "決まったタイプ名（例: 場を沸かす炎タイプ）の種類の数です。", "18種類のうちいくつに散らばっているかを見ます。偏りが大きいなら診断の傾きを疑います。"],
  kpiRating: ["平均評価（本文付き）", "本文付きレビューの星の平均です（星だけの評価は含みません）。", "ストアで表示される平均とは別物です。不満の中身は下のレビュー一覧で確認します。"],
  funnel: ["ファネル", "アプリを初めて開いた人が、ホーム→チャット→自分会議→課金画面→購入とどこまで進んだかの人数です（日本のユーザーのみ）。「自分会議」はロックが外れた状態で自分会議のタブを開いた人数で、ロック中に開いた人は下に別に出します。", "段と段のあいだの割合が急に落ちるところが、離脱しているところです。期間内に各段階へ来た人数なので、期間より前に初めて開いた人も数え、上の段より多くなることがあります。自分会議のタブを開いた記録はアプリ 3.14 より後の版から取っているため、それより前の版の人は「自分会議」に数えられていません。"],
  signups: ["新規アカウント数（月別）", "Firebase のアカウントが作られた数を月ごとに数えたものです。", "ダウンロードからアカウント登録まで進んだ人の推移です。期間の切り替えとは関係なく全期間を表示します。"],
  storeImpressions: ["ストアでの表示回数", "App Store で DARIAS が表示された回数の日別推移です。", "検索の順位やおすすめに載ったかどうかで大きく動きます。急に増えた日は何があったか（投稿・更新）を振り返ります。"],
  storeDownloads: ["初回ダウンロード", "初めてダウンロードした数の日別推移です。", "SNSの投稿やアップデートの日と重ねて、効いた施策を探します。"],
  storeSources: ["ページ閲覧の流入元", "App Store のページがどこから開かれたかの内訳です（App Store の検索・閲覧・Web・他のアプリなど）。", "検索が大半ならキーワードが効いています。Web やアプリ参照が増えていれば SNS やリンクからの流入です。"],
  ratingDist: ["評価の内訳", "本文付きレビューの星ごとの件数です。", "★1〜2が多いときはレビュー一覧で不満の中身を確認し、直したら返信します。"],
  reviews: ["レビュー一覧", "App Store に書かれた本文付きのレビューです。", "星で絞り込んだり、新しい順・評価順に並べ替えたりできます。直した不満には App Store Connect から返信すると、見ている人の印象が変わります。"],
  newUsers: ["新規ユーザー（日別）", "アプリを初めて開いた端末の数の日別推移です（日本のみ）。", "SNSやストアの施策の効果がいちばん早く出るところです。"],
  activeUsers: ["アクティブユーザー（日別）", "その日にアプリを開いた人の数です（日本のみ）。", "新規が少ない日でも保たれていれば、毎日使ってもらえています。"],
  weekly: ["週ごとの新規とアクティブ", "週ごとの新規ユーザーとアクティブユーザーの表です（日本のみ）。列名を押すと並べ替えられます。", "アクティブが新規より大きく上回っていれば、前から使っている人が戻ってきています。"],
  adEarnings: ["推定収益（日別）", "AdMob の推定収益の日別推移です。", "無料ユーザーの数にほぼ比例します。急に0になった日は広告の表示まわりの不具合を疑います。"],
  adImpressions: ["表示回数（日別）", "広告が実際に表示された回数の日別推移です。", "リクエストはあるのに表示が0の日が続くときは、表示される前に広告が消えていないか確認します。"],
  igFollowers: ["Instagram フォロワー数", "毎朝記録したフォロワー数の推移です。", "投稿の型を変えた日と重ねて、伸びたきっかけを探します。"],
  thFollowers: ["Threads フォロワー数", "毎朝記録したフォロワー数の推移です。", "1日8回の自動投稿がファンにつながっているかを見ます。"],
  igTiming: ["Instagram 曜日・時間帯ごとの成績", "期間内に投稿したリール・投稿を、投稿した曜日と時間帯（日本時間）ごとにまとめたものです。再生の中央値（真ん中の値）と平均、本数を出します。", "投稿の曜日や時間を変えたら、2〜4週間たってからここで比べます。本数が少ない枠は1本の当たり外れで大きく動くので、中央値と本数をあわせて見てください。"],
  thTiming: ["Threads 曜日・時間帯ごとの成績", "期間内に投稿した Threads を、投稿した曜日と時間帯（日本時間）ごとにまとめたものです。表示の中央値と平均、本数を出します。", "通勤・昼休み・寝る前など、狙った時間に見られているかを確かめます。本数が少ない枠は中央値と本数をあわせて見てください。"],
  igPosts: ["Instagram 投稿の成績", "期間内に投稿したリール・投稿ごとの成績です。列名を押すと並べ替えられます。", "保存とシェアは「次の人にも配信されるか」を決める大事な数字です。平均視聴が1〜2秒なら冒頭で離脱されています。"],
  thPosts: ["Threads 投稿の成績", "期間内に投稿した Threads ごとの成績です。列名を押すと並べ替えられます。", "表示で並べ替えると、どんな話題や書き出しが見られているかが分かります。"],
  elements: ["元素ごとの人数", "9つの元素それぞれに決まったキャラクターの数と、元素が決まった人のなかでの割合です。「未確定」はまだ元素が決まっていない（赤ちゃん段階の）キャラクターです。", "特定の元素に偏りすぎていないかを見ます。極端な偏りは、診断の質問や採点の傾きが原因のことがあります。"],
  typeNames: ["タイプ名", "決まったタイプ名ごとの人数です（多い順）。", "同じ元素の2タイプがどちらかに偏っていないかも見ます。"],
  stages: ["成長段階", "キャラクターが赤ちゃん・幼少期・大人のどこまで育ったかの人数です。", "赤ちゃんのまま止まっている人が多いなら、バッジ診断の第1弾をそろえるところまで続けてもらえていません。"],
  badges: ["バッジ診断で答えた数", "バッジ診断の質問にいくつ答えたかを区分した人数です（第1弾は10問、第2弾は20問でそろいます）。", "どこで答えるのをやめているかが分かります。"],
  gender: ["性別", "キャラクターの性別ごとの人数です。", "ユーザー層の目安です。"],
};

// ───────── ログイン ─────────
$("login-btn").onclick = async () => {
  $("login-error").textContent = "";
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    $("login-error").textContent = "ログインできませんでした: " + e.message;
  }
};
$("logout-btn").onclick = () => signOut(auth);

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    $("login").hidden = false;
    $("app").hidden = true;
    return;
  }
  if (user.uid !== ADMIN_UID) {
    $("login").hidden = false;
    $("app").hidden = true;
    $("login-error").textContent = "このアカウントには閲覧の権限がありません。";
    await signOut(auth);
    return;
  }
  $("login").hidden = true;
  $("app").hidden = false;
  await loadAll();
});

// ───────── タブ ─────────
document.querySelectorAll(".tabs button").forEach((btn) => {
  btn.onclick = () => {
    document.querySelectorAll(".tabs button").forEach((b) => b.setAttribute("aria-selected", b === btn));
    document.querySelectorAll(".tab").forEach((t) => { t.hidden = t.id !== "tab-" + btn.dataset.tab; });
    hideHelp();
    remember("dash-tab", btn.dataset.tab);
  };
});

// ───────── 期間 ─────────
document.querySelectorAll(".periods button").forEach((btn) => {
  btn.onclick = () => setPeriod(btn.dataset.period);
});
$("from").onchange = $("to").onchange = () => { state.from = $("from").value; state.to = $("to").value; renderAll(); };

function setPeriod(p) {
  state.period = p;
  document.querySelectorAll(".periods button").forEach((b) => b.setAttribute("aria-pressed", b.dataset.period === p));
  $("custom-range").hidden = p !== "custom";
  if (p === "custom" && !state.from) {
    const r = presetRange("30");
    state.from = $("from").value = r.from;
    state.to = $("to").value = r.to;
  }
  remember("dash-period", p);
  renderAll();
}

function todayStr() { return ymd(new Date()); }
function ymd(d) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; }
function addDays(s, n) { const d = new Date(s + "T00:00:00"); d.setDate(d.getDate() + n); return ymd(d); }
function daysBetween(a, b) { return Math.round((new Date(b + "T00:00:00") - new Date(a + "T00:00:00")) / 86400000) + 1; }

function presetRange(p) {
  const to = todayStr();
  if (p === "all") return { from: state.daily[0]?.date || to, to };
  return { from: addDays(to, -(Number(p) - 1)), to };
}
// いま選んでいる期間と、その直前の同じ長さの期間（全期間のときは比較しない）
function ranges() {
  let cur;
  if (state.period === "custom" && state.from && state.to) {
    const [a, b] = [state.from, state.to].sort();
    cur = { from: a, to: b };
  } else {
    cur = presetRange(state.period === "custom" ? "30" : state.period);
  }
  const len = daysBetween(cur.from, cur.to);
  const prev = state.period === "all" ? null : { from: addDays(cur.from, -len), to: addDays(cur.from, -1) };
  return { cur, prev };
}
const inRange = (date, r) => !!r && date >= r.from && date <= r.to;
const rowsIn = (r) => state.daily.filter((d) => inRange(d.date, r));

// ───────── 今すぐ集計 ─────────
$("collect-btn").onclick = async () => {
  const btn = $("collect-btn");
  btn.disabled = true;
  showStatus("集計しています…（1〜2分かかります）");
  try {
    const token = await auth.currentUser.getIdToken();
    const res = await fetch(COLLECT_URL, { method: "POST", headers: { Authorization: "Bearer " + token } });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(body.detail || res.status);
    showStatus(body.status === "skipped" ? body.reason : "集計しました。");
    await loadAll();
  } catch (e) {
    showStatus("集計に失敗しました: " + e.message);
  } finally {
    btn.disabled = false;
  }
};
function showStatus(text) {
  $("collect-status").hidden = false;
  $("collect-status").textContent = text;
}

// ───────── 読み込み ─────────
async function loadAll() {
  try {
    const [latest, summary, dailySnap, personaSnap] = await Promise.all([
      getDoc(doc(db, "admin_metrics", "latest")),
      getDoc(doc(db, "admin_metrics", "summary")),
      getDocs(query(collection(db, "admin_metrics", "daily", "days"), orderBy("date", "desc"), limit(MAX_DAYS))),
      getDocs(query(collection(db, "admin_metrics", "personality", "days"), orderBy("date", "desc"), limit(1))),
    ]);
    state.L = latest.data() || {};
    state.S = summary.data() || {};
    state.daily = dailySnap.docs.map((d) => d.data()).sort((a, b) => a.date.localeCompare(b.date));
    state.persona = personaSnap.docs[0]?.data() || null;
    renderHeader();
    renderAll();
  } catch (e) {
    showStatus("データを読めませんでした: " + e.message);
  }
}

function renderAll() {
  const { cur, prev } = ranges();
  $("period-label").textContent = `${fmtDay(cur.from)} 〜 ${fmtDay(cur.to)}${prev ? `（比較: ${fmtDay(prev.from)} 〜 ${fmtDay(prev.to)}）` : ""}`;
  const ctx = { cur, prev, rows: rowsIn(cur), prevRows: prev ? rowsIn(prev) : [] };
  renderOverview(ctx);
  renderStore(ctx);
  renderAppUsage(ctx);
  renderAds(ctx);
  renderSns(ctx);
  renderPersonality();
}

const SOURCE_LABELS = {
  appStore: "App Store", ga4: "アプリ内（GA4）", admob: "AdMob", instagram: "Instagram", meetings: "自分会議の実施",
  threads: "Threads", signups: "登録数", personality: "性格",
};

function renderHeader() {
  const L = state.L;
  const at = L.finishedAt?.toDate?.();
  const h = new Date().getHours();
  $("hero-title").textContent = h < 11 ? "おはようございます ☀️" : h < 18 ? "こんにちは 🌤" : "おつかれさまです 🌙";
  $("updated").textContent = at ? `最終更新 ${fmtDateTime(at)}（${L.trigger === "manual" ? "手動" : "自動"}）・毎朝6時に自動で集計します` : "まだ集計されていません";
  const errs = Object.keys(L.errors || {});
  $("source-errors").hidden = errs.length === 0;
  $("source-errors").textContent = errs.length
    ? "取得できなかったもの: " + errs.map((k) => `${SOURCE_LABELS[k] || k}（${L.errors[k]}）`).join(" ／ ")
    : "";
}

// ───────── 値の取り出し ─────────
const V = {
  snsViews: (r) => sumDefined([r.instagram?.yesterday?.views, r.threads?.yesterday?.views]),
  storeImp: (r) => r.appStore?.engagement?.byType?.Impression,
  pageViews: (r) => sumKeys(r.appStore?.engagement?.byType, "page view"),
  firstDl: (r) => sumKeys(r.appStore?.downloads?.byType, "first"),
  newUsers: (r) => r.ga4?.newUsers,
  activeUsers: (r) => r.ga4?.activeUsers,
  adEarn: (r) => r.admob?.earningsJPY,
  adImp: (r) => r.admob?.impressions,
  adClicks: (r) => r.admob?.clicks,
  igFollowers: (r) => r.instagram?.followers,
  igLinkTaps: (r) => r.instagram?.yesterday?.profile_links_taps,
  meetings: (r) => r.meetings?.count ?? (r.date >= MEETINGS_START ? 0 : undefined),
  thFollowers: (r) => r.threads?.followers,
};
function sumKeys(t, prefix) { if (!t) return undefined; return Object.entries(t).filter(([k]) => k.toLowerCase().startsWith(prefix)).reduce((a, [, v]) => a + v, 0); }
function sumDefined(arr) { const xs = arr.filter((x) => x != null); return xs.length ? xs.reduce((a, b) => a + b, 0) : undefined; }
// 期間の合計。1日もデータが無ければ undefined（「0」と「まだ無い」を区別する）
function total(rows, f) { return rows.some((r) => f(r) != null) ? rows.reduce((a, r) => a + (f(r) || 0), 0) : undefined; }
function last(rows, f) { for (let i = rows.length - 1; i >= 0; i--) { const v = f(rows[i]); if (v != null) return v; } return undefined; }
function first(rows, f) { for (const r of rows) { const v = f(r); if (v != null) return v; } return undefined; }
function dateList(r) { const out = []; for (let d = r.from; d <= r.to; d = addDays(d, 1)) out.push(d); return out; }
function series(ctx, f) {
  const byDate = new Map(state.daily.map((r) => [r.date, r]));
  return dateList(ctx.cur).map((d) => [d, f(byDate.get(d) || { date: d })]);
}

// ───────── 大きな数字のカード ─────────
function kpi(o) { return { format: fmt, ...o }; }
function renderKpis(id, items) {
  $(id).innerHTML = items.map((k, i) => {
    const has = k.value != null && Number.isFinite(k.value);
    const d = has && k.prev != null ? deltaBadge(k.value, k.prev, k.format) : "";
    const tone = toneOf(k);
    return `<div class="kpi ${tone}" style="animation-delay:${i * 40}ms">
      <div class="kpi-head"><span class="label">${esc(k.label)}</span><button class="help" data-help="${k.help}" aria-label="${esc(k.label)}の説明">?</button></div>
      <div class="value" data-i="${i}">${has ? esc(k.format(k.value)) : "–"}</div>
      <div class="sub">${has ? d + (k.sub ? esc(k.sub) : "") : esc(k.why || "データなし")}</div>
      ${k.spark ? sparkline(k.spark) : ""}
    </div>`;
  }).join("");
  // 数字を0から数え上げる（動きを減らす設定のときはしない）
  $(id).querySelectorAll(".value[data-i]").forEach((el) => {
    const k = items[Number(el.dataset.i)];
    if (k.value != null && Number.isFinite(k.value)) countUp(el, k.value, k.format);
  });
}
// 前の期間より良くなったら good、悪くなったら bad（数字が増えるほど良いものばかりなので、増減で決める）。
// 変化が小さい（±5%未満）ときは色を付けない。色だけに頼らないよう、▲▼と%も必ず出す
const TONE_THRESHOLD = 0.05;
function toneOf(k) {
  if (k.tone) return k.tone;
  if (k.value == null || k.prev == null || !Number.isFinite(k.value)) return "";
  if (k.prev === 0) return k.value > 0 ? "good" : "";
  const r = (k.value - k.prev) / k.prev;
  return r >= TONE_THRESHOLD ? "good" : r <= -TONE_THRESHOLD ? "bad" : "";
}
function deltaBadge(v, p, format) {
  const diff = v - p;
  if (diff === 0) return `<span class="delta">± 0</span><span>前の期間と同じ　</span>`;
  const pct = p ? Math.round(diff / p * 100) : null;
  const up = diff > 0;
  const text = `${up ? "▲" : "▼"} ${pct == null ? format(Math.abs(diff)) : Math.abs(pct) + "%"}`;
  return `<span class="delta ${up ? "up" : "down"}">${text}</span><span>前の期間 ${esc(format(p))}　</span>`;
}
function countUp(el, target, format) {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const start = performance.now(), dur = 700;
  const step = (t) => {
    const k = Math.min(1, (t - start) / dur);
    el.textContent = format(k === 1 ? target : target * (1 - Math.pow(1 - k, 3)));
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
function sparkline(points) {
  const vals = points.map(([, v]) => v).filter((v) => v != null);
  if (vals.length < 2) return "";
  const W = 200, H = 34, max = Math.max(...vals), min = Math.min(...vals);
  const x = (i) => i / (points.length - 1) * W;
  const y = (v) => H - 3 - (max === min ? (H - 6) / 2 : (v - min) / (max - min) * (H - 6));
  let d = "", pen = false;
  points.forEach(([, v], i) => { if (v == null) { pen = false; return; } d += `${pen ? "L" : "M"}${x(i).toFixed(1)},${y(v).toFixed(1)}`; pen = true; });
  return `<svg class="spark" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" aria-hidden="true"><path d="${d}" fill="none" stroke="var(--series-1)" stroke-width="2" vector-effect="non-scaling-stroke" stroke-linejoin="round" stroke-linecap="round"/></svg>`;
}

// ───────── 全体 ─────────
function renderOverview(ctx) {
  const { rows, prevRows } = ctx;
  renderKpis("ov-kpis", [
    kpi({ help: "kpiSns", label: "SNSでの表示", value: total(rows, V.snsViews), prev: total(prevRows, V.snsViews), spark: series(ctx, V.snsViews), why: "記録は10/10から" }),
    kpi({ help: "kpiStoreImp", label: "ストアでの表示", value: total(rows, V.storeImp), prev: total(prevRows, V.storeImp), spark: series(ctx, V.storeImp), why: "Apple のレポート待ち" }),
    kpi({ help: "kpiDl", label: "初回ダウンロード", value: total(rows, V.firstDl), prev: total(prevRows, V.firstDl), spark: series(ctx, V.firstDl), why: "Apple のレポート待ち" }),
    kpi({ help: "kpiNew", label: "新規ユーザー（日本）", value: total(rows, V.newUsers), prev: total(prevRows, V.newUsers), spark: series(ctx, V.newUsers) }),
    kpi({ help: "kpiAd", label: "広告の推定収益", value: total(rows, V.adEarn), prev: total(prevRows, V.adEarn), format: yen, spark: series(ctx, V.adEarn) }),
  ]);
  renderHighlights(ctx);
  renderFunnel("ov-funnel", "ov-funnel-note");
  const months = Object.entries(state.S.signupsByMonth || {}).sort(([a], [b]) => a.localeCompare(b)).map(([m, v]) => ({ label: m, value: v }));
  columnChart("ov-signups", months, { unit: "件" });
}

function renderHighlights(ctx) {
  const { rows, prevRows, cur } = ctx;
  const items = [];
  // 前の期間からいちばん大きく動いた数字
  const moved = [
    ["新規ユーザー", V.newUsers, fmt], ["SNSでの表示", V.snsViews, fmt], ["ストアでの表示", V.storeImp, fmt],
    ["初回ダウンロード", V.firstDl, fmt], ["広告の推定収益", V.adEarn, yen],
  ].map(([name, f, format]) => ({ name, format, v: total(rows, f), p: total(prevRows, f) }))
    .filter((m) => m.v != null && m.p != null && m.p > 0)
    .map((m) => ({ ...m, r: (m.v - m.p) / m.p }));
  if (moved.length) {
    const best = moved.reduce((a, b) => (b.r > a.r ? b : a));
    const worst = moved.reduce((a, b) => (b.r < a.r ? b : a));
    if (best.r > 0) items.push({ tone: "good", emoji: "📈", title: "いちばん伸びた数字", main: `${best.name} +${Math.round(best.r * 100)}%`, sub: `前の期間 ${best.format(best.p)} → ${best.format(best.v)}` });
    if (worst.r < 0) items.push({ tone: "bad", emoji: "📉", title: "いちばん落ちた数字", main: `${worst.name} −${Math.round(-worst.r * 100)}%`, sub: `前の期間 ${worst.format(worst.p)} → ${worst.format(worst.v)}` });
  }
  const ig = postsIn(state.S.instagramPosts, cur).sort((a, b) => (b.views || 0) - (a.views || 0))[0];
  if (ig) items.push({ emoji: "🎬", title: "いちばん見られた Instagram", html: link(clip(ig.title || "（本文なし）", 26), ig.permalink), sub: `再生 ${fmt(ig.views)}・保存 ${fmt(ig.saved)}・シェア ${fmt(ig.shares)}` });
  const th = postsIn(state.S.threadsPosts, cur).sort((a, b) => (b.views || 0) - (a.views || 0))[0];
  if (th) items.push({ emoji: "🧵", title: "いちばん見られた Threads", html: link(clip(th.title || "（本文なし）", 26), th.permalink), sub: `表示 ${fmt(th.views)}・いいね ${fmt(th.likes)}・返信 ${fmt(th.replies)}` });
  const igF = last(rows, V.igFollowers), thF = last(rows, V.thFollowers);
  if (igF != null || thF != null) {
    const g = (f) => { const a = first(rows, f), b = last(rows, f); return a != null && b != null ? b - a : 0; };
    const net = g(V.igFollowers) + g(V.thFollowers);
    items.push({ tone: net > 0 ? "good" : net < 0 ? "bad" : "", emoji: "🌱", title: "フォロワー", main: `Instagram ${fmt(igF)}・Threads ${fmt(thF)}`, sub: `期間内の増減 Instagram ${signed(g(V.igFollowers))}・Threads ${signed(g(V.thFollowers))}` });
  }
  const reviews = (state.S.reviews || []).filter((r) => inRange((r.createdDate || "").slice(0, 10), cur));
  items.push(reviews.length
    ? { tone: avg(reviews.map((r) => r.rating)) >= 4 ? "good" : avg(reviews.map((r) => r.rating)) <= 2.5 ? "bad" : "", emoji: "⭐", title: "期間内のレビュー", main: `${reviews.length}件・平均 ★${avg(reviews.map((r) => r.rating)).toFixed(1)}`, sub: clip(reviews[0].title || reviews[0].body, 30) }
    : { emoji: "💬", title: "期間内のレビュー", main: "新しいレビューはありません", sub: `これまでの合計 ${fmt((state.S.reviews || []).length)} 件` });
  const TONE_TEXT = { good: "良い", bad: "要注意" };
  $("ov-highlights").innerHTML = items.slice(0, 6).map((h, i) => `<div class="highlight ${h.tone || ""}" style="animation-delay:${i * 50}ms"><div class="emoji" aria-hidden="true">${h.emoji}</div><div><div class="h-title">${esc(h.title)}${h.tone ? `<span class="tone-label">${TONE_TEXT[h.tone]}</span>` : ""}</div><div class="h-main">${h.html || esc(h.main)}</div><div class="h-sub">${esc(h.sub)}</div></div></div>`).join("");
}

// ファネルは人数（重複を除いた数）なので日別を足せない。期間の選択肢ごとに collector が取った値を使う
function funnelFor() {
  const S = state.S;
  const map = { 7: S.funnel7, 30: S.funnel30, 90: S.funnel90, all: S.funnelAll };
  if (map[state.period]) return { data: map[state.period], note: state.period === "all" ? "2026-08-19（計測開始）以降" : `直近${state.period}日` };
  return { data: S.funnel30 || S.funnelAll || [], note: state.period === "custom" ? "期間を指定したときは直近30日の値です（人数は日ごとに足し合わせられないため）" : "直近30日" };
}
function renderFunnel(id, noteId) {
  let { data, note } = funnelFor();
  $(noteId).textContent = note;
  const el = $(id);
  if (!data.length) { el.innerHTML = `<p class="empty">データがありません</p>`; return; }
  // 段に入れない補足（自分会議のロック画面を開いた人など）は下に添える
  const side = data.filter((s) => s.side);
  data = data.filter((s) => !s.side);
  const max = Math.max(...data.map((s) => s.users), 1);
  el.innerHTML = `<div class="funnel">${data.map((s, i) => {
    const conv = i > 0 && data[i - 1].users ? Math.round(s.users / data[i - 1].users * 100) : null;
    // 期間内に来た人数どうしなので、期間より前に始めた人が多いと100%を超える。そのときは割合を出さない
    const convText = conv == null ? "–" : conv > 100 ? "–（期間より前に始めた人を含むため比べられません）" : conv + "%";
    return `${i > 0 ? `<div class="f-conv">↓ 前の段から <strong>${convText}</strong></div>` : ""}
      <div class="f-step"><span class="f-label">${esc(s.label)}</span><div class="f-track"><div class="f-bar" style="width:${s.users / max * 100}%"></div></div><span class="f-num">${fmt(s.users)}人</span></div>`;
  }).join("")}</div>` + side.map((s) => `<p class="card-note" style="margin:8px 0 0">🔒 ${esc(s.label)}を開いた人: <strong>${fmt(s.users)}人</strong>（アプリ 3.14 より後の版から記録）</p>`).join("")
    + tableView([...data, ...side].map((s) => [s.label, fmt(s.users) + "人"]), ["段階", "人数"]);
}

// ───────── ストア ─────────
function renderStore(ctx) {
  const { rows, prevRows } = ctx;
  const conv = (rs) => { const pv = total(rs, V.pageViews), dl = total(rs, V.firstDl); return pv ? dl / pv * 100 : undefined; };
  const reviews = state.S.reviews || [];
  renderKpis("st-kpis", [
    kpi({ help: "kpiStoreImp", label: "ストアでの表示", value: total(rows, V.storeImp), prev: total(prevRows, V.storeImp), spark: series(ctx, V.storeImp), why: "Apple のレポート待ち" }),
    kpi({ help: "kpiPageViews", label: "ページ閲覧", value: total(rows, V.pageViews), prev: total(prevRows, V.pageViews), spark: series(ctx, V.pageViews), why: "Apple のレポート待ち" }),
    kpi({ help: "kpiDl", label: "初回ダウンロード", value: total(rows, V.firstDl), prev: total(prevRows, V.firstDl), spark: series(ctx, V.firstDl), why: "Apple のレポート待ち" }),
    kpi({ help: "kpiConv", label: "転換率", value: conv(rows), prev: conv(prevRows), format: pctFmt, why: "Apple のレポート待ち" }),
    kpi({ help: "kpiRating", label: "平均評価（本文付き）", value: reviews.length ? avg(reviews.map((r) => r.rating)) : undefined, format: (v) => "★" + v.toFixed(1), sub: `${reviews.length}件` }),
  ]);
  lineChart("st-impressions", [{ name: "表示回数", points: series(ctx, V.storeImp) }], { area: true });
  lineChart("st-downloads", [{ name: "初回DL", points: series(ctx, V.firstDl) }], { area: true });
  const src = {};
  rows.forEach((r) => Object.entries(r.appStore?.engagement?.bySource || {}).forEach(([k, v]) => { src[k] = (src[k] || 0) + v; }));
  barChart("st-sources", Object.entries(src).sort((a, b) => b[1] - a[1]).map(([k, v]) => ({ label: k, value: v })), { unit: "回" });
  barChart("st-rating", [5, 4, 3, 2, 1].map((n) => ({ label: "★" + n, value: reviews.filter((r) => r.rating === n).length })), { unit: "件" });
  renderReviews();
}

const reviewState = { star: "all", sort: "new" };
$("rv-sort").onchange = (e) => { reviewState.sort = e.target.value; renderReviews(); };
function renderReviews() {
  const all = state.S.reviews || [];
  $("rv-stars").innerHTML = ["all", 5, 4, 3, 2, 1].map((s) => {
    const n = s === "all" ? all.length : all.filter((r) => r.rating === s).length;
    return `<button data-star="${s}" aria-pressed="${String(reviewState.star) === String(s)}">${s === "all" ? "すべて" : "★" + s}（${n}）</button>`;
  }).join("");
  $("rv-stars").querySelectorAll("button").forEach((b) => { b.onclick = () => { reviewState.star = b.dataset.star; renderReviews(); }; });
  const byDate = (a, b) => (b.createdDate || "").localeCompare(a.createdDate || "");
  const sorters = {
    new: byDate,
    old: (a, b) => -byDate(a, b),
    high: (a, b) => b.rating - a.rating || byDate(a, b),
    low: (a, b) => a.rating - b.rating || byDate(a, b),
  };
  const list = all.filter((r) => reviewState.star === "all" || String(r.rating) === reviewState.star).sort(sorters[reviewState.sort]);
  $("st-reviews").innerHTML = list.length
    ? `<p class="count-note">${list.length}件（期間に関係なくすべて表示）</p><div class="reviews">${list.map((r) => `<div class="review"><div><span class="stars" aria-label="星${r.rating}">${"★".repeat(r.rating || 0)}${"☆".repeat(5 - (r.rating || 0))}</span> <strong>${esc(r.title)}</strong></div><div class="meta">${esc((r.createdDate || "").slice(0, 10))}・${esc(r.territory)}</div><p>${esc(r.body)}</p></div>`).join("")}</div>`
    : `<p class="empty">該当するレビューはありません</p>`;
}

// ───────── アプリ内 ─────────
function renderAppUsage(ctx) {
  const { rows, prevRows } = ctx;
  renderKpis("au-kpis", [
    kpi({ help: "kpiNew", label: "新規ユーザー（日本）", value: total(rows, V.newUsers), prev: total(prevRows, V.newUsers), spark: series(ctx, V.newUsers) }),
    kpi({ help: "kpiActive", label: "使った人（重複なし）", ...activeUnique(), spark: series(ctx, V.activeUsers) }),
    kpi({ help: "kpiMeetings", label: "自分会議の実施", value: total(rows, V.meetings), prev: total(prevRows, V.meetings), spark: series(ctx, V.meetings), sub: "件" }),
    kpi({ help: "kpiMeetingReady", label: "自分会議を使える人", value: meetingReady(), sub: meetingReadySub(), why: "性格の集計待ち" }),
  ]);
  lineChart("au-new", [{ name: "新規ユーザー", points: series(ctx, V.newUsers) }], { area: true });
  lineChart("au-active", [{ name: "アクティブユーザー", points: series(ctx, V.activeUsers) }], { area: true });
  renderFunnel("au-funnel", "au-funnel-note");
  sortableTable("au-weekly", [
    { key: "week", label: "週", format: (w) => `${w.slice(0, 4)}年 第${w.slice(4)}週` },
    { key: "newUsers", label: "新規", num: true },
    { key: "activeUsers", label: "アクティブ", num: true },
  ], state.S.weekly || [], { key: "week", dir: "desc" });
}

// 期間内に使った人数（重複なし）。日別を足すと同じ人を何度も数えるので、collector が期間の選択肢ごとに取った値を使う
function activeUnique() {
  const a = state.S.activeUnique || {};
  if (state.period === "custom") return { value: undefined, why: "期間を指定したときは出せません（7日・30日・90日・全期間で見てください）" };
  // 前の期間が計測開始（GA4_START）より前にかかるときは、0人ではなく「比較なし」にする
  const { prev } = ranges();
  const comparable = prev && prev.from >= GA4_START;
  return { value: a[state.period], prev: comparable ? a[state.period + "prev"] : undefined, why: "次の集計から表示されます" };
}

// 自分会議を使える（性格タイプが決まった＝成長段階が幼少期以上の）人数
function meetingReady() {
  const g = state.persona?.growthStages;
  return g ? (g.child || 0) + (g.adult || 0) : undefined;
}
function meetingReadySub() {
  const g = state.persona?.growthStages;
  if (!g) return "";
  const all = (g.baby || 0) + (g.child || 0) + (g.adult || 0);
  return all ? `全体の ${Math.round(meetingReady() / all * 100)}%（まだロック中 ${fmt(g.baby || 0)}人）` : "";
}

// ───────── 広告 ─────────
function renderAds(ctx) {
  const { rows, prevRows } = ctx;
  const ctr = (rs) => { const i = total(rs, V.adImp), c = total(rs, V.adClicks); return i ? c / i * 100 : undefined; };
  const ecpm = (rs) => { const i = total(rs, V.adImp), e = total(rs, V.adEarn); return i ? e / i * 1000 : undefined; };
  renderKpis("ad-kpis", [
    kpi({ help: "kpiAd", label: "推定収益", value: total(rows, V.adEarn), prev: total(prevRows, V.adEarn), format: yen, spark: series(ctx, V.adEarn), why: "AdMob 未接続" }),
    kpi({ help: "kpiAdImp", label: "表示回数", value: total(rows, V.adImp), prev: total(prevRows, V.adImp), spark: series(ctx, V.adImp), why: "AdMob 未接続" }),
    kpi({ help: "kpiCtr", label: "クリック率", value: ctr(rows), prev: ctr(prevRows), format: pctFmt, why: "この期間は表示がありません" }),
    kpi({ help: "kpiEcpm", label: "eCPM", value: ecpm(rows), prev: ecpm(prevRows), format: yen, why: "この期間は表示がありません" }),
  ]);
  lineChart("ad-earnings", [{ name: "推定収益", points: series(ctx, V.adEarn) }], { prefix: "¥", area: true });
  lineChart("ad-impressions", [{ name: "表示回数", points: series(ctx, V.adImp) }], { area: true });
}

// ───────── SNS ─────────
function postsIn(posts, r) { return (posts || []).filter((p) => inRange((p.timestamp || "").slice(0, 10), r)); }
function renderSns(ctx) {
  const { rows, prevRows, cur, prev } = ctx;
  const igPosts = postsIn(state.S.instagramPosts, cur), thPosts = postsIn(state.S.threadsPosts, cur);
  const sumOf = (ps, k) => (ps.length ? ps.reduce((a, p) => a + (p[k] || 0), 0) : undefined);
  const growth = (f) => { const a = first(rows, f), b = last(rows, f); return a != null && b != null ? b - a : undefined; };
  const growthText = (f) => (growth(f) != null ? `期間内 ${signed(growth(f))}` : "");
  renderKpis("sn-kpis", [
    kpi({ help: "kpiIgFollowers", label: "Instagram フォロワー", value: last(rows, V.igFollowers), spark: series(ctx, V.igFollowers), sub: growthText(V.igFollowers) }),
    kpi({ help: "kpiThFollowers", label: "Threads フォロワー", value: last(rows, V.thFollowers), spark: series(ctx, V.thFollowers), sub: growthText(V.thFollowers) }),
    kpi({ help: "kpiIgLinkTaps", label: "プロフィールのリンクのタップ", value: total(rows, V.igLinkTaps), prev: total(prevRows, V.igLinkTaps), spark: series(ctx, V.igLinkTaps), why: "記録は10/10から" }),
    kpi({ help: "kpiIgViews", label: "Instagram 投稿の再生", value: sumOf(igPosts, "views"), prev: prev ? sumOf(postsIn(state.S.instagramPosts, prev), "views") : undefined, sub: `${igPosts.length}本`, why: "期間内の投稿がありません" }),
    kpi({ help: "kpiThViews", label: "Threads 投稿の表示", value: sumOf(thPosts, "views"), prev: prev ? sumOf(postsIn(state.S.threadsPosts, prev), "views") : undefined, sub: `${thPosts.length}本`, why: "期間内の投稿がありません" }),
  ]);
  timingTables("sn-ig-timing", igPosts, "views", "再生");
  timingTables("sn-th-timing", thPosts, "views", "表示");
  lineChart("sn-ig-followers", [{ name: "フォロワー", points: series(ctx, V.igFollowers) }]);
  lineChart("sn-th-followers", [{ name: "フォロワー", points: series(ctx, V.thFollowers) }]);
  sortableTable("sn-ig-posts", [
    { key: "timestamp", label: "投稿日", format: (v) => (v || "").slice(0, 10) },
    { key: "type", label: "種類" },
    { key: "title", label: "内容", html: (p) => link(p.title, p.permalink), wrap: true },
    { key: "views", label: "再生", num: true }, { key: "reach", label: "リーチ", num: true },
    { key: "saved", label: "保存", num: true }, { key: "shares", label: "シェア", num: true },
    { key: "likes", label: "いいね", num: true }, { key: "comments", label: "コメント", num: true },
    { key: "ig_reels_avg_watch_time", label: "平均視聴", num: true, format: (v) => (v ? (v / 1000).toFixed(1) + "秒" : "–") },
  ], igPosts, { key: "timestamp", dir: "desc" }, "期間内の投稿がありません");
  sortableTable("sn-th-posts", [
    { key: "timestamp", label: "投稿日時", format: (v) => (v || "").slice(0, 16).replace("T", " ") },
    { key: "title", label: "内容", html: (p) => link(p.title, p.permalink), wrap: true },
    { key: "views", label: "表示", num: true }, { key: "likes", label: "いいね", num: true },
    { key: "replies", label: "返信", num: true }, { key: "reposts", label: "再投稿", num: true },
    { key: "quotes", label: "引用", num: true }, { key: "shares", label: "シェア", num: true },
  ], thPosts, { key: "timestamp", dir: "desc" }, "期間内の投稿がありません");
}

// 曜日ごと・時間帯ごとの成績（投稿日時を日本時間に直してまとめる）
const WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];
const timingMode = {};
function timingTables(id, posts, key, label) {
  const mode = timingMode[id] || "weekday";
  const groups = new Map();
  posts.forEach((p) => {
    const t = new Date(p.timestamp);
    if (Number.isNaN(t.getTime())) return;
    const jst = new Date(t.getTime() + (9 * 60 + t.getTimezoneOffset()) * 60000);
    const k = mode === "weekday" ? jst.getDay() : jst.getHours();
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(p[key] || 0);
  });
  const rows = [...groups.entries()].map(([k, vs]) => ({
    slot: k, slotLabel: mode === "weekday" ? WEEKDAYS[k] + "曜" : `${k}時台`,
    count: vs.length, median: median(vs), mean: vs.reduce((a, b) => a + b, 0) / vs.length,
  }));
  const el = $(id);
  const head = `<div class="chips" role="group" aria-label="まとめ方"><button data-m="weekday" aria-pressed="${mode === "weekday"}">曜日ごと</button><button data-m="hour" aria-pressed="${mode === "hour"}">時間帯ごと</button></div>`;
  const box = document.createElement("div");
  box.id = id + "-t";
  el.innerHTML = head;
  el.appendChild(box);
  sortableTable(box.id, [
    { key: "slot", label: mode === "weekday" ? "曜日" : "時間帯", num: true, format: (_v) => "", html: (r) => esc(r.slotLabel) },
    { key: "median", label: `${label}（中央値）`, num: true },
    { key: "mean", label: `${label}（平均）`, num: true, format: (v) => fmt(Math.round(v * 10) / 10) },
    { key: "count", label: "本数", num: true },
  ], rows, { key: "slot", dir: "asc" }, "期間内の投稿がありません");
  el.querySelectorAll(".chips button").forEach((b) => { b.onclick = () => { timingMode[id] = b.dataset.m; timingTables(id, posts, key, label); }; });
}
function median(xs) {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b), m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

// ───────── 性格 ─────────
// 元素の色は DARIAS のアプリ（character_detail_screen.dart の _elementColors）と同じ。グラフの系列色ではなく、元素カードの目印にだけ使う
const ELEMENTS = [
  ["炎", "🔥", "#E53935"], ["水", "💧", "#1E88E5"], ["風", "🍃", "#43A047"], ["土", "🪨", "#8D6E63"], ["氷", "❄️", "#4FC3F7"],
  ["雷", "⚡", "#FDD835"], ["光", "✨", "#FFB300"], ["闇", "🌙", "#6A1B9A"], ["無", "⚪", "#9E9E9E"],
];
const STAGE_LABELS = { baby: "赤ちゃん", child: "幼少期", adult: "大人" };
const GENDER_LABELS = { male: "男性", female: "女性", neutral: "その他" };
const BADGE_ORDER = ["0", "1-9", "10-19", "20"];

function renderPersonality() {
  const P = state.persona;
  if (!P) {
    ["ps-elements", "ps-types", "ps-stages", "ps-badges", "ps-gender"].forEach((id) => { $(id).innerHTML = `<p class="empty">まだ集計されていません</p>`; });
    return;
  }
  const decided = ELEMENTS.reduce((a, [e]) => a + (P.elements?.[e] || 0), 0);
  renderKpis("ps-kpis", [
    kpi({ help: "kpiCharacters", label: "キャラクター数", value: P.totalCharacters }),
    kpi({ help: "kpiDecided", label: "元素が決まった数", value: decided, sub: P.totalCharacters ? `全体の ${Math.round(decided / P.totalCharacters * 100)}%` : "" }),
    kpi({ help: "kpiTypes", label: "タイプ名の種類", value: Object.keys(P.typeNames || {}).filter((k) => k && k !== "不明").length, sub: "全18種類のうち" }),
  ]);
  const maxEl = Math.max(1, ...ELEMENTS.map(([e]) => P.elements?.[e] || 0));
  const undecided = P.elements?.["未確定"] || 0;
  $("ps-elements").innerHTML = ELEMENTS.map(([e, icon, color], i) => {
    const n = P.elements?.[e] || 0;
    return `<div class="el ${n ? "" : "empty-el"}" style="--el-color:${color};animation-delay:${i * 35}ms">
      <div class="el-icon" aria-hidden="true">${icon}</div><div class="el-name">${e}</div>
      <div class="el-count">${fmt(n)}<small>人</small></div>
      <div class="el-share">元素が決まった人の ${decided ? Math.round(n / decided * 100) : 0}%</div>
      <div class="el-bar"><i style="width:${n / maxEl * 100}%"></i></div></div>`;
  }).join("") + `<div class="el" style="--el-color:#bdbdbd"><div class="el-icon" aria-hidden="true">🥚</div><div class="el-name">未確定</div><div class="el-count">${fmt(undecided)}<small>人</small></div><div class="el-share">まだ元素が決まっていない</div></div>`;
  barChart("ps-types", Object.entries(P.typeNames || {}).filter(([k]) => k && k !== "不明").sort((a, b) => b[1] - a[1]).map(([k, v]) => ({ label: k, value: v })), { unit: "人" });
  barChart("ps-stages", ["baby", "child", "adult"].map((k) => ({ label: STAGE_LABELS[k], value: P.growthStages?.[k] || 0 })), { unit: "人" });
  barChart("ps-badges", BADGE_ORDER.map((k) => ({ label: k === "20" ? "20（すべて）" : k + "問", value: P.badgeBuckets?.[k] || 0 })), { unit: "人" });
  barChart("ps-gender", Object.entries(P.gender || {}).map(([k, v]) => ({ label: GENDER_LABELS[k] || k, value: v })), { unit: "人" });
}

// ───────── ヘルプ ─────────
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".help");
  if (btn) { e.stopPropagation(); toggleHelp(btn); return; }
  if (!e.target.closest("#help-pop")) hideHelp();
});
document.querySelector(".help-close").onclick = hideHelp;
document.addEventListener("keydown", (e) => { if (e.key === "Escape") hideHelp(); });
let helpOwner = null;
function toggleHelp(btn) {
  if (helpOwner === btn) { hideHelp(); return; }
  hideHelp();
  const [title, what, how] = HELP[btn.dataset.help] || ["", "", ""];
  $("help-title").textContent = title;
  $("help-what").textContent = what;
  $("help-how").textContent = how;
  const pop = $("help-pop");
  pop.hidden = false;
  const r = btn.getBoundingClientRect();
  const maxLeft = window.scrollX + document.documentElement.clientWidth - pop.offsetWidth - 16;
  pop.style.left = Math.max(16, Math.min(r.right + window.scrollX - pop.offsetWidth, maxLeft)) + "px";
  pop.style.top = (r.bottom + window.scrollY + 6) + "px";
  btn.setAttribute("aria-expanded", "true");
  helpOwner = btn;
}
function hideHelp() {
  $("help-pop").hidden = true;
  helpOwner?.setAttribute("aria-expanded", "false");
  helpOwner = null;
}

// ───────── 部品 ─────────
// 列名を押すと並べ替えられる表
const sortState = {};
function sortableTable(id, cols, rows, def, emptyText = "データがありません") {
  const el = $(id);
  if (!rows.length) { el.innerHTML = `<p class="empty">${esc(emptyText)}</p>`; return; }
  const st = sortState[id] || (sortState[id] = { ...def });
  const col = cols.find((c) => c.key === st.key) || cols[0];
  const sorted = [...rows].sort((a, b) => {
    const x = a[col.key], y = b[col.key];
    const c = col.num ? (x ?? -Infinity) - (y ?? -Infinity) : String(x ?? "").localeCompare(String(y ?? ""));
    return st.dir === "asc" ? c : -c;
  });
  el.innerHTML = `<p class="count-note">${rows.length}件・列名を押すと並べ替え</p><div class="table-wrap table-scroll"><table><thead><tr>${cols.map((c) =>
    `<th class="sortable ${c.num ? "num" : ""}" data-key="${c.key}" aria-sort="${c.key === st.key ? (st.dir === "asc" ? "ascending" : "descending") : "none"}">${esc(c.label)}${c.key === st.key ? `<span class="arrow">${st.dir === "asc" ? "▲" : "▼"}</span>` : ""}</th>`).join("")}</tr></thead><tbody>${
    sorted.map((r) => `<tr>${cols.map((c) => {
      if (c.html) return `<td class="${c.wrap ? "wrap" : ""}">${c.html(r)}</td>`;
      const v = r[c.key];
      const text = c.format ? c.format(v) : (c.num ? fmt(v) : (v ?? "–"));
      return `<td class="${c.num ? "num" : ""}">${esc(text)}</td>`;
    }).join("")}</tr>`).join("")}</tbody></table></div>`;
  el.querySelectorAll("th.sortable").forEach((th) => {
    th.onclick = () => {
      const k = th.dataset.key;
      const c = cols.find((x) => x.key === k);
      st.dir = st.key === k ? (st.dir === "asc" ? "desc" : "asc") : (c.num ? "desc" : "asc");
      st.key = k;
      sortableTable(id, cols, rows, def, emptyText);
    };
  });
}

// 表でも見られるようにする（色だけに頼らない・読み上げにも使える）
function tableView(rows, headers) {
  return `<details class="table-view"><summary>表で見る</summary><div class="table-wrap"><table><thead><tr>${headers.map((h, i) => `<th class="${i ? "num" : ""}">${esc(h)}</th>`).join("")}</tr></thead><tbody>${
    rows.map((r) => `<tr>${r.map((c, i) => `<td class="${i ? "num" : ""}">${esc(c)}</td>`).join("")}</tr>`).join("")}</tbody></table></div></details>`;
}

// 横棒（内訳）。単一色で、値は棒の右に書く
function barChart(id, items, opts = {}) {
  const el = $(id);
  el.className = "chart";
  if (!items.length || items.every((i) => !i.value)) { el.innerHTML = `<p class="empty">データがありません</p>`; return; }
  const W = 460, rowH = 26, labelW = Math.min(170, Math.max(...items.map((i) => textWidth(i.label))) + 12), valueW = 56;
  const H = items.length * rowH;
  const max = Math.max(...items.map((i) => i.value || 0)) || 1;
  const plotW = W - labelW - valueW;
  const bars = items.map((it, i) => {
    const y = i * rowH;
    const w = Math.max((it.value || 0) / max * plotW, it.value ? 2 : 0);
    return `<g class="hit" data-tip="${esc(`${it.label}: ${fmt(it.value)}${opts.unit || ""}`)}">
      <rect x="0" y="${y}" width="${W}" height="${rowH}" fill="transparent"/>
      <text x="${labelW - 8}" y="${y + rowH / 2 + 4}" text-anchor="end">${esc(clip(it.label, 14))}</text>
      <path d="${roundedBar(labelW, y + 5, w, rowH - 10)}" fill="var(--series-1)"/>
      <text x="${labelW + w + 6}" y="${y + rowH / 2 + 4}" style="fill:var(--text)">${fmt(it.value)}</text></g>`;
  }).join("");
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img">${bars}</svg>`
    + tableView(items.map((i) => [i.label, fmt(i.value) + (opts.unit || "")]), ["項目", "値"]);
  bindTips(el);
}

// 縦棒（月別の推移）
function columnChart(id, items, opts = {}) {
  const el = $(id);
  el.className = "chart";
  if (!items.length) { el.innerHTML = `<p class="empty">データがありません</p>`; return; }
  const W = 460, H = 200, padL = 28, padB = 22, padT = 16;
  const max = niceMax(Math.max(...items.map((i) => i.value)));
  const slot = (W - padL) / items.length, bw = Math.max(Math.min(slot - 2, 28), 2);
  const y = (v) => padT + (H - padT - padB) * (1 - v / max);
  const grid = [0, max / 2, max].map((v) => `<line class="grid-line" x1="${padL}" x2="${W}" y1="${y(v)}" y2="${y(v)}"/><text x="${padL - 4}" y="${y(v) + 4}" text-anchor="end">${fmt(v)}</text>`).join("");
  const step = Math.ceil(items.length / 6);
  const cols = items.map((it, i) => {
    const x = padL + i * slot + (slot - bw) / 2;
    const h = H - padB - y(it.value);
    return `<g class="hit" data-tip="${esc(`${it.label}: ${fmt(it.value)}${opts.unit || ""}`)}">
      <rect x="${padL + i * slot}" y="${padT}" width="${slot}" height="${H - padT - padB}" fill="transparent"/>
      <path d="${roundedCol(x, H - padB, bw, h)}" fill="var(--series-1)"/>
      ${i % step === 0 || i === items.length - 1 ? `<text x="${x + bw / 2}" y="${H - 6}" text-anchor="middle">${esc(it.label.slice(2))}</text>` : ""}</g>`;
  }).join("");
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img">${grid}<line class="axis-line" x1="${padL}" x2="${W}" y1="${H - padB}" y2="${H - padB}"/>${cols}</svg>`
    + tableView(items.map((i) => [i.label, fmt(i.value) + (opts.unit || "")]), ["月", "値"]);
  bindTips(el);
}

// 折れ線（日別の推移）。値の無い日は線を切る。ホバーで縦線と値を出す
let gradId = 0;
function lineChart(id, series, opts = {}) {
  const el = $(id);
  el.className = "chart";
  const has = series.some((s) => s.points.some(([, v]) => v != null));
  if (!has) { el.innerHTML = `<p class="empty">この期間のデータはありません</p>`; return; }
  const dates = series[0].points.map(([d]) => d);
  const W = 460, H = 200, padL = 36, padB = 22, padT = 12, padR = 8;
  const max = niceMax(Math.max(...series.flatMap((s) => s.points.map(([, v]) => v || 0))));
  const x = (i) => padL + (dates.length === 1 ? (W - padL - padR) / 2 : i / (dates.length - 1) * (W - padL - padR));
  const y = (v) => padT + (H - padT - padB) * (1 - v / max);
  const grid = [0, max / 2, max].map((v) => `<line class="grid-line" x1="${padL}" x2="${W - padR}" y1="${y(v)}" y2="${y(v)}"/><text x="${padL - 4}" y="${y(v) + 4}" text-anchor="end">${(opts.prefix || "") + fmt(v)}</text>`).join("");
  const colors = ["var(--series-1)", "var(--series-2)"];
  const gid = "g" + (++gradId);
  const paths = series.map((s, si) => {
    let d = "", pen = false, seg = [];
    const segs = [];
    s.points.forEach(([, v], i) => {
      if (v == null) { pen = false; if (seg.length) segs.push(seg); seg = []; return; }
      d += `${pen ? "L" : "M"}${x(i).toFixed(1)},${y(v).toFixed(1)}`;
      seg.push([x(i), y(v)]);
      pen = true;
    });
    if (seg.length) segs.push(seg);
    // 面は1系列のときだけ（重なると読めなくなるため）
    const area = opts.area && series.length === 1
      ? segs.filter((g) => g.length > 1).map((g) => `<path d="M${g[0][0]},${H - padB}${g.map(([a, b]) => `L${a.toFixed(1)},${b.toFixed(1)}`).join("")}L${g[g.length - 1][0]},${H - padB}Z" fill="url(#${gid})"/>`).join("")
      : "";
    const count = s.points.filter(([, v]) => v != null).length;
    const dots = count <= 3 ? s.points.map(([, v], i) => (v != null ? `<circle cx="${x(i)}" cy="${y(v)}" r="4" fill="${colors[si]}"/>` : "")).join("") : "";
    return `${area}<path d="${d}" fill="none" stroke="${colors[si]}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>${dots}`;
  }).join("");
  const ticks = [0, Math.floor((dates.length - 1) / 2), dates.length - 1].filter((v, i, a) => a.indexOf(v) === i)
    .map((i) => `<text x="${x(i)}" y="${H - 6}" text-anchor="middle">${dates[i].slice(5).replace("-", "/")}</text>`).join("");
  const legend = series.length > 1 ? `<div class="legend">${series.map((s, i) => `<span><i style="background:${colors[i]}"></i>${esc(s.name)}</span>`).join("")}</div>` : "";
  el.innerHTML = `${legend}<svg viewBox="0 0 ${W} ${H}" role="img"><defs><linearGradient id="${gid}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="var(--series-1)" stop-opacity=".22"/><stop offset="1" stop-color="var(--series-1)" stop-opacity="0"/></linearGradient></defs>${grid}<line class="axis-line" x1="${padL}" x2="${W - padR}" y1="${H - padB}" y2="${H - padB}"/>${paths}${ticks}
    <line class="cross" x1="0" x2="0" y1="${padT}" y2="${H - padB}" stroke="var(--muted)" stroke-width="1" visibility="hidden"/>
    <rect class="overlay" x="${padL}" y="${padT}" width="${W - padL - padR}" height="${H - padT - padB}" fill="transparent"/></svg>`
    + tableView(dates.map((d, i) => [d, ...series.map((s) => { const v = s.points[i][1]; return v == null ? "–" : (opts.prefix || "") + fmt(v); })]).filter((r) => r.slice(1).some((c) => c !== "–")), ["日付", ...series.map((s) => s.name)]);

  // 十字線のツールチップ（最寄りの日付に吸着する）
  const svg = el.querySelector("svg"), cross = el.querySelector(".cross"), overlay = el.querySelector(".overlay");
  const move = (ev) => {
    const pt = svg.createSVGPoint();
    const e = ev.touches ? ev.touches[0] : ev;
    pt.x = e.clientX; pt.y = e.clientY;
    const p = pt.matrixTransform(svg.getScreenCTM().inverse());
    const idx = dates.length === 1 ? 0 : Math.max(0, Math.min(dates.length - 1, Math.round((p.x - padL) / (W - padL - padR) * (dates.length - 1))));
    cross.setAttribute("x1", x(idx)); cross.setAttribute("x2", x(idx)); cross.setAttribute("visibility", "visible");
    const lines = series.map((s) => { const v = s.points[idx][1]; return `${s.name}: ${v == null ? "–" : (opts.prefix || "") + fmt(v)}`; });
    showTip(e, `${dates[idx]}<br>${lines.map(esc).join("<br>")}`);
  };
  overlay.addEventListener("mousemove", move);
  overlay.addEventListener("touchstart", move, { passive: true });
  overlay.addEventListener("mouseleave", () => { cross.setAttribute("visibility", "hidden"); hideTip(); });
}

function bindTips(el) {
  el.querySelectorAll(".hit").forEach((g) => {
    g.addEventListener("mousemove", (e) => showTip(e, esc(g.dataset.tip)));
    g.addEventListener("mouseleave", hideTip);
  });
}
function showTip(e, html) {
  const t = $("tooltip");
  t.innerHTML = html;
  t.hidden = false;
  t.style.left = Math.min(e.clientX + 12, window.innerWidth - t.offsetWidth - 8) + "px";
  t.style.top = (e.clientY + 14) + "px";
}
function hideTip() { $("tooltip").hidden = true; }

// 棒の先端だけ角を丸める（4px）
function roundedBar(x, y, w, h) {
  if (w <= 0) return "";
  const r = Math.min(4, w, h / 2);
  return `M${x},${y}H${x + w - r}Q${x + w},${y} ${x + w},${y + r}V${y + h - r}Q${x + w},${y + h} ${x + w - r},${y + h}H${x}Z`;
}
function roundedCol(x, base, w, h) {
  if (h <= 0) return "";
  const r = Math.min(4, h, w / 2);
  return `M${x},${base}V${base - h + r}Q${x},${base - h} ${x + r},${base - h}H${x + w - r}Q${x + w},${base - h} ${x + w},${base - h + r}V${base}Z`;
}

function niceMax(v) {
  if (!v || v <= 0) return 1;
  const p = Math.pow(10, Math.floor(Math.log10(v)));
  return [1, 2, 2.5, 5, 10].map((m) => m * p).find((m) => m >= v);
}
function avg(xs) { return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0; }
function textWidth(s) { return [...String(s)].reduce((a, c) => a + (c.charCodeAt(0) > 255 ? 11 : 6.5), 0); }
function clip(s, n) { s = String(s ?? ""); return [...s].length > n ? [...s].slice(0, n).join("") + "…" : s; }
function fmt(v) { return v == null || Number.isNaN(v) ? "–" : Number(v).toLocaleString("ja-JP", { maximumFractionDigits: 1 }); }
function yen(v) { return v == null ? "–" : "¥" + Number(v).toLocaleString("ja-JP", { maximumFractionDigits: v < 100 ? 1 : 0 }); }
function pctFmt(v) { return v == null ? "–" : v.toFixed(v < 10 ? 2 : 1) + "%"; }
function signed(v) { return v == null ? "–" : (v > 0 ? "+" : v < 0 ? "−" : "±") + fmt(Math.abs(v)); }
function fmtDay(s) { return s ? s.slice(5).replace("-", "/") : ""; }
function fmtDateTime(d) { return d.toLocaleString("ja-JP", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" }); }
function esc(s) { return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
function link(text, url) { return url && /^https:\/\//.test(url) ? `<a href="${esc(url)}" target="_blank" rel="noopener">${esc(text || "（本文なし）")}</a>` : esc(text); }
function remember(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* 保存できなくても動く */ } }
function recall(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }

// 前回のタブと期間を戻す（期間の指定は日付が古くなるので戻さない）
const savedTab = recall("dash-tab");
if (savedTab) document.querySelector(`.tabs button[data-tab="${savedTab}"]`)?.click();
const savedPeriod = recall("dash-period");
if (savedPeriod && savedPeriod !== "custom") {
  state.period = savedPeriod;
  document.querySelectorAll(".periods button").forEach((b) => b.setAttribute("aria-pressed", b.dataset.period === savedPeriod));
}
