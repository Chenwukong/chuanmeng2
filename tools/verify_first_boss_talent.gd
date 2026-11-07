extends SceneTree
class TutorialHost extends Node:
	var starts := 0
	func begin_talent_tutorial() -> void:
		starts += 1
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	root.size = Vector2i(1100, 740)
	var data = root.get_node("GameData")
	data.set_process(false)
	data.restore_difficulty(1)
	data.game_flags = {}
	data.talent_ranks = {}
	data.talent_points = 0
	assert(not data.grant_first_boss_talent_reward("机关人"))
	assert(not data.grant_first_boss_talent_reward("方寸山_守关60"))
	assert(data.talent_points == 0)
	assert(data.grant_first_boss_talent_reward("方寸山_守关20"))
	assert(data.talent_points == 1)
	assert(not data.grant_first_boss_talent_reward("方寸山_守关20"))
	assert(data.talent_points == 1)
	var saved = load("res://Script/Save/SaveService.gd").serialize_state(data)
	assert(saved.talent_points == 1)
	assert(saved.game_flags[data.FIRST_BOSS_TALENT_REWARD])
	var host := TutorialHost.new()
	root.add_child(host)
	current_scene = host
	data.current_scene_path = "res://scenes/MainScene.tscn"
	data._auto_save_pending = false
	data.in_battle = true
	data._process(0.0)
	assert(host.starts == 0)
	data.in_battle = false
	data._npc_dialogue_playing = true
	data._process(0.0)
	assert(host.starts == 0)
	data._npc_dialogue_playing = false
	data.ui_blocked = true
	data._process(0.0)
	assert(host.starts == 0)
	data.ui_blocked = false
	data._process(0.0)
	assert(host.starts == 1)
	var tree = load("res://scenes/UI/TalentTree.tscn").instantiate()
	host.add_child(tree)
	tree.show_page("Page_Main")
	var tutorial = load("res://scenes/UI/TalentTutorial.tscn").instantiate()
	host.add_child(tutorial)
	assert(tutorial.active and paused)
	assert(tutorial.headings.size() == 3)
	assert(tree.get_node("PointsBadge/Row/PointLabel").text.contains("1"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/talent_tutorial_preview.png")
	tutorial._next()
	assert(tutorial.page == 1)
	tutorial._previous()
	assert(tutorial.page == 0)
	tutorial._next()
	tutorial._next()
	tutorial._next()
	assert(not paused)
	assert(data.story_flag(data.TALENT_TUTORIAL_COMPLETED))
	assert(is_instance_valid(tree) and tree.visible)
	data._auto_save_pending = false
	data._process(0.0)
	assert(host.starts == 1)
	assert(data.talent_points == 1)
	assert(load("res://Script/World/MainScene.gd") != null)
	print("FIRST BOSS TALENT PASS: guard20 only, one-time +1 point, saved reward flag, battle/dialogue/UI deferral, tutorial navigation and completion, talent page stays open, no repeat")
	quit()
