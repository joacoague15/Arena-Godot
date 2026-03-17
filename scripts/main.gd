extends Control

## Sobrevivir la Pampa - Main UI
## Minimalist gothic. Dirt white canvas. Characters ARE the interface.
## Everything hidden until hover/click reveals dark floating bubbles.
## Food distribution via click-to-pick, click-to-drop.

# --- Palette: dirt white canvas + dark gothic overlays ---
const COL_BG := Color(0.82, 0.78, 0.72)
const COL_INK := Color(0.12, 0.10, 0.08)
const COL_INK_SOFT := Color(0.22, 0.19, 0.15)
const COL_BLOOD := Color(0.55, 0.12, 0.10)
const COL_BONE := Color(0.65, 0.60, 0.52)
const COL_GOLD := Color(0.62, 0.50, 0.28)
const COL_MOSS := Color(0.28, 0.42, 0.25)
const COL_DUSK := Color(0.35, 0.30, 0.45)
const COL_BUBBLE := Color(0.08, 0.07, 0.05, 0.92)
const COL_WARN := Color(0.70, 0.55, 0.15)

# --- Sprite config ---
const SPRITE_FOLDERS := {
	"Caudillo": "res://sprites/caudillo/idle/",
	"Vigia": "res://sprites/vigia/idle/",
	"Curandera": "res://sprites/healer/idle/",
}
const SPRITE_FPS := 8.0
const SPRITE_FRAME_COUNT := 8

# --- Food token config ---
const FOOD_TOKEN_SIZE := 24
const FOOD_TOKEN_GAP := 5
const FOOD_GRID_COLS := 10

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

# --- Food Screen Refs ---
var food_screen: ColorRect
var food_screen_panel: PanelContainer
var food_pool_container: GridContainer
var food_pool_label: Label
var food_char_zones: Array = []
var food_confirm_btn: Button
var food_drag_preview: PanelContainer

# --- Cure Targeting Refs ---
var cure_preview: PanelContainer
var cure_hint_label: Label

# --- State ---
var sprite_time := 0.0
var selected_char := -1
var is_night_screen := false
var actions_confirmed: Array = []
var food_screen_active := false
var food_carrying := false
var food_remaining := 0
var cure_targeting := false
var cure_source_idx := -1  # index of the Curandera doing the curing


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
	var s := StyleBoxFlat.new()
	s.bg_color = COL_BUBBLE
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	return s


func _ghost_btn(btn: Button, fg: Color, size: int = 14):
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


func _create_food_token(clickable: bool) -> PanelContainer:
	var token := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_GOLD if clickable else COL_GOLD.lightened(0.15)
	style.set_corner_radius_all(5)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	token.add_theme_stylebox_override("panel", style)
	token.custom_minimum_size = Vector2(FOOD_TOKEN_SIZE, FOOD_TOKEN_SIZE)
	if clickable:
		token.mouse_filter = Control.MOUSE_FILTER_STOP
		token.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		token.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_food_pool_click()
		)
	else:
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Small food icon inside
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
# BUILD
# =============================================

func _ready():
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)

	_build_hud()
	_build_characters()
	_build_bottom_bar()

	_build_food_screen()
	_build_night_screen()
	_build_overlay()

	# Drag preview on top of everything
	food_drag_preview = PanelContainer.new()
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = COL_GOLD.lightened(0.3)
	prev_style.set_corner_radius_all(6)
	food_drag_preview.add_theme_stylebox_override("panel", prev_style)
	food_drag_preview.custom_minimum_size = Vector2(FOOD_TOKEN_SIZE + 4, FOOD_TOKEN_SIZE + 4)
	food_drag_preview.visible = false
	food_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_drag_preview.z_index = 100
	var prev_lbl := Label.new()
	prev_lbl.text = "●"
	prev_lbl.add_theme_font_size_override("font_size", 12)
	prev_lbl.add_theme_color_override("font_color", Color(0.35, 0.25, 0.12))
	prev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prev_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_drag_preview.add_child(prev_lbl)
	add_child(food_drag_preview)

	# Cure targeting preview
	cure_preview = PanelContainer.new()
	var cure_style := StyleBoxFlat.new()
	cure_style.bg_color = COL_DUSK.lightened(0.2)
	cure_style.set_corner_radius_all(8)
	cure_style.content_margin_left = 8
	cure_style.content_margin_right = 8
	cure_style.content_margin_top = 4
	cure_style.content_margin_bottom = 4
	cure_preview.add_theme_stylebox_override("panel", cure_style)
	cure_preview.visible = false
	cure_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cure_preview.z_index = 100
	var cure_lbl := Label.new()
	cure_lbl.text = "CURAR ✚"
	cure_lbl.add_theme_font_size_override("font_size", 11)
	cure_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.95))
	cure_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cure_preview.add_child(cure_lbl)
	add_child(cure_preview)

	# Hint label (top center, shown during targeting)
	cure_hint_label = _label("", 13, COL_DUSK.lightened(0.4))
	cure_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cure_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cure_hint_label.offset_top = 55
	cure_hint_label.offset_bottom = 75
	cure_hint_label.visible = false
	cure_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cure_hint_label.z_index = 50
	add_child(cure_hint_label)

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

	# Drag preview follows mouse
	if food_carrying and food_drag_preview.visible:
		var mp := get_viewport().get_mouse_position()
		food_drag_preview.position = mp - Vector2(FOOD_TOKEN_SIZE / 2 + 2, FOOD_TOKEN_SIZE / 2 + 2)

	# Cure preview follows mouse
	if cure_targeting and cure_preview.visible:
		var cp := get_viewport().get_mouse_position()
		cure_preview.position = cp + Vector2(16, 8)

	# Highlight zones while carrying
	if food_screen_active:
		_process_food_zone_highlights()


func _unhandled_input(event: InputEvent):
	# Cancel cure targeting with right-click
	if cure_targeting:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_cure_targeting()
			get_viewport().set_input_as_handled()
			return

	# Cancel food carry with right-click
	if food_screen_active and food_carrying:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			food_carrying = false
			food_drag_preview.visible = false
			get_viewport().set_input_as_handled()
			return

	if food_screen_active or is_night_screen:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_char >= 0:
			var p: Dictionary = char_panels[selected_char]
			var sprite_area: Control = p["sprite_rect"]
			var actions_panel: Control = p["actions_panel"]
			if not sprite_area.get_global_rect().has_point(event.position) and not actions_panel.get_global_rect().has_point(event.position):
				_close_actions(selected_char)


# --- HUD ---
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


# --- Characters ---
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

	var container := Control.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(container)

	var sprite_rect := TextureRect.new()
	sprite_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sprite_rect)

	var frames := _load_sprite_frames(c.char_name)
	if frames.size() > 0:
		sprite_rect.texture = frames[0]

	var sprite_overlay := ColorRect.new()
	sprite_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_overlay.color = Color(0, 0, 0, 0)
	sprite_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sprite_overlay)

	var dead_lbl := _label("", 32, COL_BLOOD)
	dead_lbl.set_anchors_preset(Control.PRESET_CENTER)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_lbl.visible = false
	container.add_child(dead_lbl)

	var name_lbl := _label(c.char_name.to_upper(), 11, COL_INK_SOFT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -28
	name_lbl.offset_bottom = -12
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_lbl)

	# Hover info bubble
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

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size.y = 1
	info_vbox.add_child(sep)

	var state_lbl := _label("Normal", 11, COL_MOSS)
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(state_lbl)

	var need_lbl := _label("Necesita: %d" % c.get_food_need(), 10, COL_WARN)
	need_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(need_lbl)

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

	# Actions bubble
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

	if c.can_faenar():
		var btn := Button.new()
		btn.text = "FAENAR"
		_ghost_btn(btn, COL_BLOOD)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.FAENAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.FAENAR})

	if c.can_curar():
		var btn := Button.new()
		btn.text = "CURAR"
		_ghost_btn(btn, COL_DUSK.lightened(0.3))
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.CURAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CURAR})

	if c.can_rastrear():
		var btn := Button.new()
		btn.text = "RASTREAR"
		_ghost_btn(btn, COL_WARN)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.RASTREAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.RASTREAR})


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
		GameManager.Action.FAENAR: return "faenar"
		GameManager.Action.CURAR: return "curar"
		GameManager.Action.RASTREAR: return "rastrear"
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
	if GameManager.characters[idx].is_alive() and not is_night_screen and not food_screen_active:
		char_panels[idx]["is_hovered"] = true
		# During cure targeting, show special cursor on valid targets
		if cure_targeting:
			char_panels[idx]["container"].mouse_default_cursor_shape = Control.CURSOR_CROSS

func _on_char_hover_exit(idx: int):
	char_panels[idx]["is_hovered"] = false
	if cure_targeting:
		char_panels[idx]["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process_hover(delta: float):
	for i in range(char_panels.size()):
		var p: Dictionary = char_panels[i]
		var alive = GameManager.characters[i].is_alive()
		var target := 0.0
		if (p["is_hovered"] or p["is_selected"]) and alive:
			target = 1.0

		p["hover_amount"] = lerpf(p["hover_amount"], target, 0.12)
		p["info_alpha"] = lerpf(p["info_alpha"], target, 0.1)

		var info_bubble: PanelContainer = p["info_bubble"]
		info_bubble.modulate.a = p["info_alpha"]
		info_bubble.offset_bottom = -35 - p["info_alpha"] * 5

		var sprite: TextureRect = p["sprite_rect"]
		var s := lerpf(1.0, 1.015, p["hover_amount"])
		sprite.pivot_offset = sprite.size / 2.0
		sprite.scale = Vector2(s, s)


func _on_char_gui_input(event: InputEvent, idx: int):
	if is_night_screen or food_screen_active:
		return

	# Cure targeting: click on character to select heal target
	if cure_targeting:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var target_c: GameManager.Character = GameManager.characters[idx]
			if target_c.is_alive():
				_confirm_cure_target(idx)
			get_viewport().set_input_as_handled()
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

	# CURAR enters targeting mode instead of confirming immediately
	if action_id == GameManager.Action.CURAR:
		_close_actions(char_idx)
		_start_cure_targeting(char_idx)
		return

	# Apply action immediately (CAZAR/FAENAR add food to pool instantly)
	var produced = GameManager.apply_immediate_action(char_idx, action_id)
	actions_confirmed[char_idx] = true

	var p: Dictionary = char_panels[char_idx]
	var indicator: Label = p["action_indicator"]
	if produced > 0:
		indicator.text = "%s (+%d)" % [_action_display_name(action_id, c), produced]
		indicator.add_theme_color_override("font_color", COL_GOLD)
	else:
		indicator.text = _action_display_name(action_id, c)
		indicator.add_theme_color_override("font_color", COL_INK_SOFT)

	# Update food counter immediately
	_update_ui()

	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(_close_actions.bind(char_idx))

	_update_resolve_btn()


# =============================================
# CURE TARGETING
# =============================================

func _start_cure_targeting(healer_idx: int):
	cure_targeting = true
	cure_source_idx = healer_idx
	cure_preview.visible = true
	cure_hint_label.text = "CURAR: elige a quien curar  (click derecho para cancelar)"
	cure_hint_label.visible = true


func _confirm_cure_target(target_idx: int):
	# Apply cure immediately
	GameManager.apply_immediate_cure(cure_source_idx, target_idx)
	actions_confirmed[cure_source_idx] = true

	var target_name: String = GameManager.characters[target_idx].char_name
	var p: Dictionary = char_panels[cure_source_idx]
	var indicator: Label = p["action_indicator"]
	indicator.text = "curar → %s" % target_name.to_lower()
	indicator.add_theme_color_override("font_color", COL_DUSK.lightened(0.3))

	cure_targeting = false
	cure_source_idx = -1
	cure_preview.visible = false
	cure_hint_label.visible = false
	# Restore cursors
	for i in range(char_panels.size()):
		if GameManager.characters[i].is_alive():
			char_panels[i]["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Refresh UI immediately (healed character changes state, buttons rebuild)
	_update_ui()
	_update_resolve_btn()


func _cancel_cure_targeting():
	cure_targeting = false
	cure_source_idx = -1
	cure_preview.visible = false
	cure_hint_label.visible = false
	# Restore cursors
	for i in range(char_panels.size()):
		if GameManager.characters[i].is_alive():
			char_panels[i]["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# =============================================
# FOOD DISTRIBUTION SCREEN
# =============================================

func _build_food_screen():
	food_screen = ColorRect.new()
	food_screen.color = Color(0.06, 0.05, 0.03, 0.96)
	food_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	food_screen.visible = false
	food_screen.modulate.a = 0.0
	food_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	# Click on background cancels carry
	food_screen.gui_input.connect(_on_food_bg_input)
	add_child(food_screen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	food_screen.add_child(center)

	food_screen_panel = PanelContainer.new()
	food_screen_panel.add_theme_stylebox_override("panel", _bubble_style(18, 32))
	food_screen_panel.custom_minimum_size = Vector2(720, 440)
	center.add_child(food_screen_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	food_screen_panel.add_child(main_vbox)

	# Title
	var title := _label("DISTRIBUIR COMIDA", 18, COL_BONE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle := _label("Toma comida de la reserva y asignala a cada personaje", 11, COL_BONE.darkened(0.2))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# Characters row
	var chars_hbox := HBoxContainer.new()
	chars_hbox.add_theme_constant_override("separation", 16)
	chars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(chars_hbox)

	food_char_zones.clear()
	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.custom_minimum_size.x = 190
		chars_hbox.add_child(col)

		var fname := _label(c.char_name.to_upper(), 14, COL_BONE)
		fname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(fname)

		var fneed := _label("Necesita: %d" % c.get_food_need(), 11, COL_WARN)
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
		zone.gui_input.connect(_on_food_zone_input.bind(i))
		col.add_child(zone)

		var zone_grid := GridContainer.new()
		zone_grid.columns = 5
		zone_grid.add_theme_constant_override("h_separation", FOOD_TOKEN_GAP)
		zone_grid.add_theme_constant_override("v_separation", FOOD_TOKEN_GAP)
		zone_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(zone_grid)

		var falloc := _label("0 / %d" % c.get_food_need(), 12, COL_BONE)
		falloc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(falloc)

		# Highlight style (pre-built)
		var zone_style_hover := zone_style_normal.duplicate()
		zone_style_hover.border_color = COL_GOLD
		zone_style_hover.set_border_width_all(2)
		zone_style_hover.bg_color = Color(1, 1, 1, 0.06)

		food_char_zones.append({
			"column": col,
			"name_lbl": fname,
			"need_lbl": fneed,
			"zone": zone,
			"zone_style_normal": zone_style_normal,
			"zone_style_hover": zone_style_hover,
			"zone_grid": zone_grid,
			"alloc_lbl": falloc,
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

	food_pool_label = _label("RESERVA: 10", 14, COL_GOLD)
	food_pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pool_vbox.add_child(food_pool_label)

	food_pool_container = GridContainer.new()
	food_pool_container.columns = FOOD_GRID_COLS
	food_pool_container.add_theme_constant_override("h_separation", FOOD_TOKEN_GAP)
	food_pool_container.add_theme_constant_override("v_separation", FOOD_TOKEN_GAP)
	food_pool_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pool_vbox.add_child(food_pool_container)

	# Confirm button
	food_confirm_btn = Button.new()
	food_confirm_btn.text = "CONFIRMAR"
	_solid_btn(food_confirm_btn, COL_GOLD.darkened(0.2), Color(0.95, 0.92, 0.85))
	food_confirm_btn.pressed.connect(_on_food_confirm)
	food_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(food_confirm_btn)


func _show_food_screen():
	food_screen_active = true
	food_carrying = false
	food_drag_preview.visible = false

	# Init allocation
	food_remaining = GameManager.food
	GameManager.food_allocated.resize(GameManager.characters.size())
	GameManager.food_allocated.fill(0)

	_refresh_food_screen()

	food_screen.visible = true
	food_screen.modulate.a = 0.0
	food_screen_panel.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(food_screen, "modulate:a", 1.0, 0.4)
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_BACK)
		tw.tween_property(food_screen_panel, "modulate:a", 1.0, 0.25)
	)


func _refresh_food_screen():
	# Pool
	food_pool_label.text = "RESERVA: %d" % food_remaining
	if food_remaining == 0:
		food_pool_label.add_theme_color_override("font_color", COL_BLOOD)
	else:
		food_pool_label.add_theme_color_override("font_color", COL_GOLD)

	# Rebuild pool tokens
	for child in food_pool_container.get_children():
		food_pool_container.remove_child(child)
		child.queue_free()
	for _t in range(food_remaining):
		food_pool_container.add_child(_create_food_token(true))

	# Character zones
	for i in range(food_char_zones.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var z: Dictionary = food_char_zones[i]
		var allocated: int = GameManager.food_allocated[i] if i < GameManager.food_allocated.size() else 0
		var need: int = c.get_food_need() if c.is_alive() else 0

		# Need label
		if not c.is_alive():
			z["need_lbl"].text = "Muerto"
			z["need_lbl"].add_theme_color_override("font_color", COL_BLOOD)
		else:
			z["need_lbl"].text = "Necesita: %d" % need
			if allocated >= need:
				z["need_lbl"].add_theme_color_override("font_color", COL_MOSS)
			else:
				z["need_lbl"].add_theme_color_override("font_color", COL_WARN)

		# Allocation label
		z["alloc_lbl"].text = "%d / %d" % [allocated, need]
		if not c.is_alive():
			z["alloc_lbl"].add_theme_color_override("font_color", COL_BONE.darkened(0.3))
		elif allocated >= need:
			z["alloc_lbl"].add_theme_color_override("font_color", COL_MOSS)
		elif allocated > 0:
			z["alloc_lbl"].add_theme_color_override("font_color", COL_WARN)
		else:
			z["alloc_lbl"].add_theme_color_override("font_color", COL_BLOOD)

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


func _process_food_zone_highlights():
	var mp := get_viewport().get_mouse_position()
	for i in range(food_char_zones.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var z: Dictionary = food_char_zones[i]
		var zone: PanelContainer = z["zone"]
		var is_hover := food_carrying and c.is_alive() and zone.get_global_rect().has_point(mp)
		if is_hover:
			zone.add_theme_stylebox_override("panel", z["zone_style_hover"])
		else:
			zone.add_theme_stylebox_override("panel", z["zone_style_normal"])


func _on_food_pool_click():
	if not food_carrying and food_remaining > 0:
		food_carrying = true
		food_drag_preview.visible = true


func _on_food_zone_input(event: InputEvent, char_idx: int):
	var c: GameManager.Character = GameManager.characters[char_idx]
	if not c.is_alive():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if food_carrying:
			# Drop food on this character
			GameManager.food_allocated[char_idx] += 1
			food_remaining -= 1
			food_carrying = false
			food_drag_preview.visible = false
			_refresh_food_screen()
		else:
			# Remove food from this character (click to return)
			if GameManager.food_allocated[char_idx] > 0:
				GameManager.food_allocated[char_idx] -= 1
				food_remaining += 1
				_refresh_food_screen()


func _on_food_bg_input(event: InputEvent):
	if food_carrying and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Cancel carry on background click
		food_carrying = false
		food_drag_preview.visible = false


func _on_food_confirm():
	food_screen_active = false
	food_carrying = false
	food_drag_preview.visible = false

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(food_screen_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(food_screen, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		food_screen.visible = false
		GameManager.resolve_turn()
	)


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
		elif "debilita" in msg or "exhausto" in msg:
			colored = "[color=#997744]%s[/color]" % msg
		elif "cura a" in msg:
			colored = "[color=#8866aa]%s[/color]" % msg
		elif "faena" in msg:
			colored = "[color=#aa5544]%s[/color]" % msg
		elif "AVISTAMIENTO" in msg:
			colored = "[color=#bb9944][b]%s[/b][/color]" % msg
		elif "rastreo" in msg or "informacion se revelara" in msg:
			colored = "[color=#bb9944]%s[/color]" % msg
		elif "come bien" in msg:
			colored = "[color=#557744]%s[/color]" % msg
		elif "come poco" in msg or "pasa hambre" in msg:
			colored = "[color=#994433]%s[/color]" % msg
		elif "Noche sin incidentes" in msg or "no detecto amenazas" in msg:
			colored = "[color=#557744]%s[/color]" % msg
		elif msg.begins_with("---"):
			colored = "[color=#9e8052][b]%s[/b][/color]" % msg
		elif "Total cazado" in msg:
			colored = "[color=#9e8852]%s[/color]" % msg
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
		GameManager.cure_target = -1
		GameManager.food_produced.fill(0)
		GameManager.hunt_log_msgs.clear()
		for i in range(GameManager.characters.size()):
			var c: GameManager.Character = GameManager.characters[i]
			var p: Dictionary = char_panels[i]
			if c.is_alive():
				c.assigned_action = -1
				p["action_indicator"].text = "sin asignar"
				p["action_indicator"].add_theme_color_override("font_color", COL_BONE.darkened(0.2))
				var actions_vbox: VBoxContainer = p["actions_vbox"]
				for child in actions_vbox.get_children():
					child.queue_free()
				p["action_buttons"].clear()
				_build_action_buttons(actions_vbox, p["action_buttons"], c, i)
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
	if GameManager.game_over or GameManager.game_won or is_night_screen or food_screen_active or cure_targeting:
		return
	if selected_char >= 0:
		_close_actions(selected_char)
	# Show food distribution before resolving
	_show_food_screen()


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
	food_screen.visible = false
	is_night_screen = false
	food_screen_active = false
	food_carrying = false
	food_drag_preview.visible = false
	cure_targeting = false
	cure_source_idx = -1
	cure_preview.visible = false
	cure_hint_label.visible = false
	GameManager.cure_target = -1
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
			var needs_reset := false
			if c.assigned_action == GameManager.Action.CUIDAR and not c.can_guard():
				needs_reset = true
			elif c.assigned_action == GameManager.Action.FAENAR and not c.can_faenar():
				needs_reset = true
			if needs_reset:
				GameManager._undo_immediate_action(i)
				c.assigned_action = -1
				actions_confirmed[i] = false
				p["action_indicator"].text = "sin asignar"
				p["action_indicator"].add_theme_color_override("font_color", COL_BONE.darkened(0.2))
		else:
			state_lbl.text = "Normal"
			state_lbl.add_theme_color_override("font_color", COL_MOSS)
			sprite_overlay.color = Color(0, 0, 0, 0)
			p["name_lbl"].add_theme_color_override("font_color", COL_INK_SOFT)

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
