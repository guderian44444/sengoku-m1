# 本多忠勝製作來源與提示摘要

本批採雲端 imagegen，由 v22/tadakatsu/idle.png 的首格作身份參考：黑金甲、鹿角兜、白念珠、紅繫帶、黑羽披風。沒有使用本地 Qwen 或光流。

每招提示以獨立時間順序姿勢、同鏡頭/尺度/光線、完整手腳鹿角、透明背景為約束。刺擊用短收→前踏→沿握軸前推→抽回；第三段與空輕修版強調肩腰側轉、寬握或靠腰帶槍，避免生成雙拳向前的直刺；滿蓄修版明確指定右三分之四、右側、背側、正背、左側、前側的六個真轉向。

部分來源使用品紅細桿限制兩手共線。raw.png 保留帶參考線原始圖；source.png 是移除參考色、編排已選姿勢的生產來源。去線位置可有細小透明缺口，正式槍層覆蓋該軸，不能把人物層單獨作無武器版本使用。

light_1 source.png：生成 exec-fcc21174-ec1c-4e46-85ef-9127ab0a8c14。
light_2 raw.png：exec-3754b42c-ef1b-4bf4-9b25-9d82a030056f；source.png 另引用 light_1 的共用首尾ready。
light_3_v2 raw.png：exec-607df1a5-8013-499c-9853-28fc778911cf。
heavy raw.png：exec-02eb6f29-3571-41c1-a5c4-3e95c2393741。
charge_ready raw.png：exec-94941148-fd8d-4612-9db3-415716518fbe；charge_hold 保留最後一格。
charge_release_v2 source.png：exec-0f5541df-2f44-465e-9854-7b79b993735e，降槍另引用 charge_ready。
air_heavy raw.png：exec-b3d20b3d-e4b8-47d2-b495-db2cf859586a。
dash_heavy raw.png：exec-c2b0e96d-252c-430f-8bcd-7e8aeec060ad，末格引用 light_1 ready。

source.png/raw.png 為保存的來源，不需再次呼叫生成服務。build_action.py 使用 config.json 對已保存來源裁切、清除孤立鄰格、縮放、對腳底、疊完整武器及覆手層，輸出PNG與GIF。未對身體做光流、局部骨骼拉伸或翻轉補動作。
