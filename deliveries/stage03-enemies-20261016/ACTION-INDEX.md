# 第三關敵軍：37 組動作精確播放索引
此表從原包 manifest／metadata 產生，只供接入。新素材尚未接 runtime。共 178 個播放格、163 種 PNG SHA256；重用／反序不是獨立新繪 178 姿勢。每招 4–9 格，按逐格毫秒播放，不套固定六格 sampler。
`root` 是包內最終 PNG 畫布座標；`scale` 是綜合預覽倍率。下列事件欄保留作者原欄位，不自動轉成權威命中／傷害／格擋窗。原 metadata 的歷史 pending 標記未改寫。

## 盾兵 `shield`

預覽倍率 `0.7`；一般 root `[260, 285]`。

| 動作 ID／原資料 | 格數 | 每格 ms（依播放順序） | 合計 ms | 最終畫布／root | 播放結束 | 事件／缺項 |
|---|---:|---|---:|---|---|---|
| [`shield/idle`](source/metadata/shield/idle/manifest.json) | 4 | 180, 180, 180, 180 | 720 | `[640, 320]`／`[260, 285]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`shield/walk`](source/metadata/shield/walk/manifest.json) | 6 | 130, 130, 130, 130, 130, 130 | 780 | `[640, 320]`／`[260, 285]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`shield/attack`](source/metadata/shield/attack/manifest.json) | 4 | 180, 80, 60, 160 | 480 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | event_frames={"hit":3} |
| [`shield/hurt`](source/metadata/shield/hurt/manifest.json) | 4 | 60, 100, 100, 140 | 400 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`shield/down`](source/metadata/shield/down/manifest.json) | 4 | 100, 100, 100, 700 | 1000 | `[640, 320]`／`[260, 285]` | 末格保持 | event_frames={"grounded":4}；末格保持 |
| [`shield/block`](source/metadata/shield/block/manifest.json) | 4 | 100, 120, 100, 120 | 440 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |

## 槍兵 `spear`

預覽倍率 `0.7`；一般 root `[260, 285]`。

| 動作 ID／原資料 | 格數 | 每格 ms（依播放順序） | 合計 ms | 最終畫布／root | 播放結束 | 事件／缺項 |
|---|---:|---|---:|---|---|---|
| [`spear/idle`](source/metadata/spear/idle/manifest.json) | 4 | 180, 180, 180, 180 | 720 | `[640, 320]`／`[260, 285]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`spear/walk`](source/metadata/spear/walk/manifest.json) | 6 | 130, 130, 130, 130, 130, 130 | 780 | `[640, 320]`／`[260, 285]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`spear/attack`](source/metadata/spear/attack/manifest.json) | 4 | 180, 80, 60, 160 | 480 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | event_frames={"hit":3} |
| [`spear/hurt`](source/metadata/spear/hurt/manifest.json) | 4 | 60, 100, 100, 140 | 400 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`spear/down`](source/metadata/spear/down/manifest.json) | 4 | 100, 100, 100, 700 | 1000 | `[640, 320]`／`[260, 285]` | 末格保持 | event_frames={"grounded":4}；末格保持 |

## 弓兵 `archer`

預覽倍率 `0.7`；一般 root `[260, 285]`。

| 動作 ID／原資料 | 格數 | 每格 ms（依播放順序） | 合計 ms | 最終畫布／root | 播放結束 | 事件／缺項 |
|---|---:|---|---:|---|---|---|
| [`archer/idle`](source/metadata/archer/idle/manifest.json) | 4 | 180, 180, 180, 180 | 720 | `[640, 320]`／`[260, 285]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`archer/walk`](source/metadata/archer/walk/manifest.json) | 6 | 130, 130, 130, 130, 130, 130 | 780 | `[640, 320]`／`[260, 285]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`archer/attack`](source/metadata/archer/attack/manifest.json) | 4 | 180, 80, 60, 160 | 480 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | event_frames={"release_arrow":3} |
| [`archer/hurt`](source/metadata/archer/hurt/manifest.json) | 4 | 60, 100, 100, 140 | 400 | `[640, 320]`／`[260, 285]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`archer/down`](source/metadata/archer/down/manifest.json) | 4 | 100, 100, 100, 700 | 1000 | `[640, 320]`／`[260, 285]` | 末格保持 | event_frames={"grounded":4}；末格保持 |

## 蒲原氏德 `ujinori`

預覽倍率 `0.52`；一般 root `[270, 480]`。

| 動作 ID／原資料 | 格數 | 每格 ms（依播放順序） | 合計 ms | 最終畫布／root | 播放結束 | 事件／缺項 |
|---|---:|---|---:|---|---|---|
| [`ujinori/idle`](source/metadata/ujinori/idle/manifest.json) | 4 | 200, 200, 200, 200 | 800 | `[660, 510]`／`[270, 480]` | 循環 | loop_seam=[4, 1] |
| [`ujinori/hurt`](source/metadata/ujinori/hurt/manifest.json) | 4 | 70, 100, 150, 140 | 460 | `[660, 510]`／`[270, 480]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`ujinori/down`](source/metadata/ujinori/down/manifest.json) | 6 | 70, 90, 100, 120, 120, 300 | 800 | `[660, 510]`／`[270, 480]` | 末格保持 | land_frame=3；末格保持 |
| [`ujinori/guard_retreat`](source/metadata/ujinori/guard_retreat/manifest.json) | 4 | 130, 100, 160, 170 | 560 | `[660, 510]`／`[270, 480]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`ujinori/walk`](source/metadata/ujinori/walk/manifest.json) | 4 | 160, 160, 160, 160 | 640 | `[660, 510]`／`[270, 480]` | 循環 | loop_seam=[4, 1] |
| [`ujinori/slash`](source/metadata/ujinori/slash/timing.json) | 8 | 120, 100, 100, 40, 50, 90, 130, 170 | 800 | `[660, 510]`／`[140, 480]` | 單次後由 runtime 銜接 | 原始timing修補已驗證，8格／800ms一致；世界位移與命中由runtime接入校正 |

## 井伊直盛 `ii_naomori`

預覽倍率 `0.58`；一般 root `[70, 500]`。

| 動作 ID／原資料 | 格數 | 每格 ms（依播放順序） | 合計 ms | 最終畫布／root | 播放結束 | 事件／缺項 |
|---|---:|---|---:|---|---|---|
| [`ii_naomori/idle`](source/metadata/ii_naomori/idle/manifest.json) | 6 | 180, 180, 180, 180, 180, 180 | 1080 | `[680, 550]`／`[70, 500]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`ii_naomori/walk`](source/metadata/ii_naomori/walk/manifest.json) | 4 | 180, 180, 180, 180 | 720 | `[680, 550]`／`[70, 500]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`ii_naomori/thrust`](source/metadata/ii_naomori/thrust/manifest.json) | 8 | 120, 100, 90, 40, 40, 90, 80, 140 | 700 | `[680, 550]`／`[70, 500]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`ii_naomori/guard_retreat`](source/metadata/ii_naomori/guard_retreat/manifest.json) | 4 | 100, 90, 100, 170 | 460 | `[680, 550]`／`[70, 500]` | 單次後由 runtime 銜接 | events={"block_active_frames":[2,3]} |
| [`ii_naomori/hurt`](source/metadata/ii_naomori/hurt/manifest.json) | 4 | 100, 70, 100, 150 | 420 | `[680, 550]`／`[70, 500]` | 單次後由 runtime 銜接 | events={"impact_frame":2} |
| [`ii_naomori/down`](source/metadata/ii_naomori/down/manifest.json) | 6 | 100, 100, 90, 90, 100, 350 | 830 | `[760, 550]`／`[150, 500]` | 末格保持 | events={"ground_contact_frame":5}；末格保持 |

## 今川義元 `yoshimoto`

預覽倍率 `0.62`；一般 root `[200, 480]`。

| 動作 ID／原資料 | 格數 | 每格 ms（依播放順序） | 合計 ms | 最終畫布／root | 播放結束 | 事件／缺項 |
|---|---:|---|---:|---|---|---|
| [`yoshimoto/idle`](source/metadata/yoshimoto/idle/timing.json) | 4 | 180, 180, 180, 180 | 720 | `[640, 560]`／`[200, 480]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`yoshimoto/hurt`](source/metadata/yoshimoto/hurt/timing.json) | 4 | 80, 90, 120, 170 | 460 | `[640, 560]`／`[200, 480]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`yoshimoto/walk`](source/metadata/yoshimoto/walk/timing.json) | 4 | 180, 180, 180, 180 | 720 | `[640, 560]`／`[200, 480]` | 循環 | 未另標事件；依 runtime 狀態銜接 |
| [`yoshimoto/block`](source/metadata/yoshimoto/block/timing.json) | 4 | 130, 140, 220, 170 | 660 | `[640, 560]`／`[200, 480]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`yoshimoto/bow_shot`](source/metadata/yoshimoto/bow_shot/timing.json) | 4 | 180, 300, 80, 220 | 780 | `[640, 560]`／`[200, 480]` | 單次後由 runtime 銜接 | projectile_event @480ms；origin=[460, 240] |
| [`yoshimoto/down`](source/metadata/yoshimoto/down/timing.json) | 4 | 110, 140, 120, 500 | 870 | `[640, 560]`／`[200, 480]` | 末格保持 | 末格保持 |
| [`yoshimoto/naginata_slash`](source/metadata/yoshimoto/naginata_slash/timing.json) | 9 | 130, 140, 120, 70, 40, 70, 110, 100, 220 | 1000 | `[640, 560]`／`[200, 480]` | 單次後由 runtime 銜接 | 未另標事件；依 runtime 狀態銜接 |
| [`yoshimoto/sword_energy`](source/metadata/yoshimoto/sword_energy/timing.json) | 9 | 130, 140, 120, 70, 40, 70, 110, 100, 220 | 1000 | `[640, 560]`／`[200, 480]` | 單次後由 runtime 銜接 | projectile_event @460ms；origin=[490, 395] |
| [`yoshimoto/retreat`](source/metadata/yoshimoto/retreat/timing.json) | 4 | 150, 150, 150, 150 | 600 | `[640, 560]`／`[200, 480]` | 循環 | 未另標事件；依 runtime 狀態銜接 |

井伊 `down` 的畫布／root 與其他招不同；蒲原 `slash` 的 root `[140,480]` 與其他招 `[270,480]` 語義不同。義元原始 timing 中的來源子格 root／translation 不等於已整合 PNG 的 `[200,480]`，不能重複套用。詳見 [Codex 入口](../../docs/CODEX-STAGE03-HANDOFF.md)。
