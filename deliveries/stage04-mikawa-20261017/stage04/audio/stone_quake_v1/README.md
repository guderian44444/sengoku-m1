# 石頭撞擊碎裂與震地低頻補件 v1

僅兩類，各3變體，共6段；每段提供mono PCM16 48kHz WAV和Vorbis OGG。來源為既有Kenney Impact Sounds 1.0 CC0素材，原始License及用到的source_clips均保留。

- rock_impact_crumble_01–03：0.950／1.030／1.110秒。Mining撞擊瞬態＋低頻撞擊身體＋Concrete/Mining細粒分散碎屑，適用石頭撞地／撞硬物後破碎。
- ground_quake_thump_01–03：1.050／1.130／1.210秒。Mining實體撞擊降速、38–180Hz濾波，疊Soft實體撞擊及衰減反射，形成震地低頻。尾段快速衰退，避免三連震糊成持續底噪。

不是staff音效改名；沒有staff聲、振盪器、電子音高滑動或新下載素材。這是以Mining/Concrete/Soft合法擬音設計的衍生效果，不是聲稱真實錄到巨石或地震。音量、濾波、每層來源與hash見manifest及build.py；可按同配方重建。

播放建議：石撞gain0.72，震地gain0.70。WAV峰值約-3dBFS；不須再正規化到0dB。不同變體採隨機袋不連續重複。震地聲在單砸0.56秒及三連0.62／1.30／1.98秒播；每次地面接觸一聲，不跟特效粒子重播。石頭放手0.8／2／3.2秒仍只播既有throw_swing；此石撞聲等實際石頭首次硬碰撞／碎裂才播。不要發射即撞擊，也不要同次碰撞又疊泛用body_collision作兩個主撞擊。

preview.wav／mp3依序：石撞1、震地1、石撞2、震地2、石撞3、震地3，段間留0.65秒。verification.json對12個檔案實際解碼，全部finite、零數位削波、雜湊一致；保留低頻能量比例、峰值、RMS和尾音量測。這些是技術檢查，沒有冒稱已完成主觀聽驗、石材擬真度或遊戲內混音驗收。請以預覽實聽後決定音量。

來源：https://kenney.nl/assets/impact-sounds
授權：https://creativecommons.org/publicdomain/zero/1.0/
既有impact.zip SHA256：029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8
原始作者Kenney；衍生混音沿CC0提供。沒有新增類別、runtime接入或Git變更。
