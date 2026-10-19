# 敵人死亡時播放一次

本分支只交付素材取得方式與接入契約，未編輯 `game/` 程式。以下由後續遊戲整合實作。

1. 進入關卡或建立音效管理器時預載 10 段，分組為 `enemy_death_voice`；維持原始 PCM 與素材增益 0 dB。播放時沿用使用者音量設定，不在本交付做逐檔音量修正。
2. 由權威的死亡事件觸發，例如 HP 從 `> 0` 變成 `<= 0` 並進入終結死亡狀態。不要在每幀 `hp <= 0`、繪製 callback 或仍存活的擊倒狀態中觸發。
3. 同一次死亡事件只選一段。以 `(entity_id, spawn_generation, death_event_id)` 或等價唯一事件鍵去重；屍體仍在場、延遲事件重播或網路快照重複不得再次播放。復活/重生後使用新的 generation。
4. 第一次從 0–9 均勻選擇；之後從其餘 9 個索引均勻選擇。上一段索引由此死亡語音群組維護，不與受擊音效共用。
5. 普通受擊使用獨立音效群組。致死傷害的語音分派優先死亡叫喊，避免同一事件同時疊出受擊與死亡兩段人聲；武器撞擊聲仍是獨立的音效判斷。

避免連續重複的選取邏輯：

```text
if event_key already handled: return
mark event_key handled
if previous_index is absent:
    index = random integer from 0 through 9
else:
    index = random integer from 0 through 8
    if index >= previous_index: index += 1
previous_index = index
play exactly one preloaded enemy_death_voice[index]
```

「一次只播一段」是每個死亡事件只觸發一段，不是一次啟動全部 10 段。多人同時死亡可能有多個不同事件；並發音效數上限可沿用現有聲道池，不要每幀重播或排出長隊。多人遊戲應由主機選定索引並連同死亡事件送出，客戶端使用事件鍵去重。

接入前的檢查：

- 10 段全部預載成功，沒有在死亡瞬間從網路或磁碟同步下載。
- 單個敵人死亡後，連續更新多幀仍只播放一次；存活擊倒、受擊與硬直不觸發死亡叫喊。
- 連續多個死亡事件沒有相鄰相同索引；每個非上一段候選都有相同抽取機率。
- 同一事件重送不重播；敵人重生後再次死亡會正常觸發。
- 音量設定生效，原檔 SHA256 不變；公開 Git diff 沒有 WAV、音訊封包或 runtime 檔案。
