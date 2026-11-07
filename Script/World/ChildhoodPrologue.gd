extends CanvasLayer

const SEEN_FLAG := "childhood_prologue_seen"
const DIALOGUE = preload("res://Dialogue/childhood_prologue.dialogue")
const PARTS := [
	["start", preload("res://Audio/BGM/Childhood/滑稽.wav"), null],
	["contest", preload("res://Audio/BGM/Childhood/世界地图.wav"), null],
	["reunion", preload("res://Audio/BGM/Childhood/温柔2.mp3"), null],
	["relic", preload("res://Audio/BGM/Childhood/欢快2.wav"), preload("res://scenes/World/ChildhoodStages/RelicHall.tscn")],
	["borrow_talisman", preload("res://Audio/BGM/Childhood/战后.wav"), preload("res://scenes/World/ChildhoodStages/BorrowTalisman.tscn")],
	["invisibility", preload("res://Audio/BGM/Childhood/滑稽.wav"), preload("res://scenes/World/ChildhoodStages/Invisibility.tscn")],
	["wanyu", preload("res://Audio/BGM/Childhood/恶魔进行曲.wav"), preload("res://scenes/World/ChildhoodStages/BodhiRoom.tscn")],
	["possession", preload("res://Audio/BGM/Childhood/紧张战斗.wav"), null],
	["aftermath", preload("res://Audio/BGM/Childhood/温柔2.mp3"), null],
]

@export_range(1.0, 1.6, 0.05) var actor_scale_multiplier := 1.3

@onready var _cast: Node2D = $Center/Set
@onready var _balloon: DialogueManagerExampleBalloon = $StoryChat
@onready var _music: AudioStreamPlayer = $Music
@onready var _fade: ColorRect = $Fade
@onready var _time_card: Label = $Fade/TimeCard

var _tree: SceneTree
var _old_cast: Dictionary
var _old_pause: bool
var _old_block: bool
var _world_music: AudioStreamPlayer
var _old_music_pause: bool
var _active := false


func _ready() -> void:
	_tree = get_tree()
	_old_pause = _tree.paused
	_old_block = GameData.ui_blocked
	_old_cast = StoryDirector.actor_overrides
	_world_music = get_parent().get_node_or_null("BGM") as AudioStreamPlayer
	if _world_music:
		_old_music_pause = _world_music.stream_paused
		_world_music.stream_paused = true
	_active = true
	_fade.color.a = 1.0
	GameData.ui_blocked = true
	_tree.paused = true
	_bind_cast()
	_music.finished.connect(_music.play)
	_play.call_deferred()


func _bind_cast() -> void:
	var cast := {}
	for actor in _cast.get_children():
		if actor is NpcNode:
			actor.scale *= actor_scale_multiplier
			cast[actor.npc_name] = actor
	StoryDirector.actor_overrides = cast


func _cut_to_stage(stage: PackedScene) -> void:
	await create_tween().tween_property(_fade, "color:a", 1.0, 0.3).finished
	_cast.hide()
	if _cast.get_parent() == $FramedStages:
		_cast.queue_free()
	if stage != null:
		_cast = stage.instantiate()
		$FramedStages.add_child(_cast)
		_bind_cast()
	else:
		StoryDirector.actor_overrides = {}
	await create_tween().tween_property(_fade, "color:a", 0.0, 0.35).finished


func _play() -> void:
	var manager = Engine.get_singleton("DialogueManager")
	for part in PARTS:
		if part[2] != null or part[0] == "aftermath":
			await _cut_to_stage(part[2])
		_music.stream = part[1]
		_music.play()
		if part[0] == "start":
			var volume := _music.volume_db
			_music.volume_db = -32.0
			var opening := create_tween().set_parallel()
			opening.tween_property(_fade, "color:a", 0.0, 0.55)
			opening.tween_property(_music, "volume_db", volume, 0.55)
			await opening.finished
		_balloon.start.call_deferred(DIALOGUE, part[0])
		while true:
			var ended = await manager.dialogue_ended
			if ended == DIALOGUE: break
		if not is_inside_tree(): return
	_balloon.hide()
	var close := create_tween().set_parallel()
	close.tween_property(_fade, "color:a", 1.0, 0.6)
	close.tween_property(_music, "volume_db", -40.0, 0.6)
	await close.finished
	_music.stop()
	$Center.hide()
	$Backdrop.hide()
	var world := get_parent()
	var world_ui := world.get_node("UI") as CanvasLayer
	world_ui.hide()
	world.enter_opening_outskirts()
	var outskirts = world.get_current_map_root()
	var player: Node2D = outskirts.get_player_node() if outskirts else null
	if player:
		player.hide()
	_time_card.show()
	var reveal := create_tween()
	reveal.tween_interval(1.3)
	reveal.tween_property(_time_card, "modulate:a", 0.0, 0.25)
	reveal.tween_property(_fade, "color:a", 0.0, 0.55)
	await reveal.finished
	# 出场镜头由玩家确认结束，等待期间主角始终留在画面外。
	$Continue.show()
	$Continue.grab_focus()
	await $Continue.pressed
	if is_instance_valid(player):
		player.show()
	world_ui.show()
	GameData.set_story_flag(SEEN_FLAG)
	GameData.request_auto_save()
	queue_free()


func _exit_tree() -> void:
	if not _active: return
	if is_instance_valid(StoryDirector): StoryDirector.actor_overrides = _old_cast
	if is_instance_valid(GameData): GameData.ui_blocked = _old_block
	if is_instance_valid(_tree): _tree.paused = _old_pause
	if is_instance_valid(_world_music): _world_music.stream_paused = _old_music_pause
