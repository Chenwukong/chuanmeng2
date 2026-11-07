extends ItemList

func keyboard_move(direction: Vector2) -> void:
	if item_count == 0 or direction.y == 0: return
	var selected := get_selected_items()
	var index := int(selected[0]) if not selected.is_empty() else 0
	index = clampi(index + int(direction.y), 0, item_count - 1)
	select(index)
	ensure_current_is_visible()
	item_selected.emit(index)

func keyboard_activate() -> void:
	var selected := get_selected_items()
	if not selected.is_empty(): item_activated.emit(selected[0])
