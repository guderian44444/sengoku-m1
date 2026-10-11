# 信長 v0.22 正式人物圖層

以 v19 今川軍正式敵圖的寫實繪製方式重畫，保留成年信長的紅黑金鎧甲、赤色家紋披風、長馬尾、鬍鬚與威嚴神情。待機、走路、跑步皆為雙手握在頭側的立刀預備姿勢；刀具由遊戲武器層疊上，這些來源圖刻意不含烘焙武器。

25 個動作各 6 幅真正重新繪製的姿態，共 150 幅。不是裁切舊十二格減半，也不是同圖平移／旋轉補格。每個原始 RGBA 圖為 1536×1024；解剖站高標尺約 395–445 像素，屈膝、空中收腿、倒地仍按相同人物比例縮放，不用各姿態的外框高度拉伸。

| 類別 | 動作 |
| --- | --- |
| 移動 | idle、walk、run、jump |
| 普攻 | light1 右上至左下、light2 左下至右上、light3 轉身平斬、heavy1 大幅下斬、heavy2 旋身橫掃 |
| 技能 | dash_strike、rising、low_sweep、charged_upper、charged_slam、air_light、air_heavy、special |
| 防守與互動 | guard、throw、victory |
| 受擊 | hurt、stunned、launched、down、recovering |

`dash_heavy` 共用新 light3 的橫向揮砍，位移／扇形劍氣仍由戰鬥邏輯提供。勝利右手高舉刀柄，左手叉腰。受擊有捂腹彎腰與痛苦表情；死亡末兩格完全躺平，起身另畫翻身、手撐、單膝、站立的過程。

`registration.json` 每格包含原圖矩形、腳底錨點、解剖身高、握點、刀具角度與前後遮擋。角度零為刀尖向上，90 度朝右。手部遮擋矩形從同一原圖原像素再畫在刀具上，不生成假手或修改透明度。需要排除鄰格邊角的格子另有 `clip_polygon`；這是執行時顯示範圍，原圖保留完整。

`walk.png` 的蓝色格線是生成時的構圖導引，登錄矩形已裁除格線。其他來源不含格線。所有原生 alpha 都保留；沒有程序去背、去武器、塗改或補幀。拒絕的十四格／跨格初稿不在正式資料夾。

生成方式為內建 `image_gen`，逐動作生成。`prompts.json` 保存完整提示與工具來源路徑；`registration.json` 含每個正式来源 SHA-256。重現登錄：`python scripts/register-nobunaga-v22.py`。來源驗收：`python scripts/test-nobunaga-v22.py`。原生遊戲合成驗收由 v22 renderer 測試負責，來源靜態驗收不等同真人觀感驗收。
