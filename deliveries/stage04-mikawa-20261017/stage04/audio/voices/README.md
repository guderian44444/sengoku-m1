# 第四關武將短呼喊：13句試聽候選

2026-10-17，僅語音素材。**未接runtime、未更新任何聲音registry、未提交或推送Git。** 原有鵜殿5.84秒開場白完整保留，沒有拿它切割作攻擊短喊。

## 試聽與檔案

- 三人綜合：[MP3](preview/all.mp3) / [WAV](preview/all.wav) / [OGG](preview/all.ogg)；順序為鵜殿5句 → 富永4句 → 吉良4句，中間無額外口述標籤。
- 個人試聽：[鵜殿](preview/udono.mp3)、[富永](preview/tominaga.mp3)、[吉良](preview/kira.mp3)。[時間索引](preview-index.json)列出每句開始秒數。
- 正式候選：[WAV](processed/wav/)與[OGG](processed/ogg/)，各13檔；PCM16 mono 22050Hz WAV、OGG Vorbis，同一句二選一使用。播放音高1.0，採用檔全數tempo=1.0，沒有為塞入時間加速。
- [manifest.json](manifest.json)是本包採用清單；[event-map.csv](event-map.csv)供動畫端對照。`trigger_ms=null`，由動畫交接決定，沒有預寫runtime時間。
- [raw/](raw/)保存20個原始take（包括落選）、[takes/](takes/)保存每次seed、指令與處理紀錄，[candidates/](candidates/)保留處理中間檔。不要掃描原始資料夾推測採用版本。

## 三人聲線與來源

沿用本機Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice，revision `0c0e3051f131929182e2c023b9537f8b1c68adfe`，`artifacts/voice-v31/custom-model`。本包不含模型權重或套件，未下載新模型/安裝新套件。CUDA、bfloat16、sdpa、Japanese；設定與既有生成腳本SHA見 [settings.json](settings.json)。

鵜殿用合成preset Uncle_Fu，設定低沉厚重；富永用Aiden，設定乾脆銳利中低男聲；吉良用Ryan，設定清楚且有指揮感。這是既有合成聲線及角色表演設計，沒有使用真人演員錄音、沒有模仿真實演員，也沒有採用v30 Base clone流程。實際辨識度仍待聽驗。

原12句沿用頭尾靜音處理；本次備用句保留完整原始輸出，只做高低通、增益與限幅，沒有剪靜音或壓縮時間；沒有切掉句中文字或拼接既有語音。未採用take曾試過最多1.10倍輕微調速，採用13句全部原速。逐檔來源、音檔SHA、模型revision與實際seed皆在manifest與takes。

## 台詞與動畫交接

每次出招只喊一次；鵜殿三連震地只在整次出招喊一次，不跟三次震地重播。富永備用句沒有已定義絕招動畫；吉良撤退/追擊句是有隨行弓兵時可選指令。表內已知ID僅表示動畫方指定對照，**不表示已接遊戲技能或聲音**。

| 武將／素材ID | 指定日文 | 秒數 | 動畫對接狀態 |
| --- | --- | ---: | --- |
| 鵜殿長照 / `udono_uppercut` | 吹き飛べ！ | 0.601 | 動作方向已指定，正式動畫ID待確認 |
| 鵜殿長照 / `udono_rush` | 貫く！ | 0.967 | 動作方向已指定，正式動畫ID待確認 |
| 鵜殿長照 / `udono_sweep` | 薙ぎ払う！ | 1.032 | 動作方向已指定，正式動畫ID待確認 |
| 鵜殿長照 / `udono_quake` | 崩れろ！ | 0.863 | 動作方向已指定，正式動畫ID待確認 |
| 鵜殿長照 / `udono_triple_quake` | 砕け散れ！ | 0.807 | 動作方向已指定，正式動畫ID待確認 |
| 富永伴五郎忠元 / `tominaga_pursuit` | 叩き斬る！ | 0.669 | tominaga_pursuit |
| 富永伴五郎忠元 / `tominaga_heavy_chop` | 一刀両断！ | 1.103 | tominaga_heavy_chop |
| 富永伴五郎忠元 / `tominaga_sweep` | 覚悟しろ！ | 0.609 | tominaga_sweep |
| 富永伴五郎忠元 / `tominaga_reserve_finish` | これで終わりだ！ | 1.120 | 備用；沒有已定義動畫 |
| 吉良義昭 / `kira_command` | 放て！ | 1.204 | kira_command |
| 吉良義昭 / `kira_arrow` | 狙い撃つ！ | 0.630 | kira_arrow |
| 吉良義昭 / `kira_withdraw` | 逃がすな！ | 0.755 | kira_withdraw；有隨行弓兵才選用 |
| 吉良義昭 / `kira_counter` | そこだ！ | 0.627 | kira_counter |

## 驗證與尚待試聽

[verification.json](verification.json)記錄全部原始、候選、正式與預覽音檔的解碼、finite及digital clipping檢查；26個採用WAV/OGG均可解碼、mono 22050Hz、零數位削波。13句輸入文字與指定事件表一致。604個既有語音WAV/JSON的SHA前後一致，見existing-voices-before.json。

**發音/實際台詞內容與演出仍待人工確認。** 此環境沒有日語ASR，工具也不支援音訊輸入，沒有把輸入文字或波形當作已正確念出的證據。富永備用句的舊0.559秒候選已移至superseded；新候選1.120秒，保留完整模型輸出、沒有剪靜音或調速，仍需確認實際完整清楚；若聽驗發現漏字/吞字，應另產生take並保留本次來源，不靠再加速或硬切修補。未宣稱三人聲線主觀驗收、日語自然度、遊戲內混音或動畫前搖時點已通過。

以既有ComfyUI embedded Python執行 `verify.py` 可唯讀重驗。`generate.py`使用本機離線模型；重建前請複製到新的輸出目錄，避免重跑已完成take。`assemble.py`拒絕覆寫既有試聽，原包不需要執行生成程式即可使用。

## r2 核對結果

舊備用句原音0.720秒、成品0.559秒，原始生成本身已偏短。其餘12句採用檔位元完全保留。新生3個完整讀法take，所有原始與落選檔均保留。波形時長只能排查裁切/速度問題，不能證明日文每字完整；本機沒有日語ASR且工具不支援音訊輸入，13句一律維持待人工試聽。詳見preprocessing-audit.json。
