extends Control

@export_group("统计条颜色")
@export var threat_normal := Color("#365b89")
@export var threat_rising := Color("#835914")
@export var threat_high := Color("#9c3339")
@export var damage_color := Color("#355b96")
@export var healing_color := Color("#216451")

func display(member_name: String, amount: int, highest: int, category: String) -> void:
	%NameLabel.text = member_name
	%ValueLabel.text = str(amount)
	%Meter.max_value = maxi(1, highest)
	%Meter.value = amount
	var accent := threat_normal
	match category:
		"red": accent = threat_high
		"yellow": accent = threat_rising
		"damage": accent = damage_color
		"heal": accent = healing_color
	%Meter.modulate = accent
	%ValueLabel.modulate = accent
