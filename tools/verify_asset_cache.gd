extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var cache = load("res://Script/Assets/AssetCache.gd")
	var loader = load("res://Script/Assets/AssetLoader.gd")
	cache.clear()
	var retained := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	for i in 300: cache.store("test:%d" % i, retained, 1024 * 1024)
	assert(cache.diagnostics().bytes <= cache.MAX_BYTES)
	assert(cache.diagnostics().entries <= cache.MAX_ENTRIES)
	assert(not cache.has("test:0") and cache.has("test:299"))
	assert(retained.get_width() == 2)
	cache.clear()
	var a = loader.tcp_texture("res://TCP/矿石/黑曜石.tcp")
	var b = loader.tcp_texture("res://TCP/矿石/黑曜石.tcp")
	assert(a != null and a == b)
	var icon := TextureRect.new()
	root.add_child(icon)
	loader.request_tcp(icon, "res://TCP/矿石/黄金.tcp")
	loader.request_tcp(icon, "")
	await process_frame
	await process_frame
	assert(icon.texture == null)
	loader.request_tcp(icon, "res://TCP/矿石/黄金.tcp")
	for i in 8: await process_frame
	assert(icon.texture != null)
	icon.queue_free()
	cache.clear()
	assert(a.get_width() > 0)
	print("ASSET CACHE: PASS (LRU, budget, shared TCP, stale requests, live references)")
	quit()
