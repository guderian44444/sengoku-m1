# 阿市新版17招素材入口

2026-10-14。本分支交付阿市人物、獨立弓／弦／箭／VFX、接點事件、代表圖、GIF及原始來源；尚未接入遊戲runtime。

- [阿市招式文件：17招代表圖與說明](characters/oichi.md)
- [完整採用版本及分層metadata索引](oichi-final.md)
- [交接文件與驗證方式](../HANDOFF-OICHI-FINAL-20261014.md)
- [原始單一ZIP下載](../../deliveries/oichi-final-20261014/oichi_final_20261014.zip)
- [原素材包入口](../../prototypes/oichi-final-20261014/README.md)
- [獨立武器規格](weapons.md) · [效果與事件規格](effects.md)

採用版本以 [ACTION_MANIFEST.json](../../prototypes/oichi-final-20261014/ACTION_MANIFEST.json) 為準。3–13個播放格按逐格毫秒時長播放；不能強制六格sampler。空中重手採近、中、遠三箭，箭雨採半徑1230來源單位／70支，反摔採registered13格、960ms、580ms放手及左向結尾。

完整原共通規格與製作來源保存在 [source-spec](../../prototypes/oichi-final-20261014/docs/combat-art-reference/source-spec/README.md)。該目錄保留製作時的歷史規格；其空中三箭舊規則已由本輪最終版本取代。未隨本批交付的其他角色／runtime參考以文字保留，原始文件位元組保存在ZIP。

本分支從遠端main建立，未納入本機main的兩個未發布runtime提交。家康、本多、其他角色和先前VFX交付不在此PR範圍。
