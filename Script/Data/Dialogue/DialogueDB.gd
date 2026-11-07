extends RefCounted

## entries 按顺序播放，正常结束后自动推进；once=false 停留在当前段。
## locked=true 锁住当前段；通过 GameData.unlock_npc_dialogue 解锁，不跳段。
## requires_flags 继续兼容需要额外条件的旧配置。
## 每段可选 waiting：该段结束后，下一段未解锁或已无下一段时播放。
## 不写 waiting 时重复上一段；下一段已解锁时直接播放下一段。
const NPC_DIALOGUES = {
	"菩提祖师": {
		"file": "res://Dialogue/bodhi.dialogue",
		"entries": [{"id": "山巅相见", "title": "菩提初见", "type": "story"}],
	},
	"方寸山_符材商人": {
		"file": "res://Dialogue/fangcun_merchant.dialogue",
		"entries": [{"id": "材料与制符", "title": "商人招呼", "type": "story", "once": false}],
	},
	"方寸山_守关20": {
		"file": "res://Dialogue/fangcun_guards.dialogue",
		"entries": [{"id": "守关挑战", "title": "黑熊拦路", "type": "story", "once": false}],
	},
	"方寸山_守关60": {
		"file": "res://Dialogue/fangcun_guards.dialogue",
		"entries": [{"id": "守关挑战", "title": "毒云龟拦路", "type": "story", "once": false}],
	},
	"方寸山_守关100": {
		"file": "res://Dialogue/fangcun_guards.dialogue",
		"entries": [{"id": "守关挑战", "title": "赤焰兽拦路", "type": "story", "once": false}],
	},
	"方寸山_机关人": {
		"file": "res://Dialogue/chapter0.dialogue",
		"entries": [
			{"id": "初次见面", "title": "start", "type": "story", "waiting": {"title": "机关人_挑战询问"}},
			{"id": "通过试炼", "title": "试炼完成", "locked": true, "once": false},
		],
	},
	"镖头": {
		"file": "res://Dialogue/chapter1.dialogue",
		"entries": [
			{"id": "初次见面", "title": "start", "type": "story"},
			{"id": "日常交谈", "title": "镖头_日常交谈", "once": false},
		],
	},
	"凌风": {
		"file": "res://Dialogue/chapter0.dialogue",
		"entries": [{"id": "队友交谈", "title": "剑侠客", "type": "team", "once": false}],
	},
}

const LEGACY_IDS = {"机关人": "方寸山_机关人", "fangcun_mech": "方寸山_机关人", "biaotou": "镖头", "lingfeng": "凌风"}
const FLAG_ALIASES = {"mech.defeated": "机关人_试炼通过"}
const LEGACY_PROGRESS_FLAGS = {"机关人": "mech.introduced", "镖头": "biaotou.introduced"}

static func canonical_id(id: String) -> String:
	return str(LEGACY_IDS.get(id, id))

static func create_database() -> Dictionary:
	return NPC_DIALOGUES.duplicate(true)

static func conditions_met(entry: Dictionary, flags: Dictionary) -> bool:
	for flag in entry.get("requires_flags", []):
		if not flags.get(flag, false): return false
	return true

static func find_entry(database: Dictionary, event_id: String, entry_id: String) -> Dictionary:
	for entry in database.get(canonical_id(event_id), {}).get("entries", []):
		if entry.get("id", "") == entry_id: return entry
	return {}

static func is_locked(database: Dictionary, event_id: String, entry_id: String, locks: Dictionary) -> bool:
	var id := canonical_id(event_id)
	var entry := find_entry(database, id, entry_id)
	if entry.is_empty(): return true
	return bool(locks.get(id, {}).get(entry_id, entry.get("locked", false)))

static func resolve(database: Dictionary, event_id: String, flags: Dictionary, progress: Dictionary = {}, locks: Dictionary = {}, check_unlock: bool = true) -> Dictionary:
	var id := canonical_id(event_id)
	var config: Dictionary = database.get(id, {})
	var entries: Array = config.get("entries", [])
	if entries.is_empty(): return {}
	var index := clampi(int(progress.get(id, 0)), 0, entries.size())
	var entry: Dictionary = {}
	var advance := false
	var pending := index < entries.size() and (not check_unlock or (not is_locked(database, id, str(entries[index].get("id", "")), locks) and conditions_met(entries[index], flags)))
	if pending:
		entry = entries[index].duplicate(true)
		advance = bool(entry.get("once", true))
	else:
		var previous: Dictionary = entries[index - 1] if index > 0 else {}
		if previous.has("waiting"):
			entry = previous.waiting.duplicate(true)
			entry["file"] = entry.get("file", previous.get("file", config.get("file", "")))
		elif config.has("waiting") and index < entries.size():
			# 兼容早期 NPC 级等待配置，优先使用当前段自己的 waiting。
			entry = config.waiting.duplicate(true)
		elif index > 0:
			entry = previous.duplicate(true)
	if entry.is_empty(): return {}
	entry["file"] = entry.get("file", config.get("file", ""))
	entry["type"] = entry.get("type", "normal")
	entry["event_id"] = id
	entry["index"] = index
	entry["advance"] = advance
	entry["is_waiting"] = not pending
	entry["check_unlock"] = check_unlock
	return entry
