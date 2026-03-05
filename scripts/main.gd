extends Control

## Sobrevivir la Pampa - Main UI
## Sprite-focused layout with click-to-reveal action selectors.

# --- Palette ---
const COL_BG := Color(0.10, 0.08, 0.06)
const COL_PANEL := Color(0.17, 0.14, 0.11)
const COL_PANEL_DARK := Color(0.13, 0.11, 0.08)
const COL_ACCENT := Color(0.76, 0.60, 0.32)
const COL_TEXT := Color(0.88, 0.83, 0.73)
const COL_DIM := Color(0.55, 0.50, 0.43)
const COL_RED := Color(0.80, 0.25, 0.22)
const COL_GREEN := Color(0.30, 0.72, 0.35)
const COL_YELLOW := Color(0.85, 0.70, 0.25)

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
var log_label: RichTextLabel
var overlay: PanelContainer
var overlay_label: Label
var char_panels: Array = []  # Array of Dictionaries

# --- Animation state ---
var sprite_time := 0.0
var selected_char := -1  # Currently selected character index (-1 = none)


# --- Helpers ---

func _style(node: PanelContainer, color: Color, radius: int = 8, pad: int = 12):
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	node.add_theme_stylebox_override("panel", s)


func _label(text: String, size: int = 15, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _btn_style(btn: Button, bg: Color, fg: Color = COL_BG):
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", fg)
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	var p := s.duplicate()
	p.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", p)


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


# --- Build ---

func _ready():
	# BG
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_build_top_bar(vbox)
	_build_characters(vbox)
	_build_buttons(vbox)
	_build_log(vbox)
	_build_overlay()

	# Click-away detector: a transparent layer behind everything
	# that closes the action menu when clicking outside
	var click_away := Control.new()
	click_away.name = "ClickAway"
	click_away.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_away.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(click_away)

	GameManager.turn_resolved.connect(_on_turn_resolved)
	GameManager.game_ended.connect(_on_game_ended)

	_update_ui()
	_show_intro()


func _process(delta: float):
	# Animate all character sprites with ping-pong
	sprite_time += delta
	var total_frames := SPRITE_FRAME_COUNT
	var cycle_length := (total_frames * 2) - 2
	if cycle_length <= 0:
		return
	var pos := int(sprite_time * SPRITE_FPS) % cycle_length
	var frame_index: int
	if pos < total_frames:
		frame_index = pos
	else:
		frame_index = cycle_length - pos

	for p in char_panels:
		var frames: Array = p["sprite_frames"]
		var tex_rect: TextureRect = p["sprite_rect"]
		if frames.size() > 0:
			tex_rect.texture = frames[frame_index % frames.size()]

	# Update hover glow effects
	_process_hover_effects(delta)


func _unhandled_input(event: InputEvent):
	# Click anywhere outside a character to close action menu
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_char >= 0:
			# Check if click was outside the selected character's area
			var p: Dictionary = char_panels[selected_char]
			var container: Control = p["char_container"]
			var actions_panel: Control = p["actions_panel"]
			var local_pos_container := container.get_global_rect()
			var local_pos_actions := actions_panel.get_global_rect()
			if not local_pos_container.has_point(event.position) and not local_pos_actions.has_point(event.position):
				_close_actions(selected_char)


func _build_top_bar(parent: VBoxContainer):
	var panel := PanelContainer.new()
	_style(panel, COL_PANEL)
	parent.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var title := _label("SOBREVIVIR LA PAMPA", 20, COL_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	day_label = _label("Noche 1 / 10", 17)
	hbox.add_child(day_label)

	hbox.add_child(_label("|", 17, COL_DIM))

	food_label = _label("Comida: 10", 17, COL_YELLOW)
	hbox.add_child(food_label)


func _build_characters(parent: VBoxContainer):
	# Main character area - takes most vertical space
	var chars_container := HBoxContainer.new()
	chars_container.add_theme_constant_override("separation", 16)
	chars_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(chars_container)

	for i in range(GameManager.characters.size()):
		var data := _build_char_panel(chars_container, i)
		char_panels.append(data)


func _build_char_panel(parent: HBoxContainer, idx: int) -> Dictionary:
	var c: GameManager.Character = GameManager.characters[idx]

	# Outer container for the whole character column
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	parent.add_child(outer)

	# --- Character clickable container ---
	var char_container := PanelContainer.new()
	char_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	char_container.mouse_filter = Control.MOUSE_FILTER_STOP
	char_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Base style
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.12, 0.10, 0.08)
	base_style.set_corner_radius_all(12)
	base_style.content_margin_left = 4
	base_style.content_margin_right = 4
	base_style.content_margin_top = 4
	base_style.content_margin_bottom = 4
	base_style.border_width_bottom = 3
	base_style.border_color = c.color.darkened(0.3)
	char_container.add_theme_stylebox_override("panel", base_style)
	outer.add_child(char_container)

	# Inner VBox for sprite + info
	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 2)
	inner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_container.add_child(inner_vbox)

	# --- Large sprite area ---
	var sprite_rect := TextureRect.new()
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vbox.add_child(sprite_rect)

	# Load frames
	var frames := _load_sprite_frames(c.char_name)
	if frames.size() > 0:
		sprite_rect.texture = frames[0]

	# Dead/weak overlay on sprite
	var sprite_overlay := ColorRect.new()
	sprite_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_overlay.color = Color(0, 0, 0, 0)
	sprite_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_container.add_child(sprite_overlay)

	# Hover glow overlay (additive brightness)
	var hover_overlay := ColorRect.new()
	hover_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hover_overlay.color = Color(1, 1, 1, 0)  # White, transparent
	hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_container.add_child(hover_overlay)

	# Dead label centered on sprite
	var dead_lbl := _label("", 28, COL_RED)
	dead_lbl.set_anchors_preset(Control.PRESET_CENTER)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_lbl.visible = false
	char_container.add_child(dead_lbl)

	# --- Bottom info strip (inside the sprite panel) ---
	var info_bar := PanelContainer.new()
	info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0, 0, 0, 0.5)
	info_style.set_corner_radius_all(0)
	info_style.corner_radius_bottom_left = 10
	info_style.corner_radius_bottom_right = 10
	info_style.content_margin_left = 8
	info_style.content_margin_right = 8
	info_style.content_margin_top = 6
	info_style.content_margin_bottom = 6
	info_bar.add_theme_stylebox_override("panel", info_style)
	inner_vbox.add_child(info_bar)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bar.add_child(info_vbox)

	# Name
	var name_lbl := _label(c.char_name, 16, c.color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(name_lbl)

	# Compact stats
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 6)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(stats_hbox)

	var food_txt := "%d" % c.food_consumption
	var hunt_txt := "+%d" % c.hunt_yield if c.hunt_yield > 0 else "--"
	var guard_txt := "-%d%%" % int(c.guard_reduction * 100) if c.guard_reduction > 0 else "--"

	var food_lbl := _label("Come:%s" % food_txt, 11, COL_DIM)
	stats_hbox.add_child(food_lbl)
	stats_hbox.add_child(_label("|", 11, Color(0.3, 0.27, 0.22)))
	stats_hbox.add_child(_label("Caza:%s" % hunt_txt, 11, COL_DIM))
	stats_hbox.add_child(_label("|", 11, Color(0.3, 0.27, 0.22)))
	stats_hbox.add_child(_label("Guard:%s" % guard_txt, 11, COL_DIM))

	# State + sleep in one row
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 8)
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(status_hbox)

	var state_lbl := _label("Normal", 11, COL_GREEN)
	status_hbox.add_child(state_lbl)

	var sleep_lbl := _label("Sueno: OK", 11, COL_TEXT)
	status_hbox.add_child(sleep_lbl)

	var need_lbl := _label("Necesita: %d" % c.get_food_need(), 11, COL_YELLOW)
	status_hbox.add_child(need_lbl)

	# --- Current action indicator (shown at bottom of character) ---
	var action_indicator := _label("CAZAR", 13, COL_ACCENT)
	action_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var action_ind_panel := PanelContainer.new()
	action_ind_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ind_style := StyleBoxFlat.new()
	ind_style.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	ind_style.set_corner_radius_all(6)
	ind_style.content_margin_left = 8
	ind_style.content_margin_right = 8
	ind_style.content_margin_top = 3
	ind_style.content_margin_bottom = 3
	action_ind_panel.add_theme_stylebox_override("panel", ind_style)
	action_ind_panel.add_child(action_indicator)
	outer.add_child(action_ind_panel)

	# Set default action indicator text
	var default_act := _default_action(idx)
	c.assigned_action = default_act
	action_indicator.text = _action_display_name(default_act, c)

	# --- Actions panel (hidden by default, appears on click) ---
	var actions_panel := PanelContainer.new()
	actions_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var actions_style := StyleBoxFlat.new()
	actions_style.bg_color = Color(0.15, 0.12, 0.09, 0.95)
	actions_style.set_corner_radius_all(10)
	actions_style.border_width_left = 2
	actions_style.border_width_right = 2
	actions_style.border_width_top = 2
	actions_style.border_width_bottom = 2
	actions_style.border_color = c.color.darkened(0.2)
	actions_style.content_margin_left = 6
	actions_style.content_margin_right = 6
	actions_style.content_margin_top = 6
	actions_style.content_margin_bottom = 6
	actions_panel.add_theme_stylebox_override("panel", actions_style)
	actions_panel.visible = false
	actions_panel.modulate.a = 0.0
	actions_panel.scale = Vector2(0.9, 0.9)
	outer.add_child(actions_panel)

	var actions_vbox := VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 4)
	actions_panel.add_child(actions_vbox)

	# Build action buttons
	var action_buttons: Array = []
	_build_action_buttons(actions_vbox, action_buttons, c, idx)

	# Connect hover + click on character container
	char_container.gui_input.connect(_on_char_gui_input.bind(idx))
	char_container.mouse_entered.connect(_on_char_hover_enter.bind(idx))
	char_container.mouse_exited.connect(_on_char_hover_exit.bind(idx))

	return {
		"char_container": char_container,
		"sprite_rect": sprite_rect,
		"sprite_frames": frames,
		"sprite_overlay": sprite_overlay,
		"hover_overlay": hover_overlay,
		"dead_lbl": dead_lbl,
		"state_lbl": state_lbl,
		"sleep_lbl": sleep_lbl,
		"need_lbl": need_lbl,
		"food_lbl": food_lbl,
		"action_indicator": action_indicator,
		"action_ind_panel": action_ind_panel,
		"actions_panel": actions_panel,
		"actions_vbox": actions_vbox,
		"action_buttons": action_buttons,
		"base_style": base_style,
		"char_color": c.color,
		"hover_amount": 0.0,
		"is_hovered": false,
		"is_selected": false,
	}


func _build_action_buttons(parent: VBoxContainer, buttons_array: Array, c: GameManager.Character, idx: int):
	# Title
	var title := _label("Accion:", 12, COL_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)

	# CAZAR button
	if c.can_hunt():
		var btn := _make_action_btn("CAZAR (+%d)" % c.hunt_yield, COL_GREEN.darkened(0.4), idx, GameManager.Action.CAZAR)
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CAZAR})

	# CUIDAR button
	if c.can_guard():
		var btn := _make_action_btn("CUIDAR (-%d%%)" % int(c.guard_reduction * 100), COL_ACCENT.darkened(0.4), idx, GameManager.Action.CUIDAR)
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CUIDAR})

	# DORMIR button
	var btn_sleep := _make_action_btn("DORMIR", Color(0.25, 0.30, 0.55), idx, GameManager.Action.DORMIR)
	parent.add_child(btn_sleep)
	buttons_array.append({"btn": btn_sleep, "action": GameManager.Action.DORMIR})


func _make_action_btn(text: String, bg_color: Color, char_idx: int, action_id: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", COL_TEXT)

	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", s)

	var h := s.duplicate()
	h.bg_color = bg_color.lightened(0.25)
	btn.add_theme_stylebox_override("hover", h)

	var p := s.duplicate()
	p.bg_color = bg_color.lightened(0.1)
	p.border_width_left = 2
	p.border_width_right = 2
	p.border_width_top = 2
	p.border_width_bottom = 2
	p.border_color = COL_ACCENT
	btn.add_theme_stylebox_override("pressed", p)

	btn.pressed.connect(_on_action_btn_pressed.bind(char_idx, action_id))
	return btn


func _action_display_name(action_id: int, c: GameManager.Character) -> String:
	match action_id:
		GameManager.Action.CAZAR:
			return "CAZAR (+%d)" % c.hunt_yield
		GameManager.Action.CUIDAR:
			return "CUIDAR (-%d%%)" % int(c.guard_reduction * 100)
		GameManager.Action.DORMIR:
			return "DORMIR"
	return "?"


func _default_action(idx: int) -> int:
	match idx:
		0: return GameManager.Action.CAZAR
		1: return GameManager.Action.CUIDAR
		2: return GameManager.Action.DORMIR
	return GameManager.Action.DORMIR


# --- Hover & click effects ---

var _hover_tweens: Dictionary = {}

func _on_char_hover_enter(idx: int):
	if GameManager.characters[idx].is_alive():
		char_panels[idx]["is_hovered"] = true

func _on_char_hover_exit(idx: int):
	char_panels[idx]["is_hovered"] = false

func _process_hover_effects(_delta: float):
	for i in range(char_panels.size()):
		var p: Dictionary = char_panels[i]
		var target := 0.0
		if p["is_hovered"] and GameManager.characters[i].is_alive():
			target = 1.0
		if p["is_selected"]:
			target = 1.0

		# Smooth lerp
		p["hover_amount"] = lerpf(p["hover_amount"], target, 0.15)

		# Apply hover glow
		var hover_ov: ColorRect = p["hover_overlay"]
		hover_ov.color = Color(1, 1, 1, p["hover_amount"] * 0.06)

		# Apply border glow
		var style: StyleBoxFlat = p["base_style"]
		var base_border = p["char_color"].darkened(0.3)
		var glow_border = p["char_color"].lightened(0.2)
		style.border_color = base_border.lerp(glow_border, p["hover_amount"])
		style.border_width_bottom = 3 + int(p["hover_amount"] * 2)
		style.border_width_left = int(p["hover_amount"] * 1.5)
		style.border_width_right = int(p["hover_amount"] * 1.5)
		style.border_width_top = int(p["hover_amount"] * 1.5)


func _on_char_gui_input(event: InputEvent, idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c: GameManager.Character = GameManager.characters[idx]
		if not c.is_alive():
			return
		if GameManager.game_over or GameManager.game_won:
			return

		if selected_char == idx:
			# Toggle off
			_close_actions(idx)
		else:
			# Close previous if any
			if selected_char >= 0:
				_close_actions(selected_char)
			# Open this one
			_open_actions(idx)

		get_viewport().set_input_as_handled()


func _open_actions(idx: int):
	selected_char = idx
	char_panels[idx]["is_selected"] = true
	var p: Dictionary = char_panels[idx]
	var panel: PanelContainer = p["actions_panel"]
	panel.visible = true

	# Animate in: scale up + fade in
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25).from(0.0)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).from(Vector2(0.85, 0.85))

	# Subtle bounce on the character
	var container: PanelContainer = p["char_container"]
	var tween2 := create_tween()
	tween2.set_ease(Tween.EASE_OUT)
	tween2.set_trans(Tween.TRANS_ELASTIC)
	tween2.tween_property(container, "scale", Vector2(1.0, 1.0), 0.4).from(Vector2(0.97, 0.97))


func _close_actions(idx: int):
	if idx < 0 or idx >= char_panels.size():
		return
	char_panels[idx]["is_selected"] = false
	var p: Dictionary = char_panels[idx]
	var panel: PanelContainer = p["actions_panel"]

	# Animate out: shrink + fade
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.15)
	tween.chain().tween_callback(func(): panel.visible = false)

	if selected_char == idx:
		selected_char = -1


func _on_action_btn_pressed(char_idx: int, action_id: int):
	var c: GameManager.Character = GameManager.characters[char_idx]
	c.assigned_action = action_id

	# Update indicator
	var p: Dictionary = char_panels[char_idx]
	var indicator: Label = p["action_indicator"]
	indicator.text = _action_display_name(action_id, c)

	# Flash indicator color
	var ind_panel: PanelContainer = p["action_ind_panel"]
	var tween := create_tween()
	tween.tween_property(indicator, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
	tween.tween_property(indicator, "modulate", Color(1, 1, 1, 1), 0.2)

	# Highlight the selected button briefly
	_highlight_selected_action(char_idx, action_id)

	# Close action menu after a short delay
	var close_tween := create_tween()
	close_tween.tween_interval(0.2)
	close_tween.tween_callback(_close_actions.bind(char_idx))


func _highlight_selected_action(char_idx: int, action_id: int):
	var p: Dictionary = char_panels[char_idx]
	var buttons: Array = p["action_buttons"]
	for b in buttons:
		var btn: Button = b["btn"]
		if b["action"] == action_id:
			# Brief highlight
			btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
			var tw := create_tween()
			tw.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.3)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
			var tw := create_tween()
			tw.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.3)


func _build_buttons(parent: VBoxContainer):
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)

	resolve_btn = Button.new()
	resolve_btn.text = "  TERMINAR TURNO  "
	_btn_style(resolve_btn, COL_ACCENT)
	resolve_btn.pressed.connect(_on_resolve)
	hbox.add_child(resolve_btn)

	var restart_btn := Button.new()
	restart_btn.text = "  Reiniciar  "
	_btn_style(restart_btn, COL_PANEL, COL_TEXT)
	restart_btn.pressed.connect(_on_restart)
	hbox.add_child(restart_btn)


func _build_log(parent: VBoxContainer):
	var panel := PanelContainer.new()
	_style(panel, COL_PANEL_DARK)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 120
	parent.add_child(panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_color_override("default_color", COL_TEXT)
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(log_label)


func _build_overlay():
	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.8)
	overlay.add_theme_stylebox_override("panel", s)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var inner := PanelContainer.new()
	_style(inner, COL_PANEL, 16, 32)
	inner.custom_minimum_size = Vector2(500, 180)
	center.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(vbox)

	overlay_label = _label("", 26, COL_ACCENT)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(overlay_label)

	var btn := Button.new()
	btn.text = "  Jugar de Nuevo  "
	_btn_style(btn, COL_ACCENT)
	btn.pressed.connect(_on_restart)
	vbox.add_child(btn)


# --- Callbacks ---

func _on_resolve():
	if GameManager.game_over or GameManager.game_won:
		return
	# Close any open action menu
	if selected_char >= 0:
		_close_actions(selected_char)
	GameManager.resolve_turn()


func _on_turn_resolved():
	_update_ui()
	_show_log()


func _on_game_ended(won: bool):
	_update_ui()
	_show_log()
	overlay.visible = true
	if won:
		var survivors := 0
		for c in GameManager.characters:
			if c.is_alive():
				survivors += 1
		overlay_label.text = "La caravana llego!\n%d sobrevivientes en %d noches." % [survivors, GameManager.day]
		overlay_label.add_theme_color_override("font_color", COL_GREEN)
	else:
		overlay_label.text = "Nadie sobrevivio.\nLlegaron a la noche %d." % GameManager.day
		overlay_label.add_theme_color_override("font_color", COL_RED)


func _on_restart():
	GameManager.restart()
	overlay.visible = false
	selected_char = -1
	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]

		# Reset action
		var default_act := _default_action(i)
		c.assigned_action = default_act
		p["action_indicator"].text = _action_display_name(default_act, c)

		# Rebuild action buttons
		var actions_vbox: VBoxContainer = p["actions_vbox"]
		for child in actions_vbox.get_children():
			child.queue_free()
		p["action_buttons"].clear()
		_build_action_buttons(actions_vbox, p["action_buttons"], c, i)

		# Reset visuals
		p["dead_lbl"].visible = false
		p["sprite_overlay"].color = Color(0, 0, 0, 0)
		p["actions_panel"].visible = false
		p["actions_panel"].modulate.a = 0.0
		p["is_selected"] = false
		p["is_hovered"] = false
		p["hover_amount"] = 0.0

		# Reset cursor
		p["char_container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_update_ui()
	_show_intro()


# --- UI Update ---

func _update_ui():
	day_label.text = "Noche %d / %d" % [GameManager.day, GameManager.NIGHTS_TO_SURVIVE]

	food_label.text = "Comida: %d" % GameManager.food
	if GameManager.food <= 2:
		food_label.add_theme_color_override("font_color", COL_RED)
	elif GameManager.food <= 5:
		food_label.add_theme_color_override("font_color", COL_YELLOW)
	else:
		food_label.add_theme_color_override("font_color", COL_GREEN)

	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]

		# State + sprite visual feedback
		var state_lbl: Label = p["state_lbl"]
		var sprite_overlay: ColorRect = p["sprite_overlay"]

		if not c.is_alive():
			state_lbl.text = "MUERTO"
			state_lbl.add_theme_color_override("font_color", COL_RED)
			p["dead_lbl"].text = "MUERTO"
			p["dead_lbl"].visible = true
			sprite_overlay.color = Color(0, 0, 0, 0.6)
			p["char_container"].mouse_default_cursor_shape = Control.CURSOR_ARROW
			# Close actions if this char was selected
			if selected_char == i:
				_close_actions(i)
			# Disable indicator
			p["action_indicator"].text = "---"
			p["action_indicator"].add_theme_color_override("font_color", COL_DIM)
		elif c.is_weak():
			state_lbl.text = "DEBIL"
			state_lbl.add_theme_color_override("font_color", COL_RED)
			sprite_overlay.color = Color(0.4, 0, 0, 0.25)
			# Rebuild action buttons (can't guard when weak)
			var actions_vbox: VBoxContainer = p["actions_vbox"]
			for child in actions_vbox.get_children():
				child.queue_free()
			p["action_buttons"].clear()
			_build_action_buttons(actions_vbox, p["action_buttons"], c, i)
			# Check if current action is still valid
			if c.assigned_action == GameManager.Action.CUIDAR and not c.can_guard():
				c.assigned_action = GameManager.Action.DORMIR
				p["action_indicator"].text = _action_display_name(c.assigned_action, c)
		else:
			state_lbl.text = "Normal"
			state_lbl.add_theme_color_override("font_color", COL_GREEN)
			sprite_overlay.color = Color(0, 0, 0, 0)
			p["action_indicator"].add_theme_color_override("font_color", COL_ACCENT)

		# Sleep
		var sleep_lbl: Label = p["sleep_lbl"]
		if c.nights_awake == 0:
			sleep_lbl.text = "Sueno: OK"
			sleep_lbl.add_theme_color_override("font_color", COL_TEXT)
		else:
			sleep_lbl.text = "Desp: %d" % c.nights_awake
			sleep_lbl.add_theme_color_override("font_color", COL_YELLOW)

		# Food need
		var need_lbl: Label = p["need_lbl"]
		need_lbl.text = "Necesita: %d" % c.get_food_need()
		if c.is_weak():
			need_lbl.add_theme_color_override("font_color", COL_RED)
		else:
			need_lbl.add_theme_color_override("font_color", COL_YELLOW)

		# Food consumption label
		var food_lbl: Label = p["food_lbl"]
		if c.is_weak() and c.is_alive():
			food_lbl.text = "Come:%d+%d" % [c.food_consumption, GameManager.EXTRA_FOOD_WHEN_WEAK]
			food_lbl.add_theme_color_override("font_color", COL_RED)
		else:
			food_lbl.text = "Come:%d" % c.food_consumption
			food_lbl.add_theme_color_override("font_color", COL_DIM)

	resolve_btn.disabled = GameManager.game_over or GameManager.game_won


func _show_intro():
	log_label.clear()
	log_label.append_text("[color=#c19a52]SOBREVIVIR LA PAMPA[/color]\n")
	log_label.append_text("Tres almas en la inmensidad de la pampa.\n")
	log_label.append_text("Sobrevivan %d noches hasta que llegue la caravana.\n\n" % GameManager.NIGHTS_TO_SURVIVE)
	log_label.append_text("[color=#8a7d6a]Hace click en cada personaje para asignar acciones.[/color]\n")
	log_label.append_text("[color=#8a7d6a]CAZAR: produce comida. CUIDAR: reduce riesgo. DORMIR: necesario cada 2 noches.[/color]\n\n")
	log_label.append_text("[color=#c19a52]Asigna acciones y presiona TERMINAR TURNO.[/color]\n")


func _show_log():
	log_label.clear()
	for msg in GameManager.log_messages:
		var colored := msg
		if msg.begins_with("ROBO") or msg.begins_with("ATAQUE"):
			colored = "[color=#cc4444]%s[/color]" % msg
		elif "muere" in msg:
			colored = "[color=#cc4444]%s[/color]" % msg
		elif "debilita" in msg:
			colored = "[color=#cc8833]%s[/color]" % msg
		elif "Noche sin incidentes" in msg:
			colored = "[color=#66aa66]%s[/color]" % msg
		elif msg.begins_with("---"):
			colored = "[color=#c19a52]%s[/color]" % msg
		log_label.append_text(colored + "\n")
