# 阿市攻擊畫面要素

2026-10-14 最終17招已整合。採用版本、代表圖與說明如下；[完整分層索引](../oichi-final.md)、[交接文件](../../HANDOFF-OICHI-FINAL-20261014.md)。

最新修訂優先於原始共通規格：空中重手採近／中／遠三箭，箭雨半徑1230／70支，反摔採registered13格。各招依逐格duration播放，不固定六格；本批尚未接runtime。

主武為弓；輕手拿弓近打，地面重手與集氣共用拉弓動作，點放一箭擊退、滿蓄放開一箭擊退加穿透、滿蓄上方向加放開為箭雨。依[共通規格](../README.md)分開人物、弓弦箭、效果。

## 身份與動作風格

使用[目前核準身份來源](../../../prototypes/oichi-final-20261014/references/oichi-idle-v27.png)與[阿市登錄契約](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/source-spec/oichi-v27-registration.md)。保留長黑馬尾、紅金髮飾、原臉、白上衣紅邊、紅裙、黑紅護腕、白襪與紅白鞋、既有腿長與衣料質感。弓射姿勢是左手握弓、右手拉弦；鏡像改變屏幕朝向，不在連續動作中交換解剖持手。

## 動作畫面與分層要素

| 動作索引／採用版本 | 代表圖與正常速度 | 人物動作與說明 | 武器層 | 效果／接觸 | 播放格數／時長 |
| --- | --- | --- | --- | --- | --- |
| `light_1` · v2 | ![輕攻擊第一段](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/light_1.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/light_1.gif) | 上舉蓄勢後向前下方大幅揮弓；前踏、擊中、收回共同待機。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/melee/light_1_v2/anchors_events.json) | 弓身上舉後向前下方揮打；雙手握持，弦未拉開 | 踏步、鈍擊；前段推人，不發箭 | 8／840 ms |
| `light_2` · v2 | ![輕攻擊第二段](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/light_2.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/light_2.gif) | 重新製作明確下擊，肩肘帶動弓身砸向前下方，避免像從後方拉回。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/melee/light_2_v2/anchors_events.json) | 弓身向前下方明確下擊；不從後方拉回 | 第二次鈍擊與推人 | 8／840 ms |
| `light_3` · v3 force | ![輕攻擊第三段](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/light_3.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/light_3.gif) | 加重扭腰蓄勢、蹬地跨步與深弓步，肩臂伸展橫掃；接觸後擊飛，末格回共同待機。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/melee/light_3_v3/anchors_events.json) | W弓輕前方大弧 | 接觸 FX擊飛；不換成飛針或踢腿 | 10／970 ms |
| `heavy` · horizontal 9 keys | ![站立重射](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/heavy.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/heavy.gif) | 短拉弓後單箭水平射出；增加兩張有效過渡姿勢，保留回待機。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/arrows/heavy_package/heavy_horizontal_9keys/animation.json) | W前射點放；一箭由指尖扣弦點離弦 | FX箭尾與確認接觸擊退；沒有指定冰凍 | 9／800 ms |
| `charge_ready` · v1 approved | ![蓄力拉弓](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_ready.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_ready.gif) | 逐步舉弓、開肩拉弦至臉頰附近；雙腳固定支撐。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/arrows/charge_ready/animation.json) | 拉弦指尖、弓梢、箭尾三者連續移動 | 集氣開始；人物與弓不能突然換比例 | 6／900 ms |
| `charge_hold` · v1 approved | ![滿蓄保持](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_hold.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_hold.gif) | 保持滿弓瞄準，少量呼吸循環；此段不發射。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/arrows/charge_hold/animation.json) | 弦中點落在右手手指，箭尾確實扣弦 | 滿蓄提示可保持；不提前放箭 | 3／760 ms |
| `charge_release` · horizontal | ![蓄力貫穿箭](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_release.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_release.gif) | 放弦後單箭水平貫穿；以實際碰撞處理擊退，無冰爆。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/arrows/release_package/charge_release_horizontal/animation.json) | W前射滿蓄；只有一支穿透箭 | 箭離弦時停止蓄力；實際接觸擊退，箭繼續穿透 | 5／660 ms |
| `charge_rain` · radius1230 arrows70 | ![圓形箭雨](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_rain.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/charge_rain.gif) | 滿蓄蹲身、舉弓向空中射箭，箭離屏即啟動以阿市為中心的大圓形箭雨。70支隨機錯落落下，半徑1230來源座標單位；前後景分層。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/arrows/rain_package/charge_rain/animation.json) | W朝天箭雨；一箭向上，出畫面後落下獨立箭雨 | 箭出畫面即開始箭雨；區域敵人擊倒 | 10／1300 ms |
| `air_light` · v2 deep downswing | ![空中輕擊](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/air_light.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/air_light.gif) | 空中舉弓後更大幅向前下揮，接近地面敵人；此招是弓身近戰。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/oichi_air_light_v2/air_light/anchors_events.json) | W空中輕，用弓身打 | 攻擊力／範圍各加 20%；無射箭 | 6／560 ms |
| `air_heavy` · v3 shallow far | ![空中三箭](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/air_heavy.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/air_heavy.gif) | 同時射出近、中、遠三支箭；角度較平、最遠射程加長。最新視覺方向取代早先平行／半畫面試案。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/oichi_air_heavy_v3/air_heavy/anchors_events.json) | 同時發射近、中、遠三箭；角度較平，最遠射程延伸 | 擊退；射程依最新近／中／遠軌跡，不自行套 30% 加成 | 6／740 ms |
| `dash_heavy` · v1 approved | ![衝刺重擊](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/dash_heavy.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/dash_heavy.gif) | 衝刺最後一步前踏，弓身大範圍掃擊後制動站穩；不蓄力、不射箭。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/dash/dash_heavy/anchors_events.json) | W跑步前揮，以弓身接觸 | 一般敵人擊飛；盾兵一般命中，王格擋按事件 | 6／640 ms |
| `grab_start` · v1 approved | ![抓取起手](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_start.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_start.gif) | 將弓收納側背，伸手抓住上臂或衣領，把目標拉近。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/grabs/grab_start.json) | 弓與弦獨立收納，未拉弦 | 對手接點用獨立人物合成 | 6／680 ms |
| `grab_hold` · v1 approved | ![抓取保持](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_hold.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_hold.gif) | 維持雙方抓取接點與距離，小幅準備膝擊。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/grabs/grab_hold.json) | 弓安全收納 | 保持距離，不播放箭尾 | 3／720 ms |
| `grab_hit_1` · six keys | ![第一膝擊](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_hit_1.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_hit_1.gif) | 膝擊加入兩張過渡，共六格，190ms接觸，回到保持位置。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/grabs/grab_hit_1_six/metadata.json) | 同上 | 膝部接觸才鈍擊；裙片與腿部前後正確 | 6／420 ms |
| `grab_hit_2` · v1 approved | ![第二膝擊](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_hit_2.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/grab_hit_2.gif) | 第二次獨立膝擊接觸，收回後準備轉髖。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/grabs/grab_hit_2.json) | 同上 | 第二次接觸獨立 | 4／440 ms |
| `throw_forward` · edge cleaned | ![前摔](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/throw_forward.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/throw_forward.gif) | 轉髖拉人後向前拋出，已清除鄰格多餘手部污染；目標軌跡獨立。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/grabs/throw_fixes/throw_forward_metadata.json) | 弓不穿受害者 | 拋出後碰人擊飛，落地另觸發 | 8／900 ms |
| `throw_reverse` · registered slim13 | ![反向過肩摔](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/throw_reverse.png)<br>[播放GIF](../../../prototypes/oichi-final-20261014/docs/combat-art-reference/images/throw_reverse.gif) | 轉身、上肩、向後拋出；細腿版本保留，13格承重腳定位校正，580ms放手，結束面向左。 [接點與事件](../../../prototypes/oichi-final-20261014/assets/oichi/grabs/reverse_coherent/registered_metadata.json) | 弓退後層 | 對手方向隨反向輸入改變，不能只把正向圖平移 | 13／960 ms |

## 拉弓與箭雨關鍵畫面

| 畫面 | 必須可讀 |
| --- | --- |
| 準備 | 左手握弓接口，右手還未拉開，兩腳與弓射方向穩定 |
| 舉弓 | 左臂送出，右手接近弦；弓不從別處瞬移到手 |
| 拉弦 | 右肘往後、肩背發力，弦的中點跟隨實際指尖 |
| 滿拉 | 箭尾、拉弦指尖重合；右手靠近面頰，左手握弓不漂 |
| 釋放 | 鬆指，弦彈回；箭從弓前方離開，右手少量向後隨動 |
| 收手 | 弓仍在左手，肩肘降回準備；馬尾、裙片逐步停止 |

箭雨另保留滿蓄轉蹲與向上抬弓的交接，不能一格突然從站立前射換成蹲姿朝天。朝天箭、箭雨不畫在人物圖裡；三箭與單箭按不同武器／彈體配置輸出，不生圖出三張完整阿市代替。

## 分件與握點

頭、長馬尾、軀幹、裙片、上下臂、握弓手、拉弦手、上下腿與腳掌分開。握弓手量測弓柄中心，拉弦手另量測指尖，不把手腕當扣弦點。膝擊時保留裙片原設計與遮擋，不靠改變裙長修正動作。弓打的輔助手不得填入現有弓弦用 `second_hand`。

## 人物層生成提示

```text
精確沿用原核準阿市的臉、長黑馬尾、紅金髮飾、白紅上衣、紅裙、黑紅護腕與紅白鞋。
動作選本文件一列。射箭左手握弓、右手指尖拉弦；空中輕手與地面輕手均拿弓揮打。
只輸出人物：空握弓柄、拉弦指尖與肩肘發力，不畫弓身、弦、箭、箭尾或效果。
固定右向四分之三鏡頭、同一頭身比例、腿長及站立等效尺度。
真透明 RGBA，完整頭髮、手指、腳，裙片前後遮擋符合原服裝。
```

## 本角色檢查

點放、滿蓄前射、上方向箭雨三個分支都有；拉弦手與弦接點準確；箭離弦才出現；朝天箭出畫面才落雨；空中三箭按最新v3採近、中、遠三支較平且更遠的軌跡，取代舊平行／半畫面規格；弓打不混入飛針／踢擊。參照[武器](../weapons.md)與[效果](../effects.md)。
