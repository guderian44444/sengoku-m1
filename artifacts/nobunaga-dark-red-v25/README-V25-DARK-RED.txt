信長暗紅甲修正版 v25

用途
這是「48把武器＋上輪三人校色」版本的增量工具包，不是獨立遊戲。
只調整信長17組動作的紅甲RGB，覆蓋全部25組150格檢查。
idle、walk、victory、hurt、stunned、down、recovering、launched 八組原圖逐byte保留。
披風另以逐格遮罩保護；胸甲、肩甲、裙甲、護腿比對idle六格暗紅參考。
局部暴露胸甲另用小範圍柔邊修正，避免把已暗的護腿或腕部再一起壓黑。
alpha、姿態、裁切、握點、武器、阿市與忠勝均不變。

套用方式
1. 先備份你自己的專案。將本ZIP內的 scripts、game 等目錄合併進「最新48武器版」專案根目錄。
   不要用舊18武器版覆蓋目前48武器版本。
2. 確定使用Python 3.12；安裝相同版本依賴：
   python -m pip install Pillow==12.3.0 numpy==2.3.5 opencv-python-headless==5.0.0.93
3. 在專案根目錄執行：
   python scripts/nobunaga_dark_red_v25.py --apply
   python scripts/nobunaga_dark_red_v25.py --check
   python scripts/test-nobunaga-dark-red-v25.py
4. 重新開啟Godot，讓變動PNG重新匯入。工具不會自動push，也未在你的電腦套用。

安全与重現
工具先核對48武器及其他角色等348份檔案、8組保留動作、17張來源與目標SHA256、動作幾何。
全部來源與計算結果都通過才寫入。來源不符就停止，不會拿舊版本硬蓋。
第一次套用會把17張變更前PNG與registration.json備份到 artifacts/nobunaga-dark-red-v25/before。
再次套用不會再加深，可重複執行。完整雜湊在 game/assets/v25/nobunaga-dark-red.json。
遮罩多邊形隨包保留，可核對逐格保護區。原始透明度逐pixel相同。
原v23與v24歷史清單保留不改；新v25清單記錄此次明確允許的舊雜湊→新雜湊。

回復
如需回復本次顏色，把上述before目錄的17張PNG與registration.json複製回 game/assets/v22/nobunaga。
同時將本次工具與v25遮罩/清單保留在備份位置；舊版本完整專案備份是最直接的完整回復方式。

預覽
影片是最新來源圖與已核准武器的素材合成，不是遊戲實機錄影。
完整25動作、150格、左右向；每個原作格固定展示，並非招式原實際時序。
如需自行生成預覽，還需ffmpeg，以及既有 scripts/preview-weapons-v24.py。
執行 python scripts/preview-nobunaga-dark-red-v25.py。
重新生成registration需另裝 scipy==1.17.0，再執行 scripts/register-nobunaga-v22.py。

檢查範圍
本雲端完成前後對照、150格目視、像素不變檢查、乾淨副本重跑/冪等重跑與相關Godot headless測試。
詳細結果見同包VALIDATION.txt與測試紀錄。此修正沒有處理歷史projectile_v12已知失敗。
