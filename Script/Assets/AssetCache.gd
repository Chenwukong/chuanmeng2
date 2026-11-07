extends RefCounted
## 全项目共享的有界 LRU；使用中的资源由播放器/控件继续持有，不会被强制销毁。
const MAX_BYTES := 128 * 1024 * 1024
const MAX_ENTRIES := 256
static var _entries: Dictionary = {}
static var _bytes: int = 0
static var _weak: Dictionary = {}

static func has(key: String) -> bool:
	return _entries.has(key)

static func fetch(key: String, fallback = null):
	if not _entries.has(key): return fallback
	var entry: Dictionary = _entries[key]
	_entries.erase(key)
	_entries[key] = entry
	return entry.value

static func store(key: String, value, bytes: int = 0) -> void:
	if _entries.has(key):
		_bytes -= int(_entries[key].bytes)
		_entries.erase(key)
	_entries[key] = {"value": value, "bytes": maxi(0, bytes)}
	_bytes += maxi(0, bytes)
	while _entries.size() > MAX_ENTRIES or (_bytes > MAX_BYTES and _entries.size() > 1):
		var oldest: String = _entries.keys()[0]
		_bytes -= int(_entries[oldest].bytes)
		_entries.erase(oldest)

static func weak_fetch(key: String):
	var reference: WeakRef = _weak.get(key)
	return reference.get_ref() if reference else null

static func weak_store(key: String, value: RefCounted) -> void:
	for old_key in _weak.keys():
		if _weak[old_key].get_ref() == null: _weak.erase(old_key)
	_weak[key] = weakref(value)

static func clear() -> void:
	_entries.clear()
	_weak.clear()
	_bytes = 0

static func diagnostics() -> Dictionary:
	return {"entries": _entries.size(), "bytes": _bytes, "weak_entries": _weak.size()}
