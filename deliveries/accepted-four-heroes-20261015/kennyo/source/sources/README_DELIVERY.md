# 本願寺顯如03 全16招素材交接

本包為已核准03白頭巾、大念珠、深色僧兵戰鬥束裝的遊戲改編。實際歷史人物身份與遊戲戰法分開，不宣稱歷史顯如曾使用這些兵器或招式。

## 最新優先規則
- source/specs 的招式文件是本機未追蹤全文快照，不是已提交 main 版本。
- 原文件的高舉杖集氣／頭頂轉兩圈已被使用者後續明示覆蓋：收杖、站立合掌念經、保持段人物完全不動、取下念珠拉長後左右各一擊為一輪，共三輪六擊。
- 2026-10-15 最新修正版珠串為可彎曲連續軟鏈，佛號改為正立佛教卍字，在六擊各自高速砸出，獨立位移、短拖尾與終點散光。不得回用舊硬圓環預覽。
- 常規預覽持飾頭錫杖。完整長棍、錫杖、03薙刀為獨立武器圖。抓技與集氣/念珠時保留安全背收杖。

## 尺規與時序
以本多冠頂至腳底（不含鹿角）163px為站立等效。各來源sheet依頭/軀幹/骨長單一倍率；蹲身或跳躍不可重新等高。腳底root與人物pose分開。所有GIF為製作預覽時序，不是已驗證引擎攻速。

## 各招
light_1 / light_2 / light_3 / heavy / charge_ready / charge_hold / charge_release / air_light / air_heavy / grabs/grab_start / grabs/grab_hold / grabs/grab_hit_1 / grabs/grab_hit_2 / grabs/throw_forward / grabs/throw_reverse / dash_heavy。

每招有原始imagegen圖、來源提示、透明人物、武器前後、手指遮擋、獨立FX、正常/慢速GIF及量測事件資料。部分招式的敵人替身獨立分層。現階段人物是逐關鍵姿勢完整繪製，不是已分拆成完整可重綁骨架；被衣袖遮住的肢段不能當成已有完整骨架。

## 集氣三招當前入口
- charge_ready/normal.gif = kennyo03_charge_ready_stow_staff.gif。stow-metadata.json 為收杖姿勢與握點資料；body_stow_XX 為最新人物層。舊 body_canvas 為原合掌身份基準，勿誤用舊武器空白預覽。
- charge_hold/normal.gif = kennyo03_charge_hold_staff.gif。composite_01及weapon_back_01對應固定保持。完全不移動人物，效果可另行疊加。
- charge_release_v4/normal.gif = kennyo03_bead_manji_impact_v4.gif。metadata記錄38個人物播放關鍵格（原33+5）、6個獨立strike事件，beads_back/front及effect各自分層。v3補了抬臂越頭頂與肩胸腰發力的新人物姿勢；v4人物和念珠完全保留，只更新卍字效果，左拉越頭右甩，再反向。招後杖仍安全背收；回持杖可用收杖序列反向，需接入時檢查過渡。
- charge_release整個舊資料夾為歷程，含舊圓環/柔性v2預覽，均非目前入口。最終snapshot/manifest.json是唯一總索引。

## 接入邊界
未改Git/runtime/網站。接入仍需引擎驗證碰撞、攻擊取消、目標判定、世界位移阻擋、跨招回guard與抓取釋放事件。範圍/傷害+20%或+30%是招表邏輯，不能靠放大人物實現。所有原圖與生成提示保存；無Comfy、Qwen、光流。

## 最終修訂入口
請以snapshot manifest每個action的source_directory為準，不猜無版本號的目錄就是最新。light1改10格真揮弧，單一解剖腳前掌固定支點，末段前伸尾握；light2保持7格單揮，起手正常握持、末段才滑至尾握；light3改11格正面左上到右下斜掃；兩頭槌共用第二下6格600ms但事件獨立；兩摔各12格，空輕/空重各11格；跑重改7格前戳。此說明不表示已獲得整套最終審核，仍為逐招候選。

最新FX入口為charge_release_v5/normal.gif；v4直射版已被向外與斜上不規則爆散取代。以snapshot總manifest為唯一入口。
