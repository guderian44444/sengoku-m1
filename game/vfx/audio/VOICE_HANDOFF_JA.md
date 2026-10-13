# 日文配音交接

用戶已確認全部日文；新配音或有問題的既有音檔留由 Codex 製作，不阻塞本批 SFX。不要使用中文配音，不模仿特定聲優、不從同一嗓音強制pitch生成整隊。

## 六英雄台本與讀音

- 信長 existing：天魔の刃！／てんまのやいば！／Tenma no yaiba. 有力成年男聲，中低音、少量粗邊，統帥般自信。收尾「ば」果斷。
- 阿市 existing：氷の羽！／こおりのはね！／Kōri no hane. 成年女性，清亮有力、運動感，胸腹支撐；避免耳語、幼童感或尖細失真。
- 秀吉 legacy：大返し！／おおがえし！／Ōgaeshi. 新名目標：千成奇策！／せんなりきさく！／Sennari kisaku. 成年男性明亮靈活tenor，有狡黠自信的短促起句；最後「さく」爆發。新名讀法是交接建議，未有此台詞錄音。
- 家康 legacy：三河の意地！／みかわのいじ！／Mikawa no iji. 新名目標：三河不動！／みかわふどう！／Mikawa fudō. 成熟男性溫厚有重量baritone，先沉穩壓住氣，再一口氣堅毅喊出；不做喉嚨低吼替代字詞。新名讀法是交接建議，未有此台詞錄音。
- 光秀 existing：月光一閃！／げっこういっせん！／Gekkō issen. 成年男性集中、清晰、銳利tenor，字頭乾淨、停頓少、收尾俐落。
- 忠勝 existing：蜻蛉切！／とんぼきり！／Tonbokiri. 成年男性強健粗獷bass-baritone，全胸腔投射，爆發力強而吐字清楚，不加嘶吼詞或吼叫蓋字。

以上existing字詞依倉庫metadata，不代表本次聽寫核實。讀音為台本指導；應由日文聽審確認長音/促音/清晰度。

## 表演與錄製

僅說一次完整招式名，熱血街機戰鬥喊聲，有呼吸支撐與爆發尾字。無旁白、無背景音樂、無多餘詞、無特定真人仿聲。分別設計角色嗓音與個性，不能共享同一聲演換pitch。
建議目標0.8–1.8秒，盡量與蓄力→首打/主打相連；在新三段時間表確定前不要強裁字詞。保留乾聲母帶，少量EQ/壓縮另出game版，所有处理存recipe。

## 檔名與槽位

- 現成 remaster：voice_wav/{actor}_special_0.wav、voice_ogg/{actor}_special_0.ogg。保留原台詞。
- 待製作：voice_wav/hideyoshi_sennari_kisaku_ja_01.wav、voice_wav/ieyasu_mikawa_fudo_ja_01.wav（目前不存在，不能当作有效asset）
- 新稿slot詳見voice_slots.json，status=missing且asset=null；不得播放錯名alias，fallback=silence。字幕可正常顯示新名。
- 48kHz mono PCM16 WAV，Ogg Vorbis q6；sample peak建議≤-3dBFS、true peak≤-1dBTP，零削波。响度以整體遊戲混音驗收，別僅靠LUFS。

## 觸發

legacy：動作tick0一次，SFX按manifest裡各英雄既有hit tick。新draft三段：開招一次；等動畫authoring cue確定再定第一個重擊，不沿用210tick當成新方案。遊戲慢動作只讓cue跟模擬tick，不pitch語音。暫停亦暫停語音；取消/換場必須停止。

## 待驗收

1. 六英雄及boss逐段日文聽寫、確認喊法真的熱血且性別/個性一致。
2. 新秀吉/家康台詞聲演尚缺，Codex交接生成並驗聽。
3. 全遊戲音量：兩人同時放招、音樂、8連擊、人群音效都要驗；目前僅數值QA。
4. 恢復boss專名時，對照實際招式是否相符，不盲目覆寫boss泛用heavy映射。
