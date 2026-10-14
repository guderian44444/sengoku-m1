# 五招凍結來源重建
在oichi_newspec_arrows資料夾依序執行：

1. python -c "import build; build.render('charge_ready',[0,1,2,3,4,5],[100,100,130,170,180,220]); build.render('charge_hold',[5,6,5],[220,320,220])"
2. python revise_heavy.py
3. python revise_release.py
4. python rain.py
5. python revise_rain.py
6. python rain_circle_sparse_fx.py

只依賴Python/Pillow及本包凍結PNG。最後箭雨範圍以assets/oichi/arrows/rain_package內最新metadata為準。原腳本可能生成帶舊半徑410的中間人物metadata，不得拿來覆蓋最終採用JSON。較方便的最終箭雨重建入口為assets/oichi/arrows/rain_package/render_plus50_half_arrows.py。
