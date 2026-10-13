# 秀吉 v27 素材接入交接

## Git 版目錄與驗證

此 PR 只新增秀吉素材與交接，未接入主遊戲，也不修改 Oichi。本文下列 `runtime/` 指完整下載包；在 Git checkout 中對應 `game/assets/v27/hideyoshi/`，沒有額外 runtime 子目錄。QA 放在 `docs/qa/hideyoshi-v27/`。

Git 不重複儲存可重建的 39 張 sheets，亦不複製既有 v22 三把 review 刀。從儲存庫根目錄執行：

```sh
python game/assets/v27/hideyoshi/production/verify_package.py
python game/assets/v27/hideyoshi/production/rebuild_assets.py --output /tmp/hideyoshi-rebuild-new --previews --weapons-dir game/assets/v22/weapons
```

需要 Python 3.12+、Pillow、numpy，output 必須是新的空目錄。重建腳本會產出 body、foreground、sheets 與預覽，不寫入遊戲資產。

獨立 QA 的 `final_registration_sha256` 對應完整包 registration。Git registration 僅移除未出版 sheets 的 `native_sheet` 引用，並將 source_root / authoring_root 改為同層 `sources/` / `production/`；畫格、握點、刀角、hash 與其他素材資料保持一致。

本包是離線角色素材與提案座標。未安裝到主遊戲，沒有原生遊戲錄影或戰鬥系統驗證。

## 必須接上的資料
- runtime/registration.proposed.json：39 clips，每個6格；file、rect、foot、body_height、hand、weapon_angle與主刀前後層。
- runtime/equipment-placement.json：逐格逐刀的effective grip／normalized offset，三把刀保留既有世界長度85或115。不是所有刀共用同一像素握点。
- runtime/layers/hands：原圖手指／近前臂前景像素。先body、主刀、再foreground；weapon_behind時刀先body後，仍覆前景。
- 二手第二握點只供擺位/驗收，不是IK。被遮住的左右手保持authored_evidence低信度／參考／推定說明，不能改寫為直接量測。
- 扇子固定在角色body，special_1取出、special_2左手持、special_3放回腰；不得另加第二把腰扇。
- 主刀完全独立，身体只有空鞘。sheathed模式只顯示目前裝備刀的柄／鍔，於scabbard_mouth掛接；drawing/resheathing以鞘口平面裁掉已入鞘刃段。前景袖臂遮住柄時仍用原像素foreground。
- 武器角度0朝上、90朝右、順時針；鏡像必須同時鏡像主手、第二手、前景、鞘口與刀角。09/21本身是右向基準下向左返斬，不是整個角色翻向。
- color profiles只改RGB，alpha和原生尺寸/坐標完全不動；sources中保留原生檔。

## 需工程端處理
1. 與遠端main及未合併其他角色工作對齊，新增Hideyoshi loader/portrait。不能覆蓋Oichi成果。
2. 秀吉武器家族由spear轉sword，明確舊存檔/庫存遷移策略，不丟失已有武器。
3. upper_heavy、ground_slam、mixed_finisher、mixed_rising獨立路由，避免舊別名吞掉新動作。
4. special_1/2/3是一次U的三段共18格。舊210tick/8hit不能直接套新3接觸點；傷害事件和取消窗口由遊戲設計確認。
5. 09後方判定/位移，11與14非砸地，16空中命中，不沿用長槍地波。刀音效/VFX需隨武器家族。
6. 19投摔在L放開即傷害的舊邏輯，需對齊holding→throw与敵方獨立層，不把灰色假人加入body。
7. charge/holding的6格目前舊程式只用前半；新保持/回守路由需明確。
8. 確認走跑速度、起跳z、倒地root、受擊恢復等時間，source不靠bbox縮放。建議世界身高仍155，矮壯感來自人物比例；改碰撞高度是另項設計。
9. 有些欄位是本包擴充，現有loader不讀：hand_foreground_file、fan_state、main_weapon_state、equipment placement、sheath plane。integration helper只是算式範例，不是完整引擎patch。

## 原生測試清單
- 所有按鍵/組合、命中frame04（投摔例外）、連段取消、攻速修改、受擊打斷、charge蓄放。
- 3把刀左右向、雙手、返斬、取收扇、納拔刀，刀尖不穿腿/地板、柄不穿手、無重複主刀。
- launched末格→down04→down06→recovering01→idle，兩腳完整、root不跳，死亡down末格保持。
- 網路/重播/存檔、舊槍庫存遷移、圖集載入、記憶體與效能。

離線合成預覽只驗素材擺位，不能取代以上原生測試。
