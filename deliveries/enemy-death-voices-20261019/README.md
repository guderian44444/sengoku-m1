# 敵方死亡語音交付（10 段）

這份交付準備了 10 段短促語音，供敵人從存活轉為死亡時隨機播放一段。音檔已由官方下載並實測，全部符合 0.5–1.0 秒；沒有剪輯、正規化、轉檔或改變音量。這個分支未修改遊戲 runtime，也未合併 main。

**儲存庫已在 2026-10-19 核實為 public，因此本分支不包含 WAV 原檔。** 開發者應從作者官方網址下載到本機使用；請勿把下載後的檔案、ZIP、Base64 或 LFS 物件提交到這個公開交付分支。授權與出處見 [LICENSE-SOURCES.md](LICENSE-SOURCES.md)。

| ID | 官方原檔名 | 實測秒數 |
|---|---|---:|
| enemy_death_01 | voice-damage-C01.wav | 0.879456 |
| enemy_death_02 | voice-damage-C02.wav | 0.609524 |
| enemy_death_03 | voice-damage-B03.wav | 0.760454 |
| enemy_death_04 | 23_cool_down.wav | 0.817687 |
| enemy_death_05 | 14_macho_damage.wav | 0.801088 |
| enemy_death_06 | 15_macho_damage.wav | 0.700000 |
| enemy_death_07 | 14_budouka_damage.wav | 0.766259 |
| enemy_death_08 | 16_budouka_damage.wav | 0.673379 |
| enemy_death_09 | 14_nekketsu_damage.wav | 0.734150 |
| enemy_death_10 | 16_priest_damage.wav | 0.960726 |

全部為 RIFF/WAVE、PCM、44,100 Hz、16-bit、單聲道，10 個 SHA256 均不同。秒數直接以 PCM sample frames / sample rate 計算，並核對完整資料長度；沒有依檔名或近似秒數代填。完整官方 URL、位元組大小、樣本數與逐檔 SHA256 在 [manifest.json](manifest.json) 和 [DOWNLOADS.csv](DOWNLOADS.csv)。

取得本機素材（Python 3，只有標準函式庫）：

```powershell
python deliveries/enemy-death-voices-20261019/download_official.py
```

腳本只連線 manifest 中的作者官方網域，逐檔核對 SHA256、WAV 格式、時長和樣本數，保存為 `local-only/enemy_death_01.wav` 至 `enemy_death_10.wav`。每次請求 18 秒逾時，最多 3 個並行請求，不無限重試。目錄和音檔副檔名已由本目錄的 `.gitignore` 排除。下載失敗或官方內容改變時會列出失敗，不會悄悄換成其他素材。

如已下載，可離線複核：

```powershell
python deliveries/enemy-death-voices-20261019/download_official.py --verify-only
```

播放契約與整合檢查見 [INTEGRATION.md](INTEGRATION.md)：只在死亡狀態轉換觸發一次；預載；10 選 1；避免連續重複；死亡語音與普通受擊語音分開。

建議遊戲內署名：`ボイス：ユーフルカ https://youfulca.com/`

驗證日期：2026-10-19 UTC。基準 commit：`702b2f602a553a11469fd34a8337d055093844b8`。所有本次交付檔案的雜湊列於 `SHA256SUMS.txt`（校驗表自身除外）。
