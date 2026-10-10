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
const DAYS = 90;

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const $ = (id) => document.getElementById(id);

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
    try { localStorage.setItem("dash-tab", btn.dataset.tab); } catch (e) { /* 保存できなくても動く */ }
  };
});
try {
  const saved = localStorage.getItem("dash-tab");
  if (saved) document.querySelector(`.tabs button[data-tab="${saved}"]`)?.click();
} catch (e) { /* 既定のタブのまま */ }

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
    if (body.status === "skipped") showStatus(body.reason);
    else showStatus("集計しました。");
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

// ───────── データ読み込み ─────────
async function loadAll() {
  try {
    const [latest, summary, dailySnap, personaSnap] = await Promise.all([
      getDoc(doc(db, "admin_metrics", "latest")),
      getDoc(doc(db, "admin_metrics", "summary")),
      getDocs(query(collection(db, "admin_metrics", "daily", "days"), orderBy("date", "desc"), limit(DAYS))),
      getDocs(query(collection(db, "admin_metrics", "personality", "days"), orderBy("date", "desc"), limit(1))),
    ]);
    const L = latest.data() || {};
    const S = summary.data() || {};
    const daily = dailySnap.docs.map((d) => d.data()).sort((a, b) => a.date.localeCompare(b.date));
    const persona = personaSnap.docs[0]?.data() || null;
    renderHeader(L);
    renderOverview(S, daily);
    renderStore(S, daily);
    renderAppUsage(S, daily);
    renderAds(daily);
    renderSns(S, daily);
    renderPersonality(persona);
  } catch (e) {
    showStatus("データを読めませんでした: " + e.message);
  }
}

const SOURCE_LABELS = {
  appStore: "App Store", ga4: "アプリ内（GA4）", admob: "AdMob", instagram: "Instagram",
  threads: "Threads", signups: "登録数", personality: "性格",
};

function renderHeader(L) {
  const at = L.finishedAt?.toDate?.();
  $("updated").textContent = at ? `最終更新 ${fmtDateTime(at)}（${L.trigger === "manual" ? "手動" : "自動"}）` : "まだ集計されていません";
  const errs = Object.keys(L.errors || {});
  $("source-errors").hidden = errs.length === 0;
  $("source-errors").textContent = errs.length
    ? "取得できなかったもの: " + errs.map((k) => `${SOURCE_LABELS[k] || k}（${L.errors[k]}）`).join(" ／ ")
    : "";
}

// ───────── 各タブ ─────────
function renderOverview(S, daily) {
  const last7 = daily.slice(-7);
  // 1日もデータが無ければ undefined（「0」と「まだ無い」を区別する）
  const sum = (rows, f) => rows.some((r) => f(r) != null) ? rows.reduce((a, r) => a + (f(r) || 0), 0) : undefined;
  const igY = lastValue(daily, (r) => r.instagram?.yesterday?.views);
  const thY = lastValue(daily, (r) => r.threads?.yesterday?.views);
  tiles("overview-tiles", [
    { label: "SNS表示（前日）", value: fmt((igY ?? 0) + (thY ?? 0)), sub: `Instagram ${fmt(igY)}・Threads ${fmt(thY)}` },
    { label: "ストア表示（直近7日）", ...pending(sum(last7, (r) => r.appStore?.engagement?.byType?.Impression), "レポート待ち") },
    { label: "初回DL（直近7日）", ...pending(sum(last7, (r) => r.appStore ? firstDownloads(r) : undefined), "レポート待ち") },
    { label: "新規ユーザー（直近7日・日本）", ...pending(sum(last7, (r) => r.ga4?.newUsers)) },
    { label: "広告収益（直近7日）", ...pending(sum(last7, (r) => r.admob?.earningsJPY), "AdMob 未接続", (v) => "¥" + fmt(Math.round(v))) },
  ]);
  barChart("ov-funnel", (S.funnelAll || []).map((f) => ({ label: f.label, value: f.users })), { unit: "人" });
  // Firestore の map は順序を保たないので月で並べ直す
  const months = Object.entries(S.signupsByMonth || {}).sort(([a], [b]) => a.localeCompare(b)).map(([m, v]) => ({ label: m, value: v }));
  columnChart("ov-signups", months, { unit: "件" });
}

function pending(v, why = "データなし", format = fmt) {
  return v == null ? { value: "–", sub: why } : { value: format(v) };
}

function firstDownloads(r) {
  const t = r.appStore?.downloads?.byType || {};
  return Object.entries(t).filter(([k]) => k.toLowerCase().startsWith("first")).reduce((a, [, v]) => a + v, 0);
}

function renderStore(S, daily) {
  lineChart("st-impressions", [{ name: "表示回数", points: daily.map((r) => [r.date, r.appStore?.engagement?.byType?.Impression]) }]);
  lineChart("st-downloads", [{ name: "初回DL", points: daily.map((r) => [r.date, r.appStore ? firstDownloads(r) : undefined]) }]);
  const src = {};
  daily.forEach((r) => Object.entries(r.appStore?.engagement?.bySource || {}).forEach(([k, v]) => { src[k] = (src[k] || 0) + v; }));
  barChart("st-sources", Object.entries(src).sort((a, b) => b[1] - a[1]).map(([k, v]) => ({ label: k, value: v })), { unit: "回" });
  const reviews = S.reviews || [];
  $("st-reviews").innerHTML = reviews.length
    ? reviews.slice(0, 10).map((r) => `<div class="review"><div class="meta">${"★".repeat(r.rating || 0)}${"☆".repeat(5 - (r.rating || 0))}　${esc((r.createdDate || "").slice(0, 10))}・${esc(r.territory)}</div><strong>${esc(r.title)}</strong><p>${esc(r.body)}</p></div>`).join("")
    : `<p class="empty">本文付きのレビューはありません</p>`;
}

function renderAppUsage(S, daily) {
  lineChart("au-new", [{ name: "新規ユーザー", points: daily.map((r) => [r.date, r.ga4?.newUsers]) }]);
  lineChart("au-active", [{ name: "アクティブユーザー", points: daily.map((r) => [r.date, r.ga4?.activeUsers]) }]);
  barChart("au-funnel", (S.funnel30 || []).map((f) => ({ label: f.label, value: f.users })), { unit: "人" });
  table("au-weekly", ["週", "新規", "アクティブ"], (S.weekly || []).map((w) => [`${w.week.slice(0, 4)}年 第${w.week.slice(4)}週`, w.newUsers, w.activeUsers]));
}

function renderAds(daily) {
  const rows = daily.filter((r) => r.admob);
  const last30 = rows.slice(-30);
  const earn = last30.reduce((a, r) => a + r.admob.earningsJPY, 0);
  const imp = last30.reduce((a, r) => a + r.admob.impressions, 0);
  const clicks = last30.reduce((a, r) => a + r.admob.clicks, 0);
  if (!rows.length) {
    tiles("ads-tiles", [{ label: "AdMob", value: "–", sub: "まだ接続されていません" }]);
  } else tiles("ads-tiles", [
    { label: "推定収益（直近30日）", value: "¥" + fmt(Math.round(earn)) },
    { label: "表示回数（直近30日）", value: fmt(imp) },
    { label: "クリック率", value: imp ? (clicks / imp * 100).toFixed(2) + "%" : "–" },
    { label: "eCPM（1000回あたり）", value: imp ? "¥" + (earn / imp * 1000).toFixed(0) : "–" },
  ]);
  lineChart("ad-earnings", [{ name: "推定収益", points: daily.map((r) => [r.date, r.admob?.earningsJPY]) }], { prefix: "¥" });
  lineChart("ad-impressions", [{ name: "表示回数", points: daily.map((r) => [r.date, r.admob?.impressions]) }]);
}

function renderSns(S, daily) {
  const ig = lastValue(daily, (r) => r.instagram?.followers);
  const th = lastValue(daily, (r) => r.threads?.followers);
  const igY = [...daily].reverse().find((r) => r.instagram)?.instagram?.yesterday || {};
  const thY = [...daily].reverse().find((r) => r.threads)?.threads?.yesterday || {};
  tiles("sns-tiles", [
    { label: "Instagram フォロワー", value: fmt(ig), sub: `前日のリーチ ${fmt(igY.reach)}・プロフィールのリンク ${fmt(igY.profile_links_taps)}` },
    { label: "Threads フォロワー", value: fmt(th), sub: `前日の表示 ${fmt(thY.views)}・いいね ${fmt(thY.likes)}` },
  ]);
  lineChart("sn-ig-followers", [{ name: "フォロワー", points: daily.map((r) => [r.date, r.instagram?.followers]) }]);
  lineChart("sn-th-followers", [{ name: "フォロワー", points: daily.map((r) => [r.date, r.threads?.followers]) }]);
  table("sn-ig-posts", ["投稿日", "種類", "内容", "再生", "リーチ", "保存", "シェア", "いいね", "平均視聴"],
    (S.instagramPosts || []).map((p) => [p.timestamp.slice(0, 10), p.type, link(p.title, p.permalink), p.views, p.reach, p.saved, p.shares, p.likes,
      p.ig_reels_avg_watch_time ? (p.ig_reels_avg_watch_time / 1000).toFixed(1) + "秒" : "–"]), { html: [2] });
  table("sn-th-posts", ["投稿日", "内容", "表示", "いいね", "返信", "再投稿", "シェア"],
    (S.threadsPosts || []).map((p) => [p.timestamp.slice(0, 10), link(p.title, p.permalink), p.views, p.likes, p.replies, p.reposts, p.shares]), { html: [1] });
}

const STAGE_LABELS = { baby: "赤ちゃん", child: "幼少期", adult: "大人" };
const GENDER_LABELS = { male: "男性", female: "女性", neutral: "その他" };
const BADGE_ORDER = ["0", "1-9", "10-19", "20"];

function renderPersonality(P) {
  if (!P) {
    ["ps-elements", "ps-types", "ps-stages", "ps-badges", "ps-gender"].forEach((id) => { $(id).innerHTML = `<p class="empty">まだ集計されていません</p>`; });
    return;
  }
  const decided = Object.entries(P.elements || {}).filter(([k]) => k !== "未確定").reduce((a, [, v]) => a + v, 0);
  tiles("ps-tiles", [
    { label: "キャラクター数", value: fmt(P.totalCharacters) },
    { label: "元素が決まった数", value: fmt(decided), sub: P.totalCharacters ? `全体の ${(decided / P.totalCharacters * 100).toFixed(0)}%` : "" },
    { label: "タイプの種類", value: fmt(Object.keys(P.typeNames || {}).length) },
  ]);
  // 9元素は件数に関係なく常に並べる（0人の元素があることも分かるように）
  const ELEMENTS = ["炎", "風", "雷", "光", "水", "土", "氷", "闇", "無"];
  const el = ELEMENTS.map((e) => ({ label: e, value: P.elements?.[e] || 0 }));
  if (P.elements?.["未確定"]) el.push({ label: "未確定", value: P.elements["未確定"], muted: true });
  barChart("ps-elements", el, { unit: "人" });
  barChart("ps-types", Object.entries(P.typeNames || {}).filter(([k]) => k && k !== "不明").sort((a, b) => b[1] - a[1]).slice(0, 15).map(([k, v]) => ({ label: k, value: v })), { unit: "人" });
  barChart("ps-stages", ["baby", "child", "adult"].map((k) => ({ label: STAGE_LABELS[k], value: P.growthStages?.[k] || 0 })), { unit: "人" });
  barChart("ps-badges", BADGE_ORDER.map((k) => ({ label: k === "20" ? "20（すべて）" : k + "問", value: P.badgeBuckets?.[k] || 0 })), { unit: "人" });
  barChart("ps-gender", Object.entries(P.gender || {}).map(([k, v]) => ({ label: GENDER_LABELS[k] || k, value: v })), { unit: "人" });
}

// ───────── 部品 ─────────
function tiles(id, items) {
  $(id).innerHTML = items.map((t) => `<div class="tile"><div class="label">${esc(t.label)}</div><div class="value">${esc(t.value)}</div>${t.sub ? `<div class="sub">${esc(t.sub)}</div>` : ""}</div>`).join("");
}

function table(id, headers, rows, opts = {}) {
  if (!rows.length) { $(id).innerHTML = `<p class="empty">データがありません</p>`; return; }
  const html = opts.html || [];
  $(id).innerHTML = `<div class="table-wrap"><table><thead><tr>${headers.map((h, i) => `<th class="${i && !html.includes(i) ? "num" : ""}">${esc(h)}</th>`).join("")}</tr></thead><tbody>${
    rows.map((r) => `<tr>${r.map((c, i) => html.includes(i) ? `<td class="wrap">${c}</td>` : `<td class="${typeof c === "number" ? "num" : ""}">${esc(typeof c === "number" ? fmt(c) : (c ?? "–"))}</td>`).join("")}</tr>`).join("")
  }</tbody></table></div>`;
}

// 表でも見られるようにする（色だけに頼らない・読み上げにも使える）
function tableView(rows, headers) {
  return `<details class="table-view"><summary>表で見る</summary><div class="table-wrap"><table><thead><tr>${headers.map((h, i) => `<th class="${i ? "num" : ""}">${esc(h)}</th>`).join("")}</tr></thead><tbody>${
    rows.map((r) => `<tr>${r.map((c, i) => `<td class="${i ? "num" : ""}">${esc(c)}</td>`).join("")}</tr>`).join("")}</tbody></table></div></details>`;
}

// 横棒（ファネル・内訳）。単一色で、値は棒の右に書く
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
    const color = it.muted ? "var(--muted)" : "var(--series-1)";
    return `<g class="hit" data-tip="${esc(`${it.label}: ${fmt(it.value)}${opts.unit || ""}`)}">
      <rect x="0" y="${y}" width="${W}" height="${rowH}" fill="transparent"/>
      <text x="${labelW - 8}" y="${y + rowH / 2 + 4}" text-anchor="end">${esc(clip(it.label, 14))}</text>
      <path d="${roundedBar(labelW, y + 5, w, rowH - 10)}" fill="${color}"/>
      <text x="${labelW + w + 6}" y="${y + rowH / 2 + 4}" style="fill:var(--text)">${fmt(it.value)}</text></g>`;
  }).join("");
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(el.previousElementSibling?.textContent || "")}">${bars}</svg>`
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
function lineChart(id, series, opts = {}) {
  const el = $(id);
  el.className = "chart";
  const has = series.some((s) => s.points.some(([, v]) => v !== undefined && v !== null));
  if (!has) { el.innerHTML = `<p class="empty">データがありません（集計が始まるとここに出ます）</p>`; return; }
  const dates = [...new Set(series.flatMap((s) => s.points.filter(([, v]) => v != null).map(([d]) => d)))].sort();
  const W = 460, H = 200, padL = 36, padB = 22, padT = 12, padR = 8;
  const max = niceMax(Math.max(...series.flatMap((s) => s.points.map(([, v]) => v || 0))));
  const x = (d) => padL + (dates.length === 1 ? (W - padL - padR) / 2 : dates.indexOf(d) / (dates.length - 1) * (W - padL - padR));
  const y = (v) => padT + (H - padT - padB) * (1 - v / max);
  const grid = [0, max / 2, max].map((v) => `<line class="grid-line" x1="${padL}" x2="${W - padR}" y1="${y(v)}" y2="${y(v)}"/><text x="${padL - 4}" y="${y(v) + 4}" text-anchor="end">${(opts.prefix || "") + fmt(v)}</text>`).join("");
  const colors = ["var(--series-1)", "var(--series-2)"];
  const paths = series.map((s, si) => {
    const map = new Map(s.points);
    let d = "", pen = false;
    dates.forEach((dt) => {
      const v = map.get(dt);
      if (v == null) { pen = false; return; }
      d += `${pen ? "L" : "M"}${x(dt).toFixed(1)},${y(v).toFixed(1)}`;
      pen = true;
    });
    const dots = dates.length <= 2 ? dates.map((dt) => map.get(dt) != null ? `<circle cx="${x(dt)}" cy="${y(map.get(dt))}" r="4" fill="${colors[si]}"/>` : "").join("") : "";
    return `<path d="${d}" fill="none" stroke="${colors[si]}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>${dots}`;
  }).join("");
  const ticks = [dates[0], dates[Math.floor(dates.length / 2)], dates[dates.length - 1]].filter((v, i, a) => a.indexOf(v) === i)
    .map((d) => `<text x="${x(d)}" y="${H - 6}" text-anchor="middle">${d.slice(5).replace("-", "/")}</text>`).join("");
  const legend = series.length > 1 ? `<div class="legend">${series.map((s, i) => `<span><i style="background:${colors[i]}"></i>${esc(s.name)}</span>`).join("")}</div>` : "";
  el.innerHTML = `${legend}<svg viewBox="0 0 ${W} ${H}" role="img">${grid}<line class="axis-line" x1="${padL}" x2="${W - padR}" y1="${H - padB}" y2="${H - padB}"/>${paths}${ticks}
    <line class="cross" x1="0" x2="0" y1="${padT}" y2="${H - padB}" stroke="var(--muted)" stroke-width="1" visibility="hidden"/>
    <rect class="overlay" x="${padL}" y="${padT}" width="${W - padL - padR}" height="${H - padT - padB}" fill="transparent"/></svg>`
    + tableView(dates.map((d) => [d, ...series.map((s) => { const v = new Map(s.points).get(d); return v == null ? "–" : (opts.prefix || "") + fmt(v); })]), ["日付", ...series.map((s) => s.name)]);

  // 十字線のツールチップ（最寄りの日付に吸着する）
  const svg = el.querySelector("svg"), cross = el.querySelector(".cross"), overlay = el.querySelector(".overlay");
  const move = (ev) => {
    const pt = svg.createSVGPoint();
    const e = ev.touches ? ev.touches[0] : ev;
    pt.x = e.clientX; pt.y = e.clientY;
    const p = pt.matrixTransform(svg.getScreenCTM().inverse());
    const idx = dates.length === 1 ? 0 : Math.round((p.x - padL) / (W - padL - padR) * (dates.length - 1));
    const d = dates[Math.max(0, Math.min(dates.length - 1, idx))];
    cross.setAttribute("x1", x(d)); cross.setAttribute("x2", x(d)); cross.setAttribute("visibility", "visible");
    const lines = series.map((s) => { const v = new Map(s.points).get(d); return `${s.name}: ${v == null ? "–" : (opts.prefix || "") + fmt(v)}`; });
    showTip(e, `${d}<br>${lines.map(esc).join("<br>")}`);
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
  const x = Math.min(e.clientX + 12, window.innerWidth - t.offsetWidth - 8);
  t.style.left = x + "px";
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
function lastValue(rows, f) {
  for (let i = rows.length - 1; i >= 0; i--) { const v = f(rows[i]); if (v != null) return v; }
  return undefined;
}
function textWidth(s) { return [...String(s)].reduce((a, c) => a + (c.charCodeAt(0) > 255 ? 11 : 6.5), 0); }
function clip(s, n) { s = String(s); return [...s].length > n ? [...s].slice(0, n).join("") + "…" : s; }
function fmt(v) { return v == null || Number.isNaN(v) ? "–" : Number(v).toLocaleString("ja-JP", { maximumFractionDigits: 2 }); }
function fmtDateTime(d) { return d.toLocaleString("ja-JP", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" }); }
function esc(s) { return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
function link(text, url) { return url && /^https:\/\//.test(url) ? `<a href="${esc(url)}" target="_blank" rel="noopener">${esc(text || "（本文なし）")}</a>` : esc(text); }
