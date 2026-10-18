# 秀吉九組已接受基本動作（頭95%、站高尺規150px）

本包共九組、56格，最新版均已由使用者接受；核准戰鬥 idle 和既有16招保持不變，尚未接入遊戲。

## 動作與版本
- walk: 8 格 / 960ms / loop=True / walk_v1_original_direct_hi_res
- run: 6 格 / 480ms / loop=True / run_v2_contact_torso_true_passing
- hurt: 6 格 / 480ms / loop=False / hurt_v1_direct_original_highres
- stunned: 4 格 / 800ms / loop=True / stunned_v1_direct_original_highres
- jump: 10 格 / 900ms / loop=False / jump_v3_upright_airborne
- launched: 6 格 / 500ms / loop=False / launched_v2_explosive_knockback
- down: 4 格 / 620ms / loop=False / down_v1_direct_original_highres
- recovering: 6 格 / 900ms / loop=False / recovering_v1_direct_original_highres
- victory: 6 格 / 1300ms / loop=False / victory_v1_direct_original_highres

## 近期修訂
- jump：10格900ms，地面230ms蓄勢，前傾屈膝→伸髖蹬地；上升和頂點軀幹接近直立，下降才準備落地。
- launched：6格500ms，加速離地、後仰及四肢慣性甩開；world後飛210px、最高105px；末格接down。
- down：落地接觸、壓縮、反作用、靜止共4格620ms；可死亡停在第3格（零起算）。
- run v2：6格480ms，一圈左右各一步。2/5加入髖下passing，保留前傾3/4側視。上半身由原生高解析contact合成，下半身採原生passing；官方imagegen只修腰甲下小接縫，僅局部遮罩採用生成結果。頭胸與contact的遊戲縮尺相同，遮罩外原始像素不變。

## 檔案與使用
- 每組 metadata.json 提供逐格時長、root、腳點、握點、武器角度、圖層前後順序、loop與位移。frames/內 body、weapon、hand_occlusion 是獨立透明RGBA；composite可作渲染參考。
- 圖層順序：body → weapon → hand_occlusion。hand_occlusion僅放實際遮住武器的手部像素，部分idle遮層很小是正常的。
- root/world位移與預覽位移分開；PNG是角色局部座標，勿重複套用位移。GIF為審閱方便可能重播；遊戲是否循環以metadata.loop為準。
- run世界位移每圈134px；walk每圈位移見metadata。非循環動作的GIF重播回到首格，不代表遊戲中倒退或自動復活。
- launched末格與down首格完全同圖層；down末格與recovering首格完全同圖層。銜接時保留角色當前world位置。
- idle/composite_00.png是核准合成圖逐byte副本。idle原始登錄PNG皆保留；metadata引用 *_exact_00.png 作精確三層輸出，只重新切分手部36像素，最終視覺不變。
- 肖像只由核准圖裁切，沒有另畫。普通基本動作全部沒有FX。

## 高解析來源與尺規
原始身份與完整戰鬥母圖在reference/。所有全身姿勢用官方imagegen直接參照原圖；原始PNG完整保留。生成時只增加高解析衣褶與既有甲片線條，不加裝飾。人物有效高度或橫躺長軸至少600px。沒有由小遊戲圖反覆生成、全身鏡像換腳或光流補格。
各姿勢按頭胸及肢體量體校準，不以人物外框等高；保留蹲下、跳躍和倒地的姿勢高度差。頭部局部95%，人物保留高解析到最終一次遊戲尺寸縮小。run高解析合成只放大原生上半身至共同組裝畫布，最後才縮至遊戲尺寸。

## 技術驗證
technical_audit.json記錄56格三層重組全相同、透明邊界無裁切、GIF格數/總時長一致、idle與倒地銜接，以及既有16招48個檔案雜湊未變。這是檔案與像素驗證，不等於遊戲實測；使用者接受另由 acceptance.json 記錄。

## 兩個版本的包
- full_highres：保留採用的原始PNG、縮小前素材、參考母圖、三層逐格圖、metadata、審閱圖與腳本。未採用的研究稿不混入正式來源清單。
- runtime_review：僅含三層逐格圖、metadata、核准idle/肖像、武器來源與審閱GIF/PNG，便於整合。高解析來源欄位仍保留，但原母圖只在完整包內。
本次完整包與輕量包包含idle精確圖層修補，取代早前單組草稿ZIP作為最新技術交付。

接受事件：Sentinel_14a43a0d05ec8191b50a482834f7a976。此次只更新接受狀態與正式登錄清單，PNG/GIF 位元不變。核准 idle 與裁切肖像正式登錄於 registered-assets.json。
