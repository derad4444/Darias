// バッジ診断の質問（5軸 × 第1弾・第2弾 × 各10問）
// 一覧と方針は shared/docs/functions/バッジ質問一覧.md。IDは Flutter と共通。

const BADGE_QUESTIONS = {
  r1_energy_01: '休みの日、誰かと過ごすのと一人で過ごすの、どっちが元気出る？',
  r1_energy_02: '大勢の集まりのあと、楽しい疲れとぐったり疲れ、どっちが多い？',
  r1_energy_03: '嬉しいことがあったら、すぐ誰かに話したくなる？しばらく一人で噛みしめる？',
  r1_energy_04: 'お店や電車で知らない人に話しかけられたら、嬉しい？ちょっと困る？',
  r1_energy_05: '週末、人と会う予定が多い方が嬉しい？空いてる方が嬉しい？',
  r1_energy_06: 'ランチは誰かと食べたい？一人でゆっくり食べたい？',
  r1_energy_07: '友だちから急に「今から会おう」って来たら、どう感じる？',
  r1_energy_08: '疲れたとき、人と話して回復する？一人になって回復する？',
  r1_energy_09: 'イベントやお祭り、人が多いほどワクワクする？ちょっと身構える？',
  r1_energy_10: '連絡を取り合う友だちは、たくさんいる方がいい？少しでいい？',
  r2_energy_01: '初めての人ばかりの場に行くことになったら、どんな気持ちになる？',
  r2_energy_02: '考えごとは、人に話しながら整理する？一人で考えてからまとめる？',
  r2_energy_03: '一週間だれとも話さずに過ごすとしたら、どんな気持ちになりそう？',
  r2_energy_04: '自分が一番自分らしくいられるのは、人といるとき？一人のとき？',
  r2_energy_05: '会話が途切れて沈黙になったら、自分から話題を出す？そのままでも平気？',
  r2_energy_06: '新しい集まりに入ったとき、自分から輪に入っていく？声をかけられるのを待つ？',
  r2_energy_07: '人前で話す役を頼まれたら、どう感じる？',
  r2_energy_08: '理想の一日を思い浮かべたとき、そこに人はどれくらいいる？',
  r2_energy_09: '落ち込んだとき、誰かに会いたくなる？一人でいたくなる？',
  r2_energy_10: 'にぎやかな場所と静かな場所、長くいられるのはどっち？',
  r1_judgment_01: '大事なことを決めるとき、最後の決め手は気持ち？理屈？',
  r1_judgment_02: '友だちに相談されたら、まず気持ちに寄り添う？解決策を考える？',
  r1_judgment_03: '買い物で迷ったとき、「欲しい！」の気持ちで決める？値段や必要性で決める？',
  r1_judgment_04: '誰かに注意しないといけないとき、相手の気持ちを先に考える？正しさを先に考える？',
  r1_judgment_05: 'ニュースを見たとき、まず気持ちが動く？「なぜ起きたか」が気になる？',
  r1_judgment_06: '好きだけど効率が悪いやり方と、退屈だけど効率がいいやり方、どっちを選ぶ？',
  r1_judgment_07: '人を褒めるとき、頑張りや気持ちを褒める？結果や工夫を褒める？',
  r1_judgment_08: '謝られたとき、気持ちが伝わればいい？理由や改善策も聞きたい？',
  r1_judgment_09: 'プレゼントを選ぶとき、相手が喜ぶ顔で選ぶ？実用性で選ぶ？',
  r1_judgment_10: 'ルールと目の前の人の事情がぶつかったら、どっちを優先する？',
  r2_judgment_01: '理屈では正しいけど気持ちが乗らない選択、あなたならどうする？',
  r2_judgment_02: '誰かと意見がぶつかったとき、何を大事にして話す？',
  r2_judgment_03: 'これまでで一番大きな決断、どうやって決めた？',
  r2_judgment_04: '自分が間違ってたと気づくのは、気持ちがモヤっとしたとき？筋が通らないと気づいたとき？',
  r2_judgment_05: '言いにくいことを伝えるか、関係を優先して黙るか、どっちが多い？',
  r2_judgment_06: '「正しいけど冷たい人」と「優しいけど筋が通らない人」、どっちにイラッとする？',
  r2_judgment_07: '後悔するのは、気持ちを無視して決めたとき？よく考えずに決めたとき？',
  r2_judgment_08: '人を信じるかどうか、何で決める？',
  r2_judgment_09: '大切な人の頼みが筋の通らないものだったら、どうする？',
  r2_judgment_10: '自分の考えを伝えるとき、思いを込めて話す？順序立てて話す？',
  r1_processing_01: '新しいことを理解するとき、全体のイメージから掴む？細かいところから順に積み上げる？',
  r1_processing_02: '「なんとなくこっちな気がする」って感覚、どれくらい信じる？',
  r1_processing_03: '新しい家電やアプリ、説明を読んでから使う？とりあえず触ってみる？',
  r1_processing_04: '道に迷ったとき、地図で確かめる？勘で進む？',
  r1_processing_05: '初対面の人の印象、第一印象でピンとくる？話してみてから判断する？',
  r1_processing_06: 'お店選び、口コミや点数を見比べる？雰囲気で入る？',
  r1_processing_07: 'パズルや謎解き、ひらめきで解く？一つずつ可能性を潰す？',
  r1_processing_08: 'うまくいかないとき、理由を考える？気分を変えてみる？',
  r1_processing_09: 'アイデアって、ふと浮かぶ？考え抜いて出す？',
  r1_processing_10: '話を聞くとき、細かい事実が気になる？全体の雰囲気や意味が気になる？',
  r2_processing_01: '問題が起きたとき、原因を順番に分解する？パッとひらめくのを待つ？',
  r2_processing_02: '何かを選ぶとき、比べて調べてから決める？ピンときたもので決める？',
  r2_processing_03: '「根拠はないけど、こうなる気がする」って予感が当たった経験、ある？',
  r2_processing_04: '本を読むとき、書いてあることを正確に追う？行間や別の意味を想像する？',
  r2_processing_05: '未来のことを考えるとき、具体的な段取りが浮かぶ？ぼんやりしたイメージが浮かぶ？',
  r2_processing_06: '「もしも」や「意味」の話と、事実や手順の話、どっちが好き？',
  r2_processing_07: '新しい分野を学ぶなら、基礎から順番に？面白そうなところから飛び込む？',
  r2_processing_08: '説明するとき、たとえ話を使う？数字や事実を並べる？',
  r2_processing_09: '前例のない方法と実績のある方法、惹かれるのはどっち？',
  r2_processing_10: '物事のつながりや裏の意味に、つい目がいく？目の前の事実をそのまま受け取る？',
  r1_relationship_01: 'グループで何かするとき、周りに合わせる？自分のやり方を通す？',
  r1_relationship_02: '困ったとき、すぐ人に頼る？まず自分で何とかする？',
  r1_relationship_03: '頼まれごと、多少無理しても引き受ける？できないときは断る？',
  r1_relationship_04: '旅行は、誰かと予定を合わせて行く？一人で好きに行く？',
  r1_relationship_05: 'チームで成果が出たとき、みんなのおかげと思う？自分の担当がうまくいったと思う？',
  r1_relationship_06: '誰かが困ってそうなとき、自分から手伝う？頼まれたら手伝う？',
  r1_relationship_07: '自分のペースを崩されたとき、相手に合わせる？自分のペースを守る？',
  r1_relationship_08: '作業を分担するとき、相談しながら進めたい？自分の分を黙々とやりたい？',
  r1_relationship_09: '友だちとの約束、相手の都合を優先しがち？自分の都合も言える？',
  r1_relationship_10: '何かを決めるとき、周りの人に意見を聞く？自分だけで決める？',
  r2_relationship_01: 'チームでの作業と一人での作業、どっちが力を出しやすい？',
  r2_relationship_02: 'みんなの意見が自分と違ったら、どうする？',
  r2_relationship_03: '人に借りを作るのは平気？なるべく作りたくない？',
  r2_relationship_04: '頑張るとき、誰かのためだと力が出る？自分のためだと力が出る？',
  r2_relationship_05: 'ケンカしたあと、自分から歩み寄る？相手が来るのを待つ？',
  r2_relationship_06: '一人で何でもできる方が楽？人に頼れる関係の方が楽？',
  r2_relationship_07: '周りから浮いても自分のやり方を貫いた経験、ある？',
  r2_relationship_08: '誰かの期待と自分のやりたいことがぶつかったら、どうする？',
  r2_relationship_09: '人に助けを求めるのは得意？苦手？',
  r2_relationship_10: '誰かと暮らしたり働いたりするとき、ルールを合わせたい？お互い干渉しない方がいい？',
  r1_lifestyle_01: '旅行に行くなら、予定をしっかり決める？その場で決める？',
  r1_lifestyle_02: '締め切りのあること、早めに終わらせる？ギリギリで仕上げる？',
  r1_lifestyle_03: '休みの日、前もって予定を立てる？起きてから決める？',
  r1_lifestyle_04: '買い物はリストを作って行く？見ながら決める？',
  r1_lifestyle_05: '待ち合わせ、早めに着く？ちょうどか少し遅れる？',
  r1_lifestyle_06: 'カバンの中、決まった場所に決まった物がある？ざっくり入ってる？',
  r1_lifestyle_07: 'やることリストやカレンダー、使ってる？',
  r1_lifestyle_08: '朝の過ごし方、毎日だいたい同じ？日によってバラバラ？',
  r1_lifestyle_09: '外食するとき、行く店を前もって決める？歩きながら決める？',
  r1_lifestyle_10: '新しい趣味、計画を立てて続ける？気の向くままにやる？',
  r2_lifestyle_01: '予定が急に変わったとき、どんな気持ちになる？',
  r2_lifestyle_02: '部屋や持ち物、決まった場所に片付けてる？',
  r2_lifestyle_03: '5年後の自分、具体的に思い描いてる？その時になってみないとわからない？',
  r2_lifestyle_04: '目標を立てるのは好き？目標に縛られるのは苦手？',
  r2_lifestyle_05: '決めた習慣、守り続けられる方？途中で変えたくなる方？',
  r2_lifestyle_06: '計画通りに進まなかったとき、立て直す？流れに乗る？',
  r2_lifestyle_07: '長い休み、スケジュールを組む？成り行きに任せる？',
  r2_lifestyle_08: 'お金の使い方、予算を決めてる？そのとき欲しいものに使う？',
  r2_lifestyle_09: 'やりたいことが急に浮かんだら、今の予定を変えてでもやる？予定を優先する？',
  r2_lifestyle_10: '仕事や勉強、毎日コツコツ型？一気に集中型？',
};

const AXES = ['energy', 'judgment', 'processing', 'relationship', 'lifestyle'];
const ROUNDS = [1, 2];

// バッジ（軸 × 弾）。名前は第1弾がやわらかい言葉、第2弾が深い言葉
const BADGES = {
  r1_energy: {axis: 'energy', round: 1, name: 'つながり'},
  r1_judgment: {axis: 'judgment', round: 1, name: 'こころ'},
  r1_processing: {axis: 'processing', round: 1, name: 'ひらめき'},
  r1_relationship: {axis: 'relationship', round: 1, name: 'きずな'},
  r1_lifestyle: {axis: 'lifestyle', round: 1, name: 'あゆみ'},
  r2_energy: {axis: 'energy', round: 2, name: '共鳴'},
  r2_judgment: {axis: 'judgment', round: 2, name: '心核'},
  r2_processing: {axis: 'processing', round: 2, name: '洞察'},
  r2_relationship: {axis: 'relationship', round: 2, name: '信頼'},
  r2_lifestyle: {axis: 'lifestyle', round: 2, name: '道標'},
};

// 1つのバッジは2つの枠でできている（例: r1_energy_a / r1_energy_b）
const SLOT_SUFFIXES = ['a', 'b'];

/** バッジに属する質問IDの一覧 */
function questionsOfBadge(badgeKey) {
  return Object.keys(BADGE_QUESTIONS).filter((id) => id.startsWith(`${badgeKey}_`));
}

/** 質問IDからバッジのキーを返す（r1_energy_03 → r1_energy） */
function badgeOfQuestion(questionId) {
  return questionId.replace(/_\d+$/, '');
}

/** 枠のキーからバッジのキーを返す（r1_energy_a → r1_energy） */
function badgeOfSlot(slotKey) {
  return slotKey.replace(/_[ab]$/, '');
}

/** 弾ごとの全枠のキー */
function slotsOfRound(round) {
  const slots = [];
  for (const axis of AXES) {
    for (const s of SLOT_SUFFIXES) slots.push(`r${round}_${axis}_${s}`);
  }
  return slots;
}

module.exports = {
  BADGE_QUESTIONS,
  BADGES,
  AXES,
  ROUNDS,
  SLOT_SUFFIXES,
  questionsOfBadge,
  badgeOfQuestion,
  badgeOfSlot,
  slotsOfRound,
};
