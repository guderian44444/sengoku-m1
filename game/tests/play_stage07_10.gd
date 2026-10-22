extends SceneTree

const Main = preload("res://main.gd")
const Stages = preload("res://core/stage_data.gd")

class App extends Main:
	func _ready() -> void:
		profiles=PlayerStore.new("user://stages07-10-profiles","user://no-stage0710-legacy.json")
		super._ready()

	func _refresh_chapters() -> void:
		chapter_choice.clear()
		var saved := int(profiles.data.get("chapter",7))
		for chapter in Stages.available():
			if int(chapter.id) not in [7,8,9,10]: continue
			chapter_choice.add_item("第%d章　%s" % [int(chapter.id),str(chapter.title)])
			chapter_choice.set_item_metadata(chapter_choice.item_count-1,int(chapter.id))
			if int(chapter.id)<=saved: chapter_choice.selected=chapter_choice.item_count-1

func _initialize() -> void:
	root.add_child.call_deferred(App.new())
