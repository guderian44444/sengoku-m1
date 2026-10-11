import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inventory = JSON.parse(await readFile(path.join(root, 'docs/character-assets-v15.json'), 'utf8'));
const voice = JSON.parse(await readFile(path.join(root, 'game/audio/v15/manifest.json'), 'utf8'));
assert.equal(Object.keys(inventory.heroes).length, 6);
assert.equal(Object.keys(inventory.enemies).length, 12);
assert(inventory.heroes.oichi.find(row => row.action === 'victory').routes.some(route => route.source === 'v15'));
const labels = {
  nobunaga:'織田信長', oichi:'阿市', hideyoshi:'羽柴秀吉', ieyasu:'德川家康', mitsuhide:'明智光秀', tadakatsu:'本多忠勝',
  soldier:'長槍足輕', flag:'旗手', commander:'指揮官', archer:'弓兵', gunner:'鐵砲手', boss:'小王',
  imagawa:'今川', oda:'織田', saito:'齋藤', miyoshi:'三好', azai:'淺井', asakura:'朝倉', takeda:'武田', ikko:'一向一揆', mori:'毛利', akechi:'明智', hashiba:'羽柴', iga:'伊賀',
  idle:'站立／攜武', walk:'走路', run:'跑步', jump:'跳躍', light1:'輕手第一段', light2:'輕手第二段', light3:'輕手第三段', heavy1:'重手第一段', heavy2:'重手第二段', charge:'蓄力保持', charged:'滿蓄重手', rising:'上＋輕手', low_sweep:'下＋輕手', dash_strike:'前＋輕手', dash_heavy:'衝刺重手', upper_heavy:'上＋重手', charged_upper:'上＋滿蓄重手', ground_slam:'下＋重手', charged_slam:'下＋滿蓄重手', air_light:'空中輕手', air_heavy:'空中重手', mixed_finisher:'輕轉重 COMBO', mixed_rising:'重轉輕 COMBO', counter_cut:'格擋反擊', guard:'防禦／擋中', hurt:'受擊彎腰', launched:'擊飛', down:'倒地', recovering:'起身', stunned:'暈眩', grabbed:'被抓掙扎', holding:'抓住敵人', throw:'摔投', special:'必殺', victory:'過關慶祝', defeated:'死亡躺平', retreat:'面敵後退', bow_shot:'拉弓射箭', gun_shot:'裝填／鐵砲射擊', spear_thrust:'槍直刺', spear_sweep:'槍橫掃', spear_butt:'槍尾敲擊', flag_poke:'旗桿戳刺', flag_sweep:'旗桿橫掃', flag_slam:'旗桿下砸', commander_cut:'軍官斜斬', commander_rise:'軍官上挑', commander_dash:'軍官突進', boss_sweep:'大範圍橫掃', boss_smash:'近身砸擊', boss_chain:'長鏈拉近追打', boss_grab_throw:'近抓摔投', boss_thrust:'長突刺', boss_dash:'突進斬', boss_volley:'鐵砲連射', boss_counter:'格擋反擊', boss_double:'雙連斬', boss_hook:'鉤槍掛拉', boss_earth:'全周震地'
};
const identities = {
  nobunaga:'紅甲、披風、黑馬尾；刀路右上→左下、左下→右上、左→右，三段各有不同弧線。重手與火焰以幅度和震波表現力量。慶祝收刀勢後高舉武士刀。',
  oichi:'成年女性、修長腿型、長馬尾與簡單頭飾；紅白服裝，白色安全內著，弓閒置時在背上。輕手第三段先轉身再高抬腿迴旋踢；慶祝露肩、交叉腿回眸，配柔和俏皮台詞。',
  hideyoshi:'短槍快攻、靈活步法；造型與個人慶祝動作待逐人定案。',
  ieyasu:'太刀寬斬與防禦、厚重步法；造型與個人慶祝動作待逐人定案。',
  mitsuhide:'拔刀、窄線快切與格擋反擊；造型與個人慶祝動作待逐人定案。',
  tadakatsu:'長槍、長距重突與強摔；造型與個人慶祝動作待逐人定案。'
};
const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const table = rows => `<div class="scroll"><table><thead><tr><th>動作／遊戲代碼</th><th>目前實際來源</th><th>來源取樣格數</th></tr></thead><tbody>${rows.map(row => `<tr><td>${esc(labels[row.action] || row.action)}<code>${esc(row.action)}</code></td><td>${row.routes.map(r => `<code>${esc(r.source)} / ${esc(r.sheet)}</code>`).join('')}</td><td>${row.routes.map(r => `${r.sampled_cells} 格`).join(' ＋ ')}</td></tr>`).join('')}</tbody></table></div>`;
const paragraphs = [
  ['先鎖造型再補招','先交正面、側面、背面與戰鬥站姿；確認人體比例、武器、盔甲層級、配色和家徽。所有動作沿用同一個定案，避免每招重新長出不同臉、裝備或粗細。'],
  ['連續 PNG 的交付規格','主角主要招式、行走、跑步、受擊、擊飛、死亡、起身、抓摔、慶祝，各以 12 張真正重畫的連續圖片為新增製作目標；站立至少 6 張。敵兵主要戰鬥與反應同樣目標 12 張。現有毛利多數招式為 6 張、受擊／掙扎 3 張，這是本版現況，不宣稱已全部達到新規格。'],
  ['不能靠搖圖充幀','相鄰圖片要有連續的軀幹、肩胯、四肢和兵器變化；不接受複製圖片、平移、旋轉或補間模糊當成重畫。武器軌跡每張都能辨認，輕、重、強力技用幅度、刀弧與震波區分。'],
  ['解析度、比例與去背','PNG 保留原始生成 byte 與透明 alpha；單格站立人體高度至少 300 px，先排成 3×2 六格兩張，再組成 12 幀。記錄每格 region、feet、body_height，比例以解剖身高計算，不以刀尖、旗子、馬尾或整張外框縮放；半透明邊緣不可有灰霧、黑白底或鄰格碎片。'],
  ['播放、打點與事件','走路 12 fps、跑步 16 fps 連續循環，放開即站立，不為走完循環強制壓縮時間。攻擊依遊戲命中 tick 配置起手／出手／收勢：刀風、弓弦、槍響只在真正出手那格；撞擊只在有效命中。連按期間忽略普通前進，輕手第三段只踏出一次。'],
  ['受擊、倒地、死亡','受擊畫出彎腰、臉部痛苦和重心失衡。存活者可擊飛、落地彈跳、倒地、起身；死者落地後保持躺平，不從倒地圖拉回站姿。被抓用獨立掙扎圖，倒地不可抓；被抓 0.5 秒只做一次 50% 逃脫判定。'],
  ['慶祝與雙人合作','阿市／信長各 12 張，6 fps 播兩秒後保持最後一張；先落地、起身，再慶祝。約第一秒開始勝利台詞。雙人各自做動作，台詞排隊，不重複、不替倒下隊友播放。其餘四位本次不補製。'],
  ['短喊與完整台詞','阿市及敵兵發力／受擊短喊 0.30–0.50 秒，至少 3 個不同 take，硬起音、高亢、有力、迅速收尾；不能靠切斷有聲尾巴修成半秒。普通輕手一、二段和普通重手第一段不喊，COMBO 終結、重手第二段、蓄力才喊。登場、必殺招式名和過關是完整台詞，另列時長。'],
  ['武器與命中聲','每類至少 3 段不同 PCM，輕／重刀命中各 5 段；隨機洗牌且相鄰不重複。必交：刀空揮、槍破風、踢風、飛針、弓箭射出、鐵砲射出、刀／箭／彈／針／鈍擊命中、格擋破防、抓摔、落地、冰裂、火／必殺及環境互動。台詞和兵器聲分軌，避免蓋住重點。'],
  ['新增敵人的最低組合','長槍、旗手、指揮官各三招；弓兵與鐵砲兵具瞄準／發射／收勢及面敵後退。小王至少近身、長距、大範圍、抓丟四招，加格擋與反應；體格可略魁梧，裝備有辨識度。每陣營旗手與營旗使用同一家徽。毛利以定案素材為基準；其餘陣營待逐一正式化。'],
  ['每次交付與驗收','提交原 PNG／WAV、registration、語音 manifest、生成提示與種子、原檔 SHA256、處理步驟和音長量測。附逐張聯絡表、原生實錄、音效分類試聽、遊戲操作及解壓包檢查。程式通過不等於畫面、情緒、實體搖桿或雙機已人工驗收。']
];
const heroCards = ['nobunaga','oichi','hideyoshi','ieyasu','mitsuhide','tadakatsu'].map(hero => {
  const rows = inventory.heroes[hero];
  const focused = ['oichi','nobunaga'].includes(hero);
  return `<details ${focused ? 'open' : ''}><summary>${esc(labels[hero])}<span class="tag ${focused ? '' : 'wait'}">${focused ? '本次製作' : '暫緩・只盤點既有'}</span></summary><p>${esc(identities[hero])}</p>${table(rows)}</details>`;
}).join('');
const enemies = Object.entries(inventory.enemies).sort(([a],[b]) => a === 'mori' ? -1 : b === 'mori' ? 1 : a.localeCompare(b)).map(([faction, profiles]) => `<details><summary>${esc(labels[faction])}軍 <span class="tag ${faction === 'mori' ? '' : 'wait'}">${faction === 'mori' ? '沿用正式逐張圖' : '既有素材・後續正式化'}</span></summary>${Object.entries(profiles).map(([role, rows]) => `<details><summary>${esc(labels[role])}</summary>${table(rows)}</details>`).join('')}</details>`).join('');
const voiceTable = ['oichi','nobunaga','soldier','flag','commander','archer','gunner', ...Object.keys(inventory.enemies).map(f => 'boss_' + f)].map(actor => {
  const name = actor.startsWith('boss_') ? labels[actor.slice(5)] + '小王' : labels[actor];
  return `<tr><td>${esc(name)}</td>${['attack','heavy','hurt','special','victory'].map(event => {
    const clips = (voice.actors[actor]?.[event] || []).map(key => voice.clips[key]);
    const durations = clips.map(clip => Number(clip.seconds));
    return `<td>${clips.length ? `${clips.length} 段<br><small>${Math.min(...durations).toFixed(2)}–${Math.max(...durations).toFixed(2)} 秒</small>` : '—'}</td>`;
  }).join('')}</tr>`;
}).join('');
const html = `<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>吞食戰國｜角色動作與素材標準 v0.15</title><style>
:root{color-scheme:dark;font-family:"Microsoft JhengHei",system-ui,sans-serif;background:#101b20;color:#e8eadf}*{box-sizing:border-box}body{max-width:1180px;margin:auto;padding:32px 24px 70px;line-height:1.7}header{border-top:4px solid #bb514b;padding:20px 0}h1{font-size:32px;line-height:1.3}h2{margin:36px 0 16px;color:#e1c495}a{color:#aadbd3}nav{display:flex;gap:20px;flex-wrap:wrap;padding:16px;background:#1c2b31;position:sticky;top:0;z-index:1}section{scroll-margin-top:80px}details{background:#1b2a30;border:1px solid #354850;margin:12px 0;padding:14px 18px;border-radius:8px}summary{cursor:pointer;font-size:19px;font-weight:600}details details{background:#14232a}p{max-width:1000px}code{display:block;font-size:12px;color:#acc0c6;overflow-wrap:anywhere}table{border-collapse:collapse;width:100%;min-width:670px}th,td{text-align:left;vertical-align:top;padding:11px;border-bottom:1px solid #354850}th{color:#e1c495}small{color:#afbdc2}.scroll{overflow:auto}.tag{font-size:12px;font-weight:400;color:#a4e2c7;background:#244438;padding:4px 9px;margin-left:12px;border-radius:12px}.wait{color:#e7c98a;background:#423925}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}.card{padding:18px;background:#1b2a30;border-left:3px solid #aa5046}.card h3{margin:0 0 8px}.card p{margin:0}.note{padding:14px 18px;border-left:3px solid #d0ac6d;background:#332e23}footer{margin-top:32px;color:#acb9be;font-size:13px}
</style><header><small>製作基準 / v0.15 / 2026-10-11</small><h1>角色動作與素材標準</h1><p>先完成阿市、信長，再把同一套流程套到其他人。秀吉、家康、光秀、忠勝本次不補新細節與慶祝素材。</p><p><a href="../game/audio/v15/sfx/preview.html">武器／命中音效試聽</a>　<a href="../game/audio/v15/preview.html">短喊／勝利台詞試聽</a>　<a href="character-assets-v15.json">完整機器可讀清單</a></p></header>
<nav><a href="#standard">製作標準</a><a href="#heroes">六位主角</a><a href="#enemies">敵兵與陣營</a><a href="#audio">語音數量</a></nav>
<section id="standard"><h2>新增人物按這份交付</h2><div class="grid">${paragraphs.map(([title,text]) => `<article class="card"><h3>${esc(title)}</h3><p>${esc(text)}</p></article>`).join('')}</div></section>
<section id="heroes"><h2>主角需要的動作與目前來源</h2><p class="note">下表是遊戲取樣結果，格數是實際引用的來源格，不保證每格都已通過人工動作品質驗收。同一來源出現在不同招式，表示目前共用；新增正式角色應分別製作。混合技可能由兩組來源接續。死亡另沿用倒地的最後躺平格。</p>${heroCards}</section>
<section id="enemies"><h2>敵兵需要的動作與目前來源</h2><p>毛利普通敵兵現有走路、三招／遠程射擊、受擊、掙扎、死亡；小王四招。後退目前倒放面敵走路圖，起身目前反播倒地圖；新增正式素材應交專用後退、起身與格擋，不能只移動同一張圖。</p>${enemies}</section>
<section id="audio"><h2>目前實際載入的語音</h2><p>列出池中不同錄音數量及長度。新戰鬥短音與完整招式／勝利句子分開驗收；另四人延後更新，因此不列為本次新增語音。</p><div class="scroll"><table><thead><tr><th>角色／敵人</th><th>一般發力</th><th>重手／蓄力</th><th>受擊</th><th>必殺／小王技</th><th>勝利</th></tr></thead><tbody>${voiceTable}</tbody></table></div></section>
<footer>來源：game/core/battle.gd、render/frame_animation.gd、render/battle_view.gd、各版 registration.json 與 audio/v15/manifest.json。清單由 export_asset_inventory_v15.gd 匯出，本頁由 build-asset-standard-v15.mjs 重建。圖片與波形檢查、原生程式測試，不代表實際聽感與實體控制器驗收。</footer></html>`;
assert(!html.includes('undefined'));
await writeFile(path.join(root, 'docs/角色動作與素材標準-v0.15.html'), html);
console.log('PASS: v15 production standard with six heroes, twelve factions and actual voice counts');
