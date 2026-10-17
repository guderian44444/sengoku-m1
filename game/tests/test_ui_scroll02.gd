extends SceneTree
const Main = preload("res://main.gd")
const Typography = preload("res://render/game_typography.gd")
var checks := 0
var failures := 0
var captures := false
var output := ""
var evidence: Array = []

class App extends Main:
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func settle():
	for frame in range(4): await process_frame
func capture(name: String):
	if not captures: return
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	check(im.save_png(output.path_join(name+".png"))==OK,"Native screenshot "+name)
	evidence.append({"name":name,"pixels":[im.get_width(),im.get_height()]})

func run():
	captures = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	output=OS.get_environment("TEST_ARTIFACT_DIR")
	if output.is_empty(): output=ProjectSettings.globalize_path("res://../artifacts/ui-scroll02/scales-states")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	root.size=Vector2i(1280,720)
	var app:=App.new()
	root.add_child(app)
	app.testing=true
	app.set_physics_process(false)
	app.audio.stop_music()
	app._show_menu_page("main")
	await settle()
	check(FileAccess.get_sha256(Typography.FONT_PATH)=="f5a449d3a9ce2170e404050cc2b44bfa16ae48ef8fb06aa5968383ed74e5ed4d","Runtime font matches approved unmodified MasaFont")
	check(FileAccess.get_sha256("res://assets/current/ui/scroll02/scroll02_blank.png")=="adb7dc6c39225a2005b7bf5952dda1f3a91f5cebc3131969401ce86b04609daf","Runtime scroll matches approved unlettered source")
	for pixels in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1920,1080)]:
		root.size=pixels
		await settle()
		for node in app.menu_pages.main.get_children():
			if not node is Button: continue
			var face: Font=node.get_theme_font("font")
			check(face==Typography.font() and face.variation_embolden==0.0,"Native dynamic font at "+str(pixels))
			check(node.get_theme_constant("outline_size")==0,"No synthetic text outline at "+str(pixels))
			check(Rect2(0,0,1280,660).encloses(node.get_global_rect()),"Main button fits design space at "+str(pixels))
			var available: float=node.size.x-node.get_theme_stylebox("normal").content_margin_left-node.get_theme_stylebox("normal").content_margin_right
			check(face.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x<=available,"Actual main label fits central paper at "+str(pixels))
		await capture("main-%dx%d" % [pixels.x,pixels.y])
	root.size=Vector2i(1280,720)
	await settle()
	app.menu.hide()
	var layer:=CanvasLayer.new()
	layer.layer=100
	root.add_child(layer)
	var board:=Control.new()
	board.theme=Typography.theme()
	board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(board)
	var background:=ColorRect.new()
	background.color=Color("dfc99d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(background)
	var title:=Label.new()
	title.text="MasaFont Regular　／　02 紅錦卷軸・實際控制項狀態"
	title.position=Vector2(60,35)
	title.add_theme_font_size_override("font_size",28)
	board.add_child(title)
	var buttons: Array[Button]=[]
	for i in range(6):
		var text:=Label.new()
		text.text=["正常","滑鼠 Hover","鍵盤／手把 Focus","按下 Pressed","停用 Disabled","長標籤"][i]
		text.position=Vector2(70+(i%2)*640,110+(i/2)*180)
		text.add_theme_font_size_override("font_size",22)
		board.add_child(text)
		var b:=Button.new()
		b.position=text.position+Vector2(0,45)
		b.size=Vector2(500,64)
		b.text="一 人 出 陣" if i<5 else "第三章　今川本陣・決戰"
		b.add_theme_font_size_override("font_size",26)
		board.add_child(b)
		buttons.append(b)
	buttons[3].toggle_mode=true
	buttons[3].set_pressed_no_signal(true)
	buttons[4].disabled=true
	buttons[2].grab_focus()
	await settle()
	var motion:=InputEventMouseMotion.new()
	motion.position=buttons[1].get_global_rect().get_center()
	root.push_input(motion)
	await settle()
	check(buttons[0].get_draw_mode()==Button.DRAW_NORMAL,"Actual normal state")
	check(buttons[1].get_draw_mode()==Button.DRAW_HOVER,"Actual mouse hover state")
	check(buttons[2].has_focus(),"Actual keyboard/controller focus state")
	check(buttons[3].get_draw_mode()==Button.DRAW_PRESSED,"Actual pressed state")
	check(buttons[4].get_draw_mode()==Button.DRAW_DISABLED,"Actual disabled state")
	await capture("native-button-states")
	var report:=FileAccess.open(output.path_join("resolution-state-evidence.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":evidence,"font":"Unmodified MasaFont Regular","input_acceptance":"Synthetic keyboard/controller/mouse only; physical controller pending"},"  "))
	layer.queue_free()
	app.queue_free()
	await process_frame
	print("UI SCROLL02: %d checks, %d failures; native dynamic ink, states and four output sizes" % [checks,failures])
	quit(0 if failures==0 else 1)
