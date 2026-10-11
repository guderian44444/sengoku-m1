# v0.21 護符拾取素材

以內建 `image_gen` 生成一張透明圖，再以 `scripts/register-treasures-v21.py` 裁切。裁切內像素與 Alpha 完全保留；未去背重繪、未縮圖、未補畫。

| ID | 素材 | 抵傷量 | 遊戲顯示 |
|---|---|---:|---|
| `kongo` | `kongo.png` 金剛護符 | 40 | 高 56 px，保持長寬比 |
| `iron` | `iron.png` 玄鐵護符 | 75 | 高 56 px，保持長寬比 |
| `mirror` | `mirror.png` 明鏡護符 | 110 | 高 56 px，保持長寬比 |

抵傷量為 v0.21 初始平衡值；遊戲邏輯以核心資料為準。圖內無文字，三件以金紅、玄鐵青玉、古銅紫白區分。

金剛的素材 ID 為 `kongo`，核心護符 ID 為 `vajra`；`battle_view.gd` 明確將 `vajra` 對應到 `kongo.png`，其餘兩款 ID 相同。

- 原圖：`treasures-source.png`，1983 × 793 RGBA，Alpha 0–255。
- 完整提示：`prompt.txt`。生成方式為內建工具，未使用 CLI/API fallback。
- 原圖／提示／裁切檔 SHA-256 與原圖裁切區域：`registration.json`。
- 原始生成來源：`C:\Users\guder\.codex\generated_images\01a12aec-98f8-71c1-89a9-d2d766e41392\exec-2dd7c869-35d6-4c1c-a64e-5c9c1b7c1039.png`。正式專案不依賴此路徑。

已檢查生成原圖、透明通道與裁切一致性。實際場景上的拾取大小、遮擋、光環及音效由遊戲整合驗收。
