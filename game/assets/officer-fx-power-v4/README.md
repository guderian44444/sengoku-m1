# 第1–4關武將劍氣：大半徑／強突刺素材 v4

已覆蓋39個現有招式、50個角色×招式列。32招有新增獨立透明武器FX；另7招沿用弓箭、投石、金色旋槍及槍尾震地原效果。第一關瀨名／鵜殿／井伊仍共用原boss美術。第二關仍只使用現有2姿態，沒有虛構中間角色畫格。

## 這版的尺度
- 掃弧以原圖可見的握武器手為中心，外半徑為握點至武器尖端距離×1.09，依原招式各姿態方向旋轉。弧厚約外半徑×0.34。
- 突刺從尖端發出，視覺長度為握點至尖端距離×1.65，厚度×0.82。這些全部是來源像素尺度，不是世界距離、判定或傷害。
- 沿用第五關白藍氣流紋理。掃弧放在人物後層，保留清晰身形；突刺在前層。沒有重繪、拉長武器或補角色中間格。
- 四招power_v3大尺度方案已獲用戶同意後延伸至全清單；本包v4延伸同樣的尺寸規則。

## 使用
1. 每招資料夾有 metadata.json、透明 pose_XX_fx.png 及 preview_1x.mp4。保留舊特效的招式有 preserved_existing/。
2. source_sequence 保留原60Hz畫格順序和持續時間；原始命中事件在 original_hit_ticks。FX自己的顯現／衰減時間另列 events、opacity_model。
3. fx_by_pose.anchor_px 是來源裁切區域內的像素座標。origin_fx_px 是透明FX圖內原點。以 fx_axis_angle_deg 旋轉，再按照來源角色 body_height 對世界顯示身高的比例縮放。反向時位置與方向一起鏡射。
4. 新增劍氣全部 follow 當前原姿態，release=false，無獨立飛行、無碰撞。既有義元飛行劍氣、地波、箭矢和石塊仍保留各自原本release／運動；不能用新裝飾圖去代替它們。
5. 富永追擊第5格使用同一刀身已知長度與可見方向推得 estimated_from_rigid_weapon 尖端，約±25來源px不確定度，詳見 estimated_endpoint_overrides.json。富永橫掃第5格（tick36–44，600–750ms）刀尖出界且握點被遮，仍無可靠端點，此收招格不顯示新FX；該招主要掃弧於tick36結束。其他已收刀畫格不造端點。其新FX為透明空圖並 visible=false，詳見 anchor_exceptions.json。

## 預覽及核查範圍
- stage1_all_moves_1x.mp4 至 stage4_all_moves_1x.mp4：每招兩次正常速度，固定根點，供人物與FX對位審閱。
- qa_montage_stage1.jpg 至 stage4.jpg：全招代表命中格總覽。
- 這是素材與對位預覽，沒有開Godot執行遊戲；不模擬原敵人世界移動、鏡頭、玩家受擊或投射物世界飛行。原金色旋槍及震地已在預覽沿用；義元飛行波、富永地波、箭雨及投石等世界效果原件保留供現有runtime繼續使用。
- 所有來源影像SHA、原播放順序與時長通過核對；未改runtime、Git、角色來源像素、攻擊或傷害範圍。舊版及原始來源另保留。
- 鵜殿挑天／衝槍／橫掃的舊 other_vfx 圖原本在資產中、但原runtime未接線；本包明列這個狀態。所有本輪新增FX也尚未接runtime。

## 檔案
all_moves_manifest.json：39招總表；actor_coverage.json：50列覆蓋關係；QA.json：核查；preserved_asset_verification.json：舊效果逐byte保留證據。
重建腳本與標註在外層 work/；原來源包恢復內容在 restored/，兩份既有白藍FX紋理在 reference_fx/。需要 Pillow、NumPy、SciPy 及 ffmpeg。腳本只輸出素材，不修改遊戲檔案。
