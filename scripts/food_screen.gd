extends ColorRect
class_name FoodScreenUI

## Food distribution screen — pick from pool, drop on characters, toggle guard.

signal confirmed

var panel: PanelContainer
var pool_container: GridContainer
var pool_label: Label
var char_zones: Array = []
var confirm_btn: Button
var guard_summary: Label
var drag_preview: PanelContainer

var active := false
var carrying := false
var remaining := 0


func build():
	color = Color(0.06, 0.05, 0.03, 0.96)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_bg_input)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.bubble_style(18, 32))
	panel.custom_minimum_size = Vector2(720, 440)
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(main_vbox)

	# Title
	var title := UITheme.label("DISTRIBUIR COMIDA", 18, UITheme.COL_BONE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle := UITheme.label("Toma comida de la reserva y asignala a cada personaje", 11, UITheme.COL_BONE.darkened(0.2))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# Characters row
	var chars_hbox := HBoxContainer.new()
	chars_hbox.add_theme_constant_override("separation", 16)
	chars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(chars_hbox)

	char_zones.clear()
	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.custom_minimum_size.x = 190
		chars_hbox.add_child(col)

		var fname := UITheme.label(c.char_name.to_upper(), 14, UITheme.COL_BONE)
		fname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(fname)

		var fneed := UITheme.label("Necesita: %d" % c.get_food_need(), 11, UITheme.COL_WARN)
		fneed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(fneed)

		# Drop zone
		var zone := PanelContainer.new()
		var zone_style_normal := StyleBoxFlat.new()
		zone_style_normal.bg_color = Color(1, 1, 1, 0.03)
		zone_style_normal.set_corner_radius_all(12)
		zone_style_normal.border_color = Color(1, 1, 1, 0.08)
		zone_style_normal.set_border_width_all(1)
		zone_style_normal.content_margin_left = 10
		zone_style_normal.content_margin_right = 10
		zone_style_normal.content_margin_top = 10
		zone_style_normal.content_margin_bottom = 10
		zone.add_theme_stylebox_override("panel", zone_style_normal)
		zone.custom_minimum_size = Vector2(170, 90)
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		zone.gui_input.connect(_on_zone_input.bind(i))
		col.add_child(zone)

		var zone_grid := GridContainer.new()
		zone_grid.columns = 5
		zone_grid.add_theme_constant_override("h_separation", UITheme.FOOD_TOKEN_GAP)
		zone_grid.add_theme_constant_override("v_separation", UITheme.FOOD_TOKEN_GAP)
		zone_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(zone_grid)

		var falloc := UITheme.label("0 / %d" % c.get_food_need(), 12, UITheme.COL_BONE)
		falloc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(falloc)

		# Guard toggle button
		var guard_btn := Button.new()
		guard_btn.text = "CUIDAR"
		guard_btn.custom_minimum_size.y = 28
		UITheme.ghost_btn(guard_btn, UITheme.COL_BONE, 11)
		guard_btn.pressed.connect(_on_guard_toggle.bind(i))
		col.add_child(guard_btn)

		# Highlight style (pre-built)
		var zone_style_hover := zone_style_normal.duplicate()
		zone_style_hover.border_color = UITheme.COL_GOLD
		zone_style_hover.set_border_width_all(2)
		zone_style_hover.bg_color = Color(1, 1, 1, 0.06)

		char_zones.append({
			"column": col,
			"name_lbl": fname,
			"need_lbl": fneed,
			"zone": zone,
			"zone_style_normal": zone_style_normal,
			"zone_style_hover": zone_style_hover,
			"zone_grid": zone_grid,
			"alloc_lbl": falloc,
			"guard_btn": guard_btn,
		})

	# Separator
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.06)
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(sep)

	# Pool area
	var pool_vbox := VBoxContainer.new()
	pool_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(pool_vbox)

	pool_label = UITheme.label("RESERVA: 10", 14, UITheme.COL_GOLD)
	pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pool_vbox.add_child(pool_label)

	pool_container = GridContainer.new()
	pool_container.columns = UITheme.FOOD_GRID_COLS
	pool_container.add_theme_constant_override("h_separation", UITheme.FOOD_TOKEN_GAP)
	pool_container.add_theme_constant_override("v_separation", UITheme.FOOD_TOKEN_GAP)
	pool_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pool_vbox.add_child(pool_container)

	# Guard summary
	guard_summary = UITheme.label("", 11, UITheme.COL_GOLD.darkened(0.1))
	guard_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(guard_summary)

	# Confirm button
	confirm_btn = Button.new()
	confirm_btn.text = "CONFIRMAR"
	UITheme.solid_btn(confirm_btn, UITheme.COL_GOLD.darkened(0.2), Color(0.95, 0.92, 0.85))
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(confirm_btn)

	# Drag preview (high z-index so it renders above the panel)
	drag_preview = PanelContainer.new()
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = UITheme.COL_GOLD.lightened(0.3)
	prev_style.set_corner_radius_all(6)
	drag_preview.add_theme_stylebox_override("panel", prev_style)
	drag_preview.custom_minimum_size = Vector2(UITheme.FOOD_TOKEN_SIZE + 4, UITheme.FOOD_TOKEN_SIZE + 4)
	drag_preview.visible = false
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 100
	var prev_lbl := Label.new()
	prev_lbl.text = "●"
	prev_lbl.add_theme_font_size_override("font_size", 12)
	prev_lbl.add_theme_color_override("font_color", Color(0.35, 0.25, 0.12))
	prev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prev_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(prev_lbl)
	add_child(drag_preview)


func _create_food_token(clickable: bool) -> PanelContainer:
	var token := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.COL_GOLD if clickable else UITheme.COL_GOLD.lightened(0.15)
	style.set_corner_radius_all(5)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	token.add_theme_stylebox_override("panel", style)
	token.custom_minimum_size = Vector2(UITheme.FOOD_TOKEN_SIZE, UITheme.FOOD_TOKEN_SIZE)
	if clickable:
		token.mouse_filter = Control.MOUSE_FILTER_STOP
		token.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		token.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_pool_click()
		)
	else:
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := Label.new()
	inner.text = "●"
	inner.add_theme_font_size_override("font_size", 10)
	inner.add_theme_color_override("font_color", Color(0.35, 0.25, 0.12))
	inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.add_child(inner)
	return token


# =============================================
# SHOW / REFRESH / PROCESS
# =============================================

func show_screen():
	active = true
	carrying = false
	drag_preview.visible = false

	remaining = GameManager.food
	GameManager.food_allocated.resize(GameManager.characters.size())
	GameManager.food_allocated.fill(0)
	GameManager.guarding.resize(GameManager.characters.size())
	GameManager.guarding.fill(false)

	refresh()

	visible = true
	modulate.a = 0.0
	panel.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_BACK)
		tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	)


func refresh():
	# Pool
	pool_label.text = "RESERVA: %d" % remaining
	if remaining == 0:
		pool_label.add_theme_color_override("font_color", UITheme.COL_BLOOD)
	else:
		pool_label.add_theme_color_override("font_color", UITheme.COL_GOLD)

	# Rebuild pool tokens
	for child in pool_container.get_children():
		pool_container.remove_child(child)
		child.queue_free()
	for _t in range(remaining):
		pool_container.add_child(_create_food_token(true))

	# Character zones
	for i in range(char_zones.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var z: Dictionary = char_zones[i]
		var allocated: int = GameManager.food_allocated[i] if i < GameManager.food_allocated.size() else 0
		var need: int = c.get_food_need() if c.is_alive() else 0

		# Need label
		if not c.is_alive():
			z["need_lbl"].text = "Muerto"
			z["need_lbl"].add_theme_color_override("font_color", UITheme.COL_BLOOD)
		else:
			var guard_note = " (+2 guardia)" if c.guarded_last_turn else ""
			z["need_lbl"].text = "Necesita: %d%s" % [need, guard_note]
			if allocated >= need:
				z["need_lbl"].add_theme_color_override("font_color", UITheme.COL_MOSS)
			else:
				z["need_lbl"].add_theme_color_override("font_color", UITheme.COL_WARN)

		# Allocation label
		z["alloc_lbl"].text = "%d / %d" % [allocated, need]
		if not c.is_alive():
			z["alloc_lbl"].add_theme_color_override("font_color", UITheme.COL_BONE.darkened(0.3))
		elif allocated >= need:
			z["alloc_lbl"].add_theme_color_override("font_color", UITheme.COL_MOSS)
		elif allocated > 0:
			z["alloc_lbl"].add_theme_color_override("font_color", UITheme.COL_WARN)
		else:
			z["alloc_lbl"].add_theme_color_override("font_color", UITheme.COL_BLOOD)

		# Rebuild allocated tokens
		var grid: GridContainer = z["zone_grid"]
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		for _t in range(allocated):
			grid.add_child(_create_food_token(false))

		# Zone interactivity
		if not c.is_alive():
			z["zone"].mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			z["zone"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_refresh_guard_ui()


func process_tick():
	if not active:
		return
	# Drag preview follows mouse
	if carrying and drag_preview.visible:
		var mp := get_viewport().get_mouse_position()
		drag_preview.position = mp - Vector2(UITheme.FOOD_TOKEN_SIZE / 2 + 2, UITheme.FOOD_TOKEN_SIZE / 2 + 2)
	# Highlight zones
	_process_zone_highlights()


func cancel_carry():
	carrying = false
	drag_preview.visible = false


func reset():
	active = false
	carrying = false
	drag_preview.visible = false
	visible = false


# =============================================
# INTERNAL CALLBACKS
# =============================================

func _process_zone_highlights():
	var mp := get_viewport().get_mouse_position()
	for i in range(char_zones.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var z: Dictionary = char_zones[i]
		var zone: PanelContainer = z["zone"]
		var is_hover := carrying and c.is_alive() and zone.get_global_rect().has_point(mp)
		if is_hover:
			zone.add_theme_stylebox_override("panel", z["zone_style_hover"])
		else:
			zone.add_theme_stylebox_override("panel", z["zone_style_normal"])


func _on_pool_click():
	if not carrying and remaining > 0:
		carrying = true
		drag_preview.visible = true


func _on_zone_input(event: InputEvent, char_idx: int):
	var c: GameManager.Character = GameManager.characters[char_idx]
	if not c.is_alive():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if carrying:
			GameManager.food_allocated[char_idx] += 1
			remaining -= 1
			carrying = false
			drag_preview.visible = false
			refresh()
		else:
			if GameManager.food_allocated[char_idx] > 0:
				GameManager.food_allocated[char_idx] -= 1
				remaining += 1
				refresh()


func _on_bg_input(event: InputEvent):
	if carrying and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		carrying = false
		drag_preview.visible = false


func _on_guard_toggle(char_idx: int):
	var c: GameManager.Character = GameManager.characters[char_idx]
	if not c.is_alive():
		return
	GameManager.guarding[char_idx] = not GameManager.guarding[char_idx]
	_refresh_guard_ui()


func _refresh_guard_ui():
	var guard_count := 0
	var total_reduction := GameManager.get_guard_reduction_preview()
	for i in range(char_zones.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var z: Dictionary = char_zones[i]
		var btn: Button = z["guard_btn"]
		var is_guarding = GameManager.guarding[i] if i < GameManager.guarding.size() else false
		if not c.is_alive():
			btn.text = "—"
			btn.disabled = true
		elif is_guarding:
			guard_count += 1
			btn.text = "CUIDANDO"
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = UITheme.COL_GOLD.darkened(0.3)
			active_style.set_corner_radius_all(8)
			active_style.content_margin_left = 16
			active_style.content_margin_right = 16
			active_style.content_margin_top = 6
			active_style.content_margin_bottom = 6
			btn.add_theme_stylebox_override("normal", active_style)
			var h := active_style.duplicate()
			h.bg_color = UITheme.COL_GOLD.darkened(0.2)
			btn.add_theme_stylebox_override("hover", h)
			btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		else:
			btn.text = "CUIDAR"
			UITheme.ghost_btn(btn, UITheme.COL_BONE, 11)

	if guard_count > 0:
		var pct := int(total_reduction * 100)
		guard_summary.text = "Guardia: %d (-%d%% riesgo) — +2 hambre manana c/u" % [guard_count, pct]
		guard_summary.add_theme_color_override("font_color", UITheme.COL_GOLD.darkened(0.1))
	else:
		guard_summary.text = "Sin guardia — riesgo nocturno: %d%%" % int(GameManager.BASE_EVENT_CHANCE * 100)
		guard_summary.add_theme_color_override("font_color", UITheme.COL_BLOOD.lightened(0.2))


func _on_confirm():
	active = false
	carrying = false
	drag_preview.visible = false

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		confirmed.emit()
	)
