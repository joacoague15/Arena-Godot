extends Control

## Sobrevivir la Pampa - Main UI
## Minimalist gothic. Dirt white canvas. Characters ARE the interface.
## Everything hidden until hover/click reveals dark floating bubbles.

# --- Palette: dirt white canvas + dark gothic overlays ---
const COL_BG := Color(0.82, 0.78, 0.72)        # Dirty parchment white
const COL_INK := Color(0.12, 0.10, 0.08)        # Near-black ink
const COL_INK_SOFT := Color(0.22, 0.19, 0.15)   # Softer ink
const COL_BLOOD := Color(0.55, 0.12, 0.10)      # Dark blood red
const COL_BONE := Color(0.65, 0.60, 0.52)       # Muted bone
const COL_GOLD := Color(0.62, 0.50, 0.28)       # Tarnished gold
const COL_MOSS := Color(0.28, 0.42, 0.25)       # Dark moss green
const COL_DUSK := Color(0.35, 0.30, 0.45)       # Twilight purple
const COL_BUBBLE := Color(0.08, 0.07, 0.05, 0.92)  # Bubble bg
const COL_WARN := Color(0.70, 0.55, 0.15)       # Warning amber

# --- Sprite config ---
const SPRITE_FOLDERS := {
	"Caudillo": "res://sprites/caudillo/idle/",
	"Vigia": "res://sprites/vigia/idle/",
	"Curandera": "res://sprites/healer/idle/",
}
const SPRITE_FPS := 8.0
const SPRITE_FRAME_COUNT := 8

# --- UI Refs ---
var day_label: Label
var food_label: Label
var resolve_btn: Button
var game_layer: Control
var night_screen: ColorRect
var night_log: RichTextLabel
var night_continue_btn: Button
var night_panel: PanelContainer
var overlay: PanelContainer
var overlay_label: Label
var char_panels: Array = []

# --- State ---
var sprite_time := 0.0
var selected_char := -1
var is_night_screen := false
var actions_confirmed: Array = []


# =============================================
# HELPERS
# =============================================

func _label(text: String, size: int = 15, color: Color = COL_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _bubble_style(radius: int = 14, pad: int = 14) -> StyleBoxFlat:
	## Dark floating bubble - the core visual element
	var s := StyleBoxFlat.new()
	s.bg_color = COL_BUBBLE
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	# Subtle shadow feel via border
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	return s


func _ghost_btn(btn: Button, fg: Color, size: int = 14):
	## Minimal ghost-style button (transparent bg, text only, hover darkens)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", fg)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0)
	empty.content_margin_left = 16
	empty.content_margin_right = 16
	empty.content_margin_top = 10
	empty.content_margin_bottom = 10
	empty.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", empty)
	var h := empty.duplicate()
	h.bg_color = Color(1, 1, 1, 0.08)
	btn.add_theme_stylebox_override("hover", h)
	var p := empty.duplicate()
	p.bg_color = Color(1, 1, 1, 0.04)
	btn.add_theme_stylebox_override("pressed", p)


func _solid_btn(btn: Button, bg: Color, fg: Color):
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", fg)
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = bg.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)
	var p := s.duplicate()
	p.bg_color = bg.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", p)
	# Disabled style
	var d := s.duplicate()
	d.bg_color = bg.darkened(0.3)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_disabled_color", fg.darkened(0.4))


func _load_sprite_frames(char_name: String) -> Array:
	var frames: Array = []
	var folder: String = SPRITE_FOLDERS.get(char_name, "")
	if folder == "":
		return frames
	for i in range(SPRITE_FRAME_COUNT):
		var path := "%sframe_%02d.png" % [folder, i]
		if ResourceLoader.exists(path):
			frames.append(load(path))
	return frames


# =============================================
# BUILD
# =============================================

func _ready():
	# Parchment background — the entire canvas
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Game layer
	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)

	# --- Top HUD: floating text, no boxes ---
	_build_hud()

	# --- Characters: the entire center ---
	_build_characters()

	# --- Bottom resolve button ---
	_build_bottom_bar()

	# Night + End overlays
	_build_night_screen()
	_build_overlay()

	GameManager.turn_resolved.connect(_on_turn_resolved)
	GameManager.game_ended.connect(_on_game_ended)

	actions_confirmed.resize(GameManager.characters.size())
	actions_confirmed.fill(false)

	_update_ui()
	_update_resolve_btn()


func _process(delta: float):
	sprite_time += delta
	var cycle_length := (SPRITE_FRAME_COUNT * 2) - 2
	if cycle_length <= 0:
		return
	var pos := int(sprite_time * SPRITE_FPS) % cycle_length
	var frame_index: int
	if pos < SPRITE_FRAME_COUNT:
		frame_index = pos
	else:
		frame_index = cycle_length - pos

	for p in char_panels:
		var frames: Array = p["sprite_frames"]
		var tex_rect: TextureRect = p["sprite_rect"]
		if frames.size() > 0:
			tex_rect.texture = frames[frame_index % frames.size()]

	_process_hover(delta)


func _unhandled_input(event: InputEvent):
	if is_night_screen:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_char >= 0:
			var p: Dictionary = char_panels[selected_char]
			var sprite_area: Control = p["sprite_rect"]
			var actions_panel: Control = p["actions_panel"]
			if not sprite_area.get_global_rect().has_point(event.position) and not actions_panel.get_global_rect().has_point(event.position):
				_close_actions(selected_char)


# --- HUD: just floating text at the top ---
func _build_hud():
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox.offset_left = 30
	hbox.offset_right = -30
	hbox.offset_top = 16
	hbox.offset_bottom = 50
	hbox.add_theme_constant_override("separation", 20)
	game_layer.add_child(hbox)

	day_label = _label("NOCHE 1", 13, COL_INK_SOFT)
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(day_label)

	food_label = _label("COMIDA: 10", 13, COL_INK_SOFT)
	food_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(food_label)


# --- Characters: full height, centered, no containers ---
func _build_characters():
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_top = 50
	hbox.offset_bottom = -60
	hbox.offset_left = 20
	hbox.offset_right = -20
	hbox.add_theme_constant_override("separation", 0)
	game_layer.add_child(hbox)

	for i in range(GameManager.characters.size()):
		var data := _build_char(hbox, i)
		char_panels.append(data)


func _build_char(parent: HBoxContainer, idx: int) -> Dictionary:
	var c: GameManager.Character = GameManager.characters[idx]

	# Each character is just a TextureRect that fills its third of the screen
	var container := Control.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(container)

	# Sprite
	var sprite_rect := TextureRect.new()
	sprite_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sprite_rect)

	var frames := _load_sprite_frames(c.char_name)
	if frames.size() > 0:
		sprite_rect.texture = frames[0]

	# Dead/weak overlay
	var sprite_overlay := ColorRect.new()
	sprite_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_overlay.color = Color(0, 0, 0, 0)
	sprite_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sprite_overlay)

	# Dead label
	var dead_lbl := _label("", 32, COL_BLOOD)
	dead_lbl.set_anchors_preset(Control.PRESET_CENTER)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_lbl.visible = false
	container.add_child(dead_lbl)

	# --- Name label (always visible, small, at bottom center) ---
	var name_lbl := _label(c.char_name.to_upper(), 11, COL_INK_SOFT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -28
	name_lbl.offset_bottom = -12
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_lbl)

	# --- Hover info bubble (floating, dark, appears on hover) ---
	var info_bubble := PanelContainer.new()
	info_bubble.add_theme_stylebox_override("panel", _bubble_style(12, 12))
	info_bubble.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info_bubble.offset_top = -120
	info_bubble.offset_bottom = -35
	info_bubble.offset_left = -90
	info_bubble.offset_right = 90
	info_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bubble.modulate.a = 0.0
	container.add_child(info_bubble)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bubble.add_child(info_vbox)

	# Stats inside bubble
	var food_txt := "%d" % c.food_consumption
	var hunt_txt := "+%d" % c.hunt_yield if c.hunt_yield > 0 else "—"
	var guard_txt := "-%d%%" % int(c.guard_reduction * 100) if c.guard_reduction > 0 else "—"

	var food_lbl := _label("Come: %s" % food_txt, 11, COL_BONE)
	food_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(food_lbl)

	var hunt_lbl := _label("Caza: %s" % hunt_txt, 11, COL_BONE)
	hunt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(hunt_lbl)

	var guard_lbl := _label("Guardia: %s" % guard_txt, 11, COL_BONE)
	guard_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(guard_lbl)

	# Separator
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size.y = 1
	info_vbox.add_child(sep)

	var state_lbl := _label("Normal", 11, COL_MOSS)
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(state_lbl)

	var sleep_lbl := _label("Descansado", 10, COL_BONE)
	sleep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(sleep_lbl)

	var need_lbl := _label("Necesita: %d" % c.get_food_need(), 10, COL_WARN)
	need_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(need_lbl)

	# --- Action indicator (small, under the name) ---
	var action_indicator := _label("—", 10, COL_BONE)
	action_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_indicator.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	action_indicator.offset_top = -14
	action_indicator.offset_bottom = 0
	action_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(action_indicator)

	c.assigned_action = -1
	action_indicator.text = "sin asignar"
	action_indicator.add_theme_color_override("font_color", COL_BONE.darkened(0.2))

	# --- Actions bubble (click to reveal) ---
	var actions_panel := PanelContainer.new()
	actions_panel.add_theme_stylebox_override("panel", _bubble_style(14, 10))
	actions_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	actions_panel.offset_top = -200
	actions_panel.offset_bottom = -130
	actions_panel.offset_left = -80
	actions_panel.offset_right = 80
	actions_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	actions_panel.visible = false
	actions_panel.modulate.a = 0.0
	container.add_child(actions_panel)

	var actions_vbox := VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 2)
	actions_panel.add_child(actions_vbox)

	var action_buttons: Array = []
	_build_action_buttons(actions_vbox, action_buttons, c, idx)

	# Connect signals
	container.gui_input.connect(_on_char_gui_input.bind(idx))
	container.mouse_entered.connect(_on_char_hover_enter.bind(idx))
	container.mouse_exited.connect(_on_char_hover_exit.bind(idx))

	return {
		"container": container,
		"sprite_rect": sprite_rect,
		"sprite_frames": frames,
		"sprite_overlay": sprite_overlay,
		"dead_lbl": dead_lbl,
		"name_lbl": name_lbl,
		"info_bubble": info_bubble,
		"info_alpha": 0.0,
		"state_lbl": state_lbl,
		"sleep_lbl": sleep_lbl,
		"need_lbl": need_lbl,
		"food_lbl": food_lbl,
		"action_indicator": action_indicator,
		"actions_panel": actions_panel,
		"actions_vbox": actions_vbox,
		"action_buttons": action_buttons,
		"hover_amount": 0.0,
		"is_hovered": false,
		"is_selected": false,
	}


func _build_action_buttons(parent: VBoxContainer, buttons_array: Array, c: GameManager.Character, idx: int):
	if c.can_hunt():
		var btn := Button.new()
		btn.text = "CAZAR"
		_ghost_btn(btn, COL_MOSS)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.CAZAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CAZAR})

	if c.can_guard():
		var btn := Button.new()
		btn.text = "CUIDAR"
		_ghost_btn(btn, COL_GOLD)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.CUIDAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CUIDAR})

	var btn_sleep := Button.new()
	btn_sleep.text = "DORMIR"
	_ghost_btn(btn_sleep, COL_DUSK.lightened(0.3))
	btn_sleep.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.DORMIR))
	parent.add_child(btn_sleep)
	buttons_array.append({"btn": btn_sleep, "action": GameManager.Action.DORMIR})


func _build_bottom_bar():
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hbox.offset_top = -55
	hbox.offset_left = 30
	hbox.offset_right = -30
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	game_layer.add_child(hbox)

	resolve_btn = Button.new()
	resolve_btn.text = "TERMINAR TURNO"
	_solid_btn(resolve_btn, COL_INK, COL_BG)
	resolve_btn.pressed.connect(_on_resolve)
	hbox.add_child(resolve_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Reiniciar"
	_ghost_btn(restart_btn, COL_INK_SOFT, 12)
	restart_btn.pressed.connect(_on_restart)
	hbox.add_child(restart_btn)


func _action_display_name(action_id: int, _c: GameManager.Character) -> String:
	match action_id:
		GameManager.Action.CAZAR: return "cazar"
		GameManager.Action.CUIDAR: return "cuidar"
		GameManager.Action.DORMIR: return "dormir"
	return "?"


func _all_actions_confirmed() -> bool:
	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		if c.is_alive() and not actions_confirmed[i]:
			return false
	return true


func _update_resolve_btn():
	if GameManager.game_over or GameManager.game_won:
		resolve_btn.disabled = true
		return
	if _all_actions_confirmed():
		resolve_btn.disabled = false
		resolve_btn.text = "TERMINAR TURNO"
	else:
		resolve_btn.disabled = true
		var pending := 0
		for i in range(GameManager.characters.size()):
			if GameManager.characters[i].is_alive() and not actions_confirmed[i]:
				pending += 1
		resolve_btn.text = "ASIGNA ACCIONES  (%d)" % pending


# =============================================
# HOVER & CLICK
# =============================================

func _on_char_hover_enter(idx: int):
	if GameManager.characters[idx].is_alive() and not is_night_screen:
		char_panels[idx]["is_hovered"] = true

func _on_char_hover_exit(idx: int):
	char_panels[idx]["is_hovered"] = false


func _process_hover(delta: float):
	for i in range(char_panels.size()):
		var p: Dictionary = char_panels[i]
		var alive = GameManager.characters[i].is_alive()
		var target := 0.0
		if (p["is_hovered"] or p["is_selected"]) and alive:
			target = 1.0

		p["hover_amount"] = lerpf(p["hover_amount"], target, 0.12)
		p["info_alpha"] = lerpf(p["info_alpha"], target, 0.1)

		# Info bubble fade
		var info_bubble: PanelContainer = p["info_bubble"]
		info_bubble.modulate.a = p["info_alpha"]
		# Slight upward float on hover
		info_bubble.offset_bottom = -35 - p["info_alpha"] * 5

		# Subtle scale on sprite
		var sprite: TextureRect = p["sprite_rect"]
		var s := lerpf(1.0, 1.015, p["hover_amount"])
		sprite.pivot_offset = sprite.size / 2.0
		sprite.scale = Vector2(s, s)


func _on_char_gui_input(event: InputEvent, idx: int):
	if is_night_screen:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c: GameManager.Character = GameManager.characters[idx]
		if not c.is_alive() or GameManager.game_over or GameManager.game_won:
			return

		if selected_char == idx:
			_close_actions(idx)
		else:
			if selected_char >= 0:
				_close_actions(selected_char)
			_open_actions(idx)

		get_viewport().set_input_as_handled()


func _open_actions(idx: int):
	selected_char = idx
	char_panels[idx]["is_selected"] = true
	var p: Dictionary = char_panels[idx]
	var panel: PanelContainer = p["actions_panel"]
	panel.visible = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2).from(0.0)
	tween.tween_property(panel, "offset_top", -200, 0.25).from(-180)


func _close_actions(idx: int):
	if idx < 0 or idx >= char_panels.size():
		return
	char_panels[idx]["is_selected"] = false
	var p: Dictionary = char_panels[idx]
	var panel: PanelContainer = p["actions_panel"]

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func(): panel.visible = false)

	if selected_char == idx:
		selected_char = -1


func _on_action_btn_pressed(char_idx: int, action_id: int):
	var c: GameManager.Character = GameManager.characters[char_idx]
	c.assigned_action = action_id
	actions_confirmed[char_idx] = true

	var p: Dictionary = char_panels[char_idx]
	var indicator: Label = p["action_indicator"]
	indicator.text = _action_display_name(action_id, c)
	indicator.add_theme_color_override("font_color", COL_INK_SOFT)

	# Close menu
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(_close_actions.bind(char_idx))

	_update_resolve_btn()


# =============================================
# NIGHT SCREEN
# =============================================

func _build_night_screen():
	night_screen = ColorRect.new()
	night_screen.color = Color(0.04, 0.03, 0.02)
	night_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_screen.visible = false
	night_screen.modulate.a = 0.0
	night_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(night_screen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_screen.add_child(center)

	night_panel = PanelContainer.new()
	night_panel.add_theme_stylebox_override("panel", _bubble_style(16, 36))
	night_panel.custom_minimum_size = Vector2(500, 280)
	center.add_child(night_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	night_panel.add_child(vbox)

	night_log = RichTextLabel.new()
	night_log.bbcode_enabled = true
	night_log.scroll_following = true
	night_log.fit_content = true
	night_log.add_theme_color_override("default_color", COL_BONE)
	night_log.add_theme_font_size_override("normal_font_size", 14)
	night_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_log.custom_minimum_size.y = 160
	vbox.add_child(night_log)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.06)
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

	night_continue_btn = Button.new()
	night_continue_btn.text = "COMENZAR SIGUIENTE DIA"
	_solid_btn(night_continue_btn, COL_GOLD.darkened(0.2), Color(0.95, 0.92, 0.85))
	night_continue_btn.pressed.connect(_on_night_continue)
	night_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(night_continue_btn)


func _show_night_screen():
	is_night_screen = true
	night_screen.visible = true
	night_screen.modulate.a = 0.0
	_populate_night_log()
	night_panel.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(night_screen, "modulate:a", 1.0, 0.6)
	tween.tween_interval(0.15)
	tween.tween_callback(_animate_night_panel_in)


func _animate_night_panel_in():
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(night_panel, "modulate:a", 1.0, 0.35)


func _populate_night_log():
	night_log.clear()
	for msg in GameManager.log_messages:
		if msg == "":
			night_log.append_text("\n")
			continue
		var colored := msg
		if msg.begins_with("ROBO") or msg.begins_with("ATAQUE"):
			colored = "[color=#994433]%s[/color]" % msg
		elif "muere" in msg:
			colored = "[color=#883322][b]%s[/b][/color]" % msg
		elif "debilita" in msg:
			colored = "[color=#997744]%s[/color]" % msg
		elif "Noche sin incidentes" in msg:
			colored = "[color=#557744]%s[/color]" % msg
		elif msg.begins_with("---"):
			colored = "[color=#9e8052][b]%s[/b][/color]" % msg
		elif "Comida total" in msg or "Todos comen" in msg:
			colored = "[color=#9e8852]%s[/color]" % msg
		elif "insuficiente" in msg:
			colored = "[color=#994433]%s[/color]" % msg
		night_log.append_text(colored + "\n")

	if GameManager.game_won or GameManager.game_over:
		night_continue_btn.text = "VER RESULTADO"
	else:
		night_continue_btn.text = "COMENZAR SIGUIENTE DIA"


func _on_night_continue():
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(night_panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(night_screen, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_on_night_screen_hidden)


func _on_night_screen_hidden():
	night_screen.visible = false
	is_night_screen = false

	if GameManager.game_won or GameManager.game_over:
		_show_end_overlay()
	else:
		actions_confirmed.fill(false)
		for i in range(GameManager.characters.size()):
			var c: GameManager.Character = GameManager.characters[i]
			var p: Dictionary = char_panels[i]
			if c.is_alive():
				c.assigned_action = -1
				p["action_indicator"].text = "sin asignar"
				p["action_indicator"].add_theme_color_override("font_color", COL_BONE.darkened(0.2))
		_update_resolve_btn()


func _show_end_overlay():
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.4)

	if GameManager.game_won:
		var survivors := 0
		for c in GameManager.characters:
			if c.is_alive():
				survivors += 1
		overlay_label.text = "La caravana llego.\n%d sobrevivientes." % survivors
		overlay_label.add_theme_color_override("font_color", COL_MOSS)
	else:
		overlay_label.text = "Nadie sobrevivio.\nNoche %d." % GameManager.day
		overlay_label.add_theme_color_override("font_color", COL_BLOOD)


func _build_overlay():
	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.88)
	overlay.add_theme_stylebox_override("panel", s)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _bubble_style(16, 40))
	inner.custom_minimum_size = Vector2(420, 160)
	center.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(vbox)

	overlay_label = _label("", 22, COL_BONE)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(overlay_label)

	var btn := Button.new()
	btn.text = "JUGAR DE NUEVO"
	_solid_btn(btn, COL_INK_SOFT, COL_BG)
	btn.pressed.connect(_on_restart)
	vbox.add_child(btn)


# =============================================
# CALLBACKS
# =============================================

func _on_resolve():
	if GameManager.game_over or GameManager.game_won or is_night_screen:
		return
	if selected_char >= 0:
		_close_actions(selected_char)
	GameManager.resolve_turn()


func _on_turn_resolved():
	_update_ui()
	_show_night_screen()


func _on_game_ended(_won: bool):
	_update_ui()
	_show_night_screen()


func _on_restart():
	GameManager.restart()
	overlay.visible = false
	night_screen.visible = false
	is_night_screen = false
	selected_char = -1
	actions_confirmed.fill(false)

	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]

		c.assigned_action = -1
		p["action_indicator"].text = "sin asignar"
		p["action_indicator"].add_theme_color_override("font_color", COL_BONE.darkened(0.2))

		var actions_vbox: VBoxContainer = p["actions_vbox"]
		for child in actions_vbox.get_children():
			child.queue_free()
		p["action_buttons"].clear()
		_build_action_buttons(actions_vbox, p["action_buttons"], c, i)

		p["dead_lbl"].visible = false
		p["sprite_overlay"].color = Color(0, 0, 0, 0)
		p["actions_panel"].visible = false
		p["actions_panel"].modulate.a = 0.0
		p["is_selected"] = false
		p["is_hovered"] = false
		p["hover_amount"] = 0.0
		p["info_alpha"] = 0.0
		p["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_update_ui()
	_update_resolve_btn()


# =============================================
# UI UPDATE
# =============================================

func _update_ui():
	day_label.text = "NOCHE %d / %d" % [GameManager.day, GameManager.NIGHTS_TO_SURVIVE]

	food_label.text = "COMIDA: %d" % GameManager.food
	if GameManager.food <= 2:
		food_label.add_theme_color_override("font_color", COL_BLOOD)
	elif GameManager.food <= 5:
		food_label.add_theme_color_override("font_color", COL_WARN)
	else:
		food_label.add_theme_color_override("font_color", COL_INK_SOFT)

	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]

		var state_lbl: Label = p["state_lbl"]
		var sprite_overlay: ColorRect = p["sprite_overlay"]

		if not c.is_alive():
			state_lbl.text = "Muerto"
			state_lbl.add_theme_color_override("font_color", COL_BLOOD)
			p["dead_lbl"].text = "MUERTO"
			p["dead_lbl"].visible = true
			sprite_overlay.color = Color(0, 0, 0, 0.55)
			p["container"].mouse_default_cursor_shape = Control.CURSOR_ARROW
			if selected_char == i:
				_close_actions(i)
			p["action_indicator"].text = "—"
			p["action_indicator"].add_theme_color_override("font_color", COL_BONE.darkened(0.3))
			p["name_lbl"].add_theme_color_override("font_color", COL_BONE.darkened(0.3))
		elif c.is_weak():
			state_lbl.text = "Debil"
			state_lbl.add_theme_color_override("font_color", COL_BLOOD)
			sprite_overlay.color = Color(0.3, 0, 0, 0.15)
			var actions_vbox: VBoxContainer = p["actions_vbox"]
			for child in actions_vbox.get_children():
				child.queue_free()
			p["action_buttons"].clear()
			_build_action_buttons(actions_vbox, p["action_buttons"], c, i)
			if c.assigned_action == GameManager.Action.CUIDAR and not c.can_guard():
				c.assigned_action = GameManager.Action.DORMIR
				p["action_indicator"].text = _action_display_name(c.assigned_action, c)
		else:
			state_lbl.text = "Normal"
			state_lbl.add_theme_color_override("font_color", COL_MOSS)
			sprite_overlay.color = Color(0, 0, 0, 0)
			p["name_lbl"].add_theme_color_override("font_color", COL_INK_SOFT)

		var sleep_lbl: Label = p["sleep_lbl"]
		if c.nights_awake == 0:
			sleep_lbl.text = "Descansado"
			sleep_lbl.add_theme_color_override("font_color", COL_BONE)
		else:
			sleep_lbl.text = "Despierto: %d noche/s" % c.nights_awake
			sleep_lbl.add_theme_color_override("font_color", COL_WARN)

		var need_lbl: Label = p["need_lbl"]
		need_lbl.text = "Necesita: %d" % c.get_food_need()
		if c.is_weak():
			need_lbl.add_theme_color_override("font_color", COL_BLOOD)
		else:
			need_lbl.add_theme_color_override("font_color", COL_WARN)

		var food_lbl: Label = p["food_lbl"]
		if c.is_weak() and c.is_alive():
			food_lbl.text = "Come: %d+%d" % [c.food_consumption, GameManager.EXTRA_FOOD_WHEN_WEAK]
			food_lbl.add_theme_color_override("font_color", COL_BLOOD)
		else:
			food_lbl.text = "Come: %d" % c.food_consumption
			food_lbl.add_theme_color_override("font_color", COL_BONE)

	_update_resolve_btn()
