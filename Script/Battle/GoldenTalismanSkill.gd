extends RefCounted
## 复用剧情金符特效；战斗只负责施法姿态与命中结算，不经过剧情输入锁。
const EffectScene = preload("res://scenes/Effects/GoldenTalismanBurst.tscn")
const Settings = preload("res://Resources/StoryEffects/GoldenTalismanBurst.tres")

static func execute(battle, caster: BattleCharacter, target: BattleCharacter) -> void:
	if not is_instance_valid(target) or target.is_dead: return
	var source := caster.get_parent() as Node2D
	var victim := target.get_parent() as Node2D
	if source == null or victim == null: return
	var result := SkillManager.execute(caster, target, "金符齐射")
	if not result.success:
		battle._push_log(result.log_text, "system")
		return
	var settings = Settings.duplicate()
	settings.batch_count = 4
	# 战斗在 CanvasLayer 上，以战斗画布震动代替地图摄像机震动。
	settings.shake_enabled = false
	var effect = EffectScene.instantiate()
	source.get_parent().add_child(effect)
	var animation := source.get_node_or_null("WASAnimationPlayer") as WASAnimationPlayer
	var old_frame_time: float = animation.frame_time if animation else 0.1
	if animation:
		animation.frame_time = maxf(settings.charge_duration, 0.1)
		animation.play(settings.charge_animation, false)
	effect.batch_released.connect(func(_batch: int):
		if is_instance_valid(animation) and animation.is_inside_tree():
			animation.frame_time = old_frame_time
			animation.play(settings.release_animation, false)
	)
	var total_damage := maxi(1, int(result.damage_list[0] * caster.metamorphosis_mod))
	effect.batch_hit.connect(func(batch: int):
		if not is_instance_valid(battle) or not battle.is_inside_tree(): return
		if not is_instance_valid(target) or target.is_dead: return
		# 整除余数分配到前几批，四次命中之和严格等于技能计算的总伤害。
		var damage := total_damage / 4 + (1 if batch < total_damage % 4 else 0)
		var actual: int = battle.apply_damage(caster, target, damage, {"is_magic": true})
		target.sync_visual()
		battle.damage_floated.emit(target, actual, "crit" if result.is_crit else "magic")
		if is_instance_valid(victim) and not target.is_dead:
			if victim.has_method("play_hit_once"): victim.play_hit_once()
			if victim.has_method("play_hit_flash"): victim.play_hit_flash()
		var canvas := battle.get_parent() as CanvasLayer
		if canvas != null: BattleTransition.shake_canvas(canvas, settings.release_shake * 0.4, settings.burst_shake_duration)
	)
	var success: bool = await effect.play(source, victim, settings)
	if is_instance_valid(animation):
		animation.frame_time = old_frame_time
		if animation.is_inside_tree(): animation.play("idle")
	if is_instance_valid(effect): effect.queue_free()
	if not is_instance_valid(battle) or not battle.is_inside_tree(): return
	if success:
		battle._resolve_skill_effects(result, caster, target)
		battle._push_log(result.log_text, "player_action")
	if is_instance_valid(victim) and not target.is_dead and victim.has_method("play_idle"):
		victim.play_idle()
