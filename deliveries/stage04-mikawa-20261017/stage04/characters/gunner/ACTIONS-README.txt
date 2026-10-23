舊鐵炮兵第四關換裝動作補包
來源：既有v19今川gunner，原始PNG與registration SHA已核對。
內容：gun_shot6格、hurt3格、struggle3格、death6格。保持原姿勢、足點、裁切、身高尺與槍/手原畫，僅採用圖像工具衣料換色區與核准鵜殿徽。倒地最後兩格胸口不可見，不貼漂浮家徽。
原始全圖alpha逐像素一致。分格依同一原圖最大alpha連通主體裁掉鄰格碎片（模仿原runtime component_clip意圖；JS像素連通遮罩並非Godot polygon浮點實作逐位元一致）。左右對比使用同一遮罩，沒有重畫腿或移位。
時序：射擊44tick出彈、90tick結束，前3格起始0/15/30，後3格44/60/75；hurt18tick；struggle6fps，被抓時固定中格；death預設24tick。敵人實際defeated可依death_ticks採非均勻6姿勢門檻，清單保留規則。
缺項：舊圖沒有獨立裝填clip。stunned沿用hurt，recovering是倒播death，down/dead停末格，不能當成獨立新動畫。射擊第5格手部操作不是完整火繩槍裝填流程。
對比GIF是原版/換裝同步審稿，不含新增槍火音效，不改runtime或Git。人物仍保有舊素材本來的每格細節差異。
