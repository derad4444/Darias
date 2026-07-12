// DARIAS 管理ダッシュボード（ローカル・再集計ボタン付き）
// タブ1: 手帳タブ利用状況（Firestore集計）
// タブ2: 性格統計（Cloud Function recalculatePersonalityStats をプレビュー/書き込みで実行）
// 起動: node server.js  → ブラウザで http://localhost:8799 が開く
const http = require('http');
const path = require('path');
const { exec } = require('child_process');
const admin = require(path.join(__dirname, '../../functions/node_modules/firebase-admin'));
const serviceAccount = require(path.join(__dirname, '../../functions/keys/serviceAccountKey.json'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const PORT = 8799;
const FUNCTION_URL = 'https://asia-northeast1-my-character-app.cloudfunctions.net/recalculatePersonalityStats';

// ── 手帳データ集計 ────────────────────────────────────
const TS_FIELDS = {
  schedules: ['startDate', 'date'],
  memos: ['updatedAt', 'createdAt'],
  todos: ['updatedAt', 'createdAt'],
};
const tsOf = (data, fields) => {
  for (const f of fields) { const v = data[f]; if (v && v.toDate) return v.toDate(); }
  return null;
};
const iso = (dt) => (dt ? dt.toISOString().slice(0, 10) : null);

async function aggregateUsage() {
  const now = Date.now();
  const usersSnap = await db.collection('users').get();
  const info = {};
  usersSnap.docs.forEach((d) => {
    const x = d.data();
    const created = (x.createdAt && x.createdAt.toDate && x.createdAt.toDate())
      || (x.created_at && x.created_at.toDate && x.created_at.toDate()) || null;
    const lastLogin = (x.lastLoginAt && x.lastLoginAt.toDate && x.lastLoginAt.toDate()) || null;
    info[d.id] = { name: x.name || x.displayName || '(名前なし)', email: x.email || '', created, lastLogin };
  });
  try {
    let pageToken;
    do {
      const res = await admin.auth().listUsers(1000, pageToken);
      res.users.forEach((u) => {
        if (info[u.uid] && !info[u.uid].created && u.metadata.creationTime) {
          info[u.uid].created = new Date(u.metadata.creationTime);
        }
      });
      pageToken = res.pageToken;
    } while (pageToken);
  } catch (e) { /* Auth取得失敗時はdocの値のみ */ }

  const agg = {};
  const ensure = (uid) => (agg[uid] || (agg[uid] = {
    schedules: { n: 0, last: null }, memos: { n: 0, last: null }, todos: { n: 0, last: null }, diary: 0,
  }));
  for (const col of ['schedules', 'memos', 'todos']) {
    const snap = await db.collectionGroup(col).get();
    snap.docs.forEach((doc) => {
      const parts = doc.ref.path.split('/');
      if (parts[0] !== 'users') return;
      const rec = ensure(parts[1])[col];
      rec.n++;
      const t = tsOf(doc.data(), TS_FIELDS[col]);
      if (t && (!rec.last || t > rec.last)) rec.last = t;
    });
  }
  const diarySnap = await db.collectionGroup('diary').get();
  diarySnap.docs.forEach((doc) => {
    const parts = doc.ref.path.split('/');
    if (parts[0] === 'users') ensure(parts[1]).diary++;
  });

  const uids = new Set([...Object.keys(agg), ...Object.keys(info)]);
  const rows = [];
  uids.forEach((uid) => {
    const a = agg[uid] || { schedules: { n: 0, last: null }, memos: { n: 0, last: null }, todos: { n: 0, last: null }, diary: 0 };
    const i = info[uid] || { name: '(user doc削除済み)', email: '', created: null, lastLogin: null };
    const total = a.schedules.n + a.memos.n + a.todos.n + a.diary;
    if (total === 0) return;
    rows.push({
      uid, name: i.name, email: i.email,
      created: iso(i.created), daysSinceSignup: i.created ? Math.floor((now - i.created.getTime()) / 86400000) : null,
      lastLogin: iso(i.lastLogin),
      schedules: a.schedules.n, memos: a.memos.n, todos: a.todos.n, diary: a.diary, total,
      lastMemo: iso(a.memos.last), lastTodo: iso(a.todos.last), lastSchedule: iso(a.schedules.last),
    });
  });
  rows.sort((x, y) => y.total - x.total);
  const sum = (k) => rows.reduce((s, r) => s + r[k], 0);
  return {
    aggregatedAt: new Date(now).toISOString(), totalUsers: usersSnap.size, activeUsers: rows.length,
    totals: { schedules: sum('schedules'), memos: sum('memos'), todos: sum('todos'), diary: sum('diary') }, rows,
  };
}

// ── 性格統計（Cloud Function 呼び出し）────────────────
async function fetchPersonality(dryRun) {
  const url = FUNCTION_URL + (dryRun ? '?dryRun=true' : '');
  const resp = await fetch(url, { method: 'GET' });
  const text = await resp.text();
  if (resp.status !== 200) throw new Error('HTTP ' + resp.status + ': ' + text.slice(0, 300));
  let json;
  try { json = JSON.parse(text); } catch (e) { throw new Error('JSON解析失敗: ' + text.slice(0, 300)); }
  if (!json.success) throw new Error('集計失敗: ' + text.slice(0, 300));
  return { fetchedAt: new Date().toISOString(), dryRun: !!dryRun, stats: json.stats };
}

// ── HTTPサーバー ──────────────────────────────────────
const server = http.createServer(async (req, res) => {
  const send = (code, obj) => {
    res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(obj));
  };
  if (req.url === '/api/usage') {
    try { send(200, await aggregateUsage()); } catch (e) { send(500, { error: String(e && e.message || e) }); }
    return;
  }
  if (req.url && req.url.startsWith('/api/personality')) {
    const dryRun = /[?&]dryRun=true/.test(req.url);
    try { send(200, await fetchPersonality(dryRun)); } catch (e) { send(500, { error: String(e && e.message || e) }); }
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(HTML);
});
const URL = `http://localhost:${PORT}`;
server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.log(`ポート${PORT}は既に使用中です。既存のダッシュボードをブラウザで開きます: ${URL}`);
    exec(`open "${URL}"`);
    process.exit(0);
  }
  console.error('サーバー起動エラー:', e.message);
  process.exit(1);
});
server.listen(PORT, () => {
  console.log(`DARIAS 管理ダッシュボード起動: ${URL}`);
  console.log('停止するには Ctrl+C');
  exec(`open "${URL}"`);
});

// ── フロント（ブラウザ側HTML。この文字列内では ${} / バッククォートを使わない）──
const HTML = `<!doctype html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DARIAS 管理ダッシュボード</title>
<style>
  :root{--bg:#f4f5f8;--panel:#fff;--panel2:#fafbfc;--ink:#1b1e26;--soft:#5a6172;--line:#e5e7ee;--lineS:#d3d7e2;
    --accent:#4a53c9;--sch:#2f77d6;--memo:#c98a12;--todo:#2b9e6b;--diary:#8a63d2;--warn:#c2410c;--zero:#a8adba;}
  @media(prefers-color-scheme:dark){:root{--bg:#14161c;--panel:#1c1f28;--panel2:#20242f;--ink:#e9ebf1;--soft:#9aa1b4;
    --line:#2b2f3b;--lineS:#39404f;--accent:#8b93f5;--sch:#63a2f0;--memo:#e0b357;--todo:#57c895;--diary:#b295ee;--warn:#f08a5d;--zero:#5a6072;}}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Hiragino Sans","Segoe UI",sans-serif;line-height:1.5}
  .wrap{max-width:1180px;margin:0 auto;padding:24px 20px 70px}
  h1{font-size:21px;margin:0 0 12px;font-weight:750}
  h2{font-size:15px;margin:22px 0 8px;font-weight:700}
  .tabs{display:flex;gap:6px;border-bottom:1px solid var(--lineS);margin-bottom:16px}
  .tab{padding:9px 16px;font-size:14px;font-weight:600;color:var(--soft);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px}
  .tab.active{color:var(--accent);border-bottom-color:var(--accent)}
  .bar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:14px}
  button{background:var(--accent);color:#fff;border:0;border-radius:9px;padding:9px 16px;font-size:14px;font-weight:600;cursor:pointer}
  button.ghost{background:transparent;color:var(--accent);border:1px solid var(--accent)}
  button.warn{background:var(--warn)}
  button:disabled{opacity:.5;cursor:default}
  .stamp{color:var(--soft);font-size:12.5px}
  .tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px;margin-bottom:8px}
  .tile{background:var(--panel);border:1px solid var(--line);border-radius:11px;padding:12px 14px}
  .tile .l{font-size:11.5px;color:var(--soft);font-weight:600}
  .tile .n{font-size:22px;font-weight:750;font-variant-numeric:tabular-nums;margin-top:3px}
  input[type=search]{flex:1;min-width:160px;background:var(--panel);border:1px solid var(--lineS);color:var(--ink);border-radius:9px;padding:9px 12px;font-size:14px}
  .tablewrap{overflow-x:auto;background:var(--panel);border:1px solid var(--line);border-radius:12px}
  table{border-collapse:collapse;width:100%;font-size:13px}
  #t{min-width:1000px}
  thead th{position:sticky;top:0;background:var(--panel2);text-align:right;padding:10px 11px;font-size:12px;font-weight:650;color:var(--soft);border-bottom:1px solid var(--lineS);white-space:nowrap;cursor:pointer}
  thead th.l{text-align:left}
  th.sorted{color:var(--accent)}
  td{padding:8px 11px;border-bottom:1px solid var(--line);text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
  td.l{text-align:left}
  tr:hover td{background:var(--panel2)}
  .name{font-weight:600}.email{color:var(--soft);font-size:11px}
  .z{color:var(--zero)}.date{color:var(--soft);font-size:12.5px}.fut{color:var(--warn)}
  .val-sch{color:var(--sch);font-weight:650}.val-memo{color:var(--memo);font-weight:650}.val-todo{color:var(--todo);font-weight:650}.val-diary{color:var(--diary);font-weight:650}.tot{font-weight:750}
  .err{color:var(--warn);font-weight:600}
  .elemHead td{font-weight:700;background:var(--panel2)}
  .subRow td.l{padding-left:26px;color:var(--soft)}
  .hidden{display:none}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}
  @media(max-width:760px){.cols{grid-template-columns:1fr}}
</style></head><body>
<div class="wrap">
  <h1>DARIAS 管理ダッシュボード</h1>
  <div class="tabs">
    <div class="tab active" data-view="techou">手帳タブ利用状況</div>
    <div class="tab" data-view="personality">性格統計</div>
  </div>

  <!-- ===== 手帳タブ利用状況 ===== -->
  <div id="view-techou">
    <div class="bar">
      <button id="refresh">再集計</button>
      <span class="stamp" id="stamp">読み込み中…</span>
      <input type="search" id="q" placeholder="名前・メールで絞り込み…">
    </div>
    <div class="tiles" id="tiles"></div>
    <div class="tablewrap"><table id="t"><thead><tr>
      <th class="l" data-k="name">ユーザー</th>
      <th data-k="created">作成日</th>
      <th data-k="daysSinceSignup">経過日数</th>
      <th data-k="lastLogin">最終ログイン</th>
      <th data-k="schedules">予定</th>
      <th data-k="memos">メモ</th>
      <th data-k="todos">ToDo</th>
      <th data-k="diary">日記</th>
      <th data-k="total" class="sorted">合計 ▼</th>
      <th data-k="lastMemo">メモ最終</th>
      <th data-k="lastTodo">ToDo最終</th>
      <th data-k="lastSchedule">最新予定日</th>
    </tr></thead><tbody id="tb"></tbody></table></div>
  </div>

  <!-- ===== 性格統計 ===== -->
  <div id="view-personality" class="hidden">
    <div class="bar">
      <button id="pPreview" class="ghost">プレビュー（書き込みなし）</button>
      <button id="pWrite" class="warn">再集計して書き込み</button>
      <span class="stamp" id="pStamp">「プレビュー」を押すと最新の性格統計を表示します（書き込みなし）。</span>
    </div>
    <div class="tiles" id="pTiles"></div>
    <div class="cols">
      <div>
        <h2>性別分布</h2>
        <div class="tablewrap"><table><thead><tr><th class="l">性別</th><th>人数</th></tr></thead><tbody id="pGender"></tbody></table></div>
      </div>
      <div>
        <h2>元素分布（サブタイプ内訳）</h2>
        <div class="tablewrap"><table><thead><tr><th class="l">元素 / タイプ名</th><th>人数</th></tr></thead><tbody id="pElement"></tbody></table></div>
      </div>
    </div>
    <h2>性格タイプ一覧</h2>
    <div class="tablewrap"><table><thead><tr><th class="l">personalityKey</th><th class="l">元素</th><th class="l">タイプ名</th><th>人数</th></tr></thead><tbody id="pDetail"></tbody></table></div>
  </div>
</div>
<script>
var esc=function(s){return String(s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});};
var $=function(id){return document.getElementById(id);};

/* ---- タブ切替 ---- */
document.querySelectorAll('.tab').forEach(function(t){t.addEventListener('click',function(){
  document.querySelectorAll('.tab').forEach(function(x){x.classList.remove('active');});
  t.classList.add('active');
  var v=t.dataset.view;
  $('view-techou').classList.toggle('hidden',v!=='techou');
  $('view-personality').classList.toggle('hidden',v!=='personality');
});});

/* ================= 手帳タブ利用状況 ================= */
var DATA=[], sortK='total', sortDir=-1, today=new Date().toISOString().slice(0,10);
function fdate(s,fut){ if(!s) return '<span class="z">—</span>'; var f=fut&&s>today; return '<span class="date'+(f?' fut':'')+'">'+s+'</span>'; }
function cell(v,c){ return v>0?'<td class="'+c+'">'+v+'</td>':'<td class="z">0</td>'; }
function loadUsage(){
  $('refresh').disabled=true; $('stamp').textContent='集計中…';
  fetch('/api/usage').then(function(r){return r.json();}).then(function(d){
    if(d.error){ $('stamp').innerHTML='<span class="err">エラー: '+esc(d.error)+'</span>'; return; }
    DATA=d.rows; today=new Date().toISOString().slice(0,10);
    $('stamp').textContent='最終集計: '+new Date(d.aggregatedAt).toLocaleString('ja-JP')+' ／ 手帳データ保有 '+d.activeUsers+'名（全'+d.totalUsers+'名中）';
    $('tiles').innerHTML=[['予定',d.totals.schedules,'sch'],['メモ',d.totals.memos,'memo'],['ToDo',d.totals.todos,'todo'],['日記',d.totals.diary,'diary']]
      .map(function(a){return '<div class="tile"><div class="l">'+a[0]+'</div><div class="n" style="color:var(--'+a[2]+')">'+a[1]+'</div></div>';}).join('');
    renderUsage();
  }).catch(function(e){ $('stamp').innerHTML='<span class="err">通信エラー: '+esc(e.message)+'</span>'; })
    .finally(function(){ $('refresh').disabled=false; });
}
function renderUsage(){
  var term=$('q').value.trim().toLowerCase();
  var list=DATA.filter(function(r){return !term||(r.name||'').toLowerCase().indexOf(term)>=0||(r.email||'').toLowerCase().indexOf(term)>=0;});
  list.sort(function(a,b){ var x=a[sortK],y=b[sortK];
    if(sortK==='name'){return String(x||'').localeCompare(String(y||''),'ja')*sortDir;}
    if(typeof x==='string'||typeof y==='string'||sortK.indexOf('last')===0||sortK==='created'){x=x||'';y=y||'';return (x<y?-1:x>y?1:0)*sortDir;}
    return ((x||0)-(y||0))*sortDir; });
  $('tb').innerHTML=list.map(function(r){
    var nm=r.name==='(user doc削除済み)'?'<span class="name z">'+esc(r.name)+'</span>':'<span class="name">'+esc(r.name)+'</span>'+(r.email?'<br><span class="email">'+esc(r.email)+'</span>':'');
    return '<tr><td class="l">'+nm+'</td>'+
      '<td>'+fdate(r.created)+'</td>'+
      '<td>'+(r.daysSinceSignup==null?'<span class="z">—</span>':r.daysSinceSignup+'日')+'</td>'+
      '<td>'+fdate(r.lastLogin)+'</td>'+
      cell(r.schedules,'val-sch')+cell(r.memos,'val-memo')+cell(r.todos,'val-todo')+cell(r.diary,'val-diary')+
      '<td class="tot">'+r.total+'</td>'+
      '<td>'+fdate(r.lastMemo)+'</td><td>'+fdate(r.lastTodo)+'</td><td>'+fdate(r.lastSchedule,true)+'</td></tr>';
  }).join('');
}
document.querySelectorAll('#t thead th').forEach(function(th){th.addEventListener('click',function(){
  var k=th.dataset.k; if(sortK===k)sortDir=-sortDir; else {sortK=k;sortDir=(k==='name'||k==='created')?1:-1;}
  document.querySelectorAll('#t thead th').forEach(function(h){h.classList.remove('sorted');h.textContent=h.textContent.replace(/ [\\u25bc\\u25b2]$/,'');});
  th.classList.add('sorted'); th.textContent=th.textContent.replace(/ [\\u25bc\\u25b2]$/,'')+(sortDir<0?' \\u25bc':' \\u25b2'); renderUsage();
});});
$('refresh').addEventListener('click',loadUsage);
$('q').addEventListener('input',renderUsage);

/* ================= 性格統計 ================= */
var GENDER={female:'女性',male:'男性',neutral:'未設定'};
var ELEMENT_ORDER=['\\u708e','\\u98a8','\\u96f7','\\u5149','\\u6c34','\\u571f','\\u6c37','\\u95c7','\\u7121','\\u4e0d\\u660e'];
function loadPersonality(dryRun){
  $('pPreview').disabled=true; $('pWrite').disabled=true;
  $('pStamp').textContent=(dryRun?'プレビュー集計中…':'再集計＆書き込み中…');
  fetch('/api/personality'+(dryRun?'?dryRun=true':'')).then(function(r){return r.json();}).then(function(d){
    if(d.error){ $('pStamp').innerHTML='<span class="err">エラー: '+esc(d.error)+'</span>'; return; }
    renderPersonality(d);
  }).catch(function(e){ $('pStamp').innerHTML='<span class="err">通信エラー: '+esc(e.message)+'</span>'; })
    .finally(function(){ $('pPreview').disabled=false; $('pWrite').disabled=false; });
}
function renderPersonality(d){
  var s=d.stats||{};
  $('pStamp').innerHTML=(d.dryRun?'【プレビュー・書き込みなし】':'【書き込み完了】')+' 取得: '+new Date(d.fetchedAt).toLocaleString('ja-JP');
  $('pTiles').innerHTML=
    '<div class="tile"><div class="l">総性格数（診断完了）</div><div class="n">'+(s.total_completed_users!=null?s.total_completed_users:'—')+'</div></div>'+
    '<div class="tile"><div class="l">ユニーク性格タイプ数</div><div class="n">'+(s.unique_personality_types!=null?s.unique_personality_types:'—')+'</div></div>';
  // 性別分布
  var g=s.gender_distribution||{};
  $('pGender').innerHTML=Object.keys(g).map(function(k){return '<tr><td class="l">'+(GENDER[k]||esc(k))+'</td><td>'+g[k]+'</td></tr>';}).join('')||'<tr><td class="l z">データなし</td><td class="z">—</td></tr>';
  // 元素分布：typeName→element 逆引き→元素ごとにグループ化
  var t2e={}; var pd=s.personality_details||{};
  Object.keys(pd).forEach(function(k){var i=pd[k];if(i.typeName&&i.element)t2e[i.typeName]=i.element;});
  var groups={}; var tnc=s.type_name_counts||{};
  Object.keys(tnc).forEach(function(tn){var e=t2e[tn]||'\\u4e0d\\u660e';(groups[e]||(groups[e]=[])).push({typeName:tn,count:tnc[tn]});});
  var elems=ELEMENT_ORDER.concat(Object.keys(groups).filter(function(e){return ELEMENT_ORDER.indexOf(e)<0;}));
  var html='';
  elems.forEach(function(e){
    var grp=groups[e]; if(!grp)return;
    var total=grp.reduce(function(a,b){return a+b.count;},0);
    html+='<tr class="elemHead"><td class="l">'+esc(e)+'（合計）</td><td>'+total+'</td></tr>';
    grp.sort(function(a,b){return b.count-a.count;}).forEach(function(x){
      html+='<tr class="subRow"><td class="l">'+esc(x.typeName)+'</td><td>'+x.count+'</td></tr>';
    });
  });
  $('pElement').innerHTML=html||'<tr><td class="l z">データなし</td><td class="z">—</td></tr>';
  // 性格タイプ一覧
  var entries=Object.keys(pd).map(function(k){return [k,pd[k]];}).sort(function(a,b){return b[1].count-a[1].count;});
  $('pDetail').innerHTML=entries.map(function(en){var k=en[0],i=en[1];
    return '<tr><td class="l">'+esc(k)+'</td><td class="l">'+esc(i.element||'')+'</td><td class="l">'+esc(i.typeName||'')+'</td><td>'+i.count+'</td></tr>';
  }).join('')||'<tr><td class="l z" colspan="4">データなし</td></tr>';
}
$('pPreview').addEventListener('click',function(){loadPersonality(true);});
$('pWrite').addEventListener('click',function(){
  if(confirm('Firestoreに性格統計を書き込みます。よろしいですか？'))loadPersonality(false);
});

/* 初回は手帳を自動ロード（性格統計は書き込み回避のため手動ボタンで実行）*/
loadUsage();
</script></body></html>`;
