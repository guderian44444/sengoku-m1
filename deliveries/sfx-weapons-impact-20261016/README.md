# 吞食戰國：全武器音效 v3 素材交付

44類、98個音效、WAV/OGG共196檔。**僅素材與對接文件，尚未接runtime；請進遊戲實聽後調整。**

- [CODEX接入說明與44類對接表](CODEX-INTEGRATION.md)
- [機器可讀runtime對接JSON](runtime-map.json) / [CSV](runtime-map.csv)
- [目前runtime cue、路徑與音量參考](runtime-reference.json)
- [原始單一ZIP](Sengoku_All_Weapons_SFX_v3.zip)：19,515,398 bytes；SHA256 `3fdc045f382f8dd8d5c815b41dc870e86f2b949ecbc67c934d9493ccca390f07`。小於100MiB，直接保留於Git。
- [完整解壓包](package/README.md)、[試聽MP3](package/Sengoku_All_Weapons_Preview_v3.mp3)、[時間索引](package/docs/preview-index.json)
- [獨立驗證報告](verification.json)、[唯讀驗證器](verify_delivery.py)、[來源授權核對](SOURCE-VERIFICATION.md)

指定Library來源：[v3 ZIP](https://chatgpt.com/api/library/files/libfile_ee78523225b48191bd0fec448383a9a7/download)；[獨立試聽](https://chatgpt.com/api/library/files/libfile_db67c193e9c081919dc3a94687cdea69/download)。Git內MP3來自指定ZIP，未另改音訊。

單包與解壓215檔保持原始位元，來源ZIP與授權、manifest、SHA與製作方QA一併保留。v1/v2 build腳本屬包內歷史配方，不代表本批改用舊包。火槍及裝填屬原創設計/Foley試作，非史實錄音。未主觀遊戲驗收。

驗證：`python -X utf8 verify_delivery.py` 核對檔案與對接完整性；安裝numpy、soundfile後加 `--decode` 完整解碼，可用 `--report /absolute/path.json` 另存報告。驗證不改原包、不執行包內腳本。
