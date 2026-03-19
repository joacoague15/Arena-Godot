extends Control

## Sobrevivir la Pampa - Main UI
## Minimalist gothic. Dirt white canvas. Characters ARE the interface.
## Everything hidden until hover/click reveals dark floating bubbles.
## Food distribution via click-to-pick, click-to-drop.

# --- UI Refs ---
var day_label: Label
var food_label: Label
var resolve_btn: Button
var game_layer: Control
var bg_texture: TextureRect
var char_panels: Array = []

# --- Sub-screens ---
var food_screen: FoodScreenUI
var night_screen: NightScreenUI

# --- Overlay ---
var overlay: PanelContainer
var overlay_label: Label

# --- Energy HUD ---
var energy_icons: Array = []  # Array of TextureRect
var energy_tooltip: PanelContainer
var energy_tooltip_label: Label

# --- Cure Targeting Refs ---
var cure_preview: PanelContainer
var cure_hint_label: Label

# --- State ---
var sprite_time := 0.0
var selected_char := -1
var actions_confirmed: Array = []
var cure_targeting := false
var cure_source_idx := -1


# =============================================
# BUILD
# =============================================

func _ready():
	var bg := ColorRect.new()
	bg.color = UITheme.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Background image (pampa landscape)
	bg_texture = TextureRect.new()
	bg_texture.texture = load("res://sprites/background.png")
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_texture)

	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)

	_build_hud()
	_build_characters()
	_build_bottom_bar()

	# Food distribution screen
	food_screen = FoodScreenUI.new()
	food_screen.build()
	add_child(food_screen)
	food_screen.confirmed.connect(_on_food_confirmed)

	# Night screen
	night_screen = NightScreenUI.new()
	night_screen.build()
	add_child(night_screen)
	night_screen.screen_done.connect(_on_night_screen_hidden)

	_build_overlay()

	# Cure targeting preview
	cure_preview = PanelContainer.new()
	var cure_style := StyleBoxFlat.new()
	cure_style.bg_color = UITheme.COL_DUSK.lightened(0.2)
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
	cure_hint_label = UITheme.label("", 13, UITheme.COL_DUSK.lightened(0.4))
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
	var cycle_length := (UITheme.SPRITE_FRAME_COUNT * 2) - 2
	if cycle_length <= 0:
		return
	var pos := int(sprite_time * UITheme.SPRITE_FPS) % cycle_length
	var frame_index: int
	if pos < UITheme.SPRITE_FRAME_COUNT:
		frame_index = pos
	else:
		frame_index = cycle_length - pos

	for p in char_panels:
		var frames: Array = p["sprite_frames"]
		var tex_rect: TextureRect = p["sprite_rect"]
		if frames.size() > 0:
			tex_rect.texture = frames[frame_index % frames.size()]

	_process_hover(delta)

	# Food screen drag preview + zone highlights
	food_screen.process_tick()

	# Cure preview follows mouse
	if cure_targeting and cure_preview.visible:
		var cp := get_viewport().get_mouse_position()
		cure_preview.position = cp + Vector2(16, 8)


func _unhandled_input(event: InputEvent):
	# Cancel cure targeting with right-click
	if cure_targeting:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_cure_targeting()
			get_viewport().set_input_as_handled()
			return

	# Cancel food carry with right-click
	if food_screen.active and food_screen.carrying:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			food_screen.cancel_carry()
			get_viewport().set_input_as_handled()
			return

	if food_screen.active or night_screen.is_active:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_char >= 0:
			var p: Dictionary = char_panels[selected_char]
			var sprite_area: Control = p["sprite_rect"]
			var actions_panel: Control = p["actions_panel"]
			if not sprite_area.get_global_rect().has_point(event.position) and not actions_panel.get_global_rect().has_point(event.position):
				_close_actions(selected_char)


# =============================================
# HUD
# =============================================

func _build_hud():
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox.offset_left = 30
	hbox.offset_right = -30
	hbox.offset_top = 16
	hbox.offset_bottom = 50
	hbox.add_theme_constant_override("separation", 20)
	game_layer.add_child(hbox)

	day_label = UITheme.label("NOCHE 1", 13, UITheme.COL_INK_SOFT)
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(day_label)

	food_label = UITheme.label("COMIDA: 10", 13, UITheme.COL_INK_SOFT)
	food_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(food_label)

	# Energy icons (top-right)
	var energy_container := HBoxContainer.new()
	energy_container.add_theme_constant_override("separation", 4)
	hbox.add_child(energy_container)

	var energy_tex := load("res://sprites/energy.png")
	for i in range(3):
		var icon := TextureRect.new()
		icon.texture = energy_tex
		icon.custom_minimum_size = Vector2(70, 70)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_entered.connect(_on_energy_hover_enter)
		icon.mouse_exited.connect(_on_energy_hover_exit)
		energy_container.add_child(icon)
		energy_icons.append(icon)

	# Energy tooltip (hidden by default)
	energy_tooltip = PanelContainer.new()
	energy_tooltip.add_theme_stylebox_override("panel", UITheme.bubble_style(8, 6))
	energy_tooltip.visible = false
	energy_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_tooltip.z_index = 100
	energy_tooltip_label = UITheme.label("", 11, UITheme.COL_BONE)
	energy_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_tooltip.add_child(energy_tooltip_label)
	add_child(energy_tooltip)


# =============================================
# CHARACTERS
# =============================================

func _build_characters():
	for i in range(GameManager.characters.size()):
		var data := _build_char(i)
		char_panels.append(data)


func _build_char(idx: int) -> Dictionary:
	var c: GameManager.Character = GameManager.characters[idx]
	var layout = UITheme.CHAR_LAYOUT[idx]
	var lx: int = layout[0]
	var ly: int = layout[1]
	var lw: int = layout[2]
	var feet_y: int = layout[3]
	var lz: int = layout[4]
	var lh: int = 660 - ly  # container extends to just above bottom bar

	var container := Control.new()
	container.position = Vector2(lx, ly)
	container.size = Vector2(lw, lh)
	container.z_index = lz
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	game_layer.add_child(container)

	# Sprite: manually sized and positioned for ground alignment
	var scale_f := float(lw) / 1280.0
	var sprite_h := int(720.0 * scale_f)
	var ground_in_container := UITheme.GROUND_Y - ly
	var feet_in_sprite := int(float(feet_y) * scale_f)
	var sprite_y := ground_in_container - feet_in_sprite

	var sprite_rect := TextureRect.new()
	sprite_rect.position = Vector2(0, sprite_y)
	sprite_rect.size = Vector2(lw, sprite_h)
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sprite_rect)

	var frames := UITheme.load_sprite_frames(c.char_name)
	if frames.size() > 0:
		sprite_rect.texture = frames[0]

	# Overlay matches sprite position for tinting (dead/weak)
	var sprite_overlay := ColorRect.new()
	sprite_overlay.position = Vector2(0, sprite_y)
	sprite_overlay.size = Vector2(lw, sprite_h)
	sprite_overlay.color = Color(0, 0, 0, 0)
	sprite_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sprite_overlay)

	var dead_lbl := UITheme.label("", 32, UITheme.COL_BLOOD)
	dead_lbl.set_anchors_preset(Control.PRESET_CENTER)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_lbl.visible = false
	container.add_child(dead_lbl)

	var state_lbl := UITheme.label("Normal", 11, UITheme.COL_MOSS)
	state_lbl.visible = false
	var need_lbl := UITheme.label("Necesita: %d" % c.get_food_need(), 10, UITheme.COL_WARN)
	need_lbl.visible = false
	var food_lbl := UITheme.label("Come: %d" % c.food_consumption, 11, UITheme.COL_BONE)
	food_lbl.visible = false

	c.assigned_action = -1

	# Actions bubble
	var actions_panel := PanelContainer.new()
	actions_panel.add_theme_stylebox_override("panel", UITheme.bubble_style(14, 10))
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
		"state_lbl": state_lbl,
		"need_lbl": need_lbl,
		"food_lbl": food_lbl,
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
		btn.custom_minimum_size = Vector2(140, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.ghost_btn(btn, UITheme.COL_MOSS)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.CAZAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CAZAR})

	if c.can_faenar():
		var btn := Button.new()
		btn.text = "FAENAR"
		btn.custom_minimum_size = Vector2(140, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.ghost_btn(btn, UITheme.COL_BLOOD)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.FAENAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.FAENAR})

	if c.can_curar():
		var btn := Button.new()
		btn.text = "CURAR"
		btn.custom_minimum_size = Vector2(140, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.ghost_btn(btn, UITheme.COL_DUSK.lightened(0.3))
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.CURAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.CURAR})

	if c.can_rastrear():
		var btn := Button.new()
		btn.text = "RASTREAR"
		btn.custom_minimum_size = Vector2(140, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.ghost_btn(btn, UITheme.COL_WARN)
		btn.pressed.connect(_on_action_btn_pressed.bind(idx, GameManager.Action.RASTREAR))
		parent.add_child(btn)
		buttons_array.append({"btn": btn, "action": GameManager.Action.RASTREAR})


# =============================================
# BOTTOM BAR
# =============================================

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
	resolve_btn.custom_minimum_size = Vector2(220, 48)
	UITheme.solid_btn(resolve_btn, UITheme.COL_INK, UITheme.COL_BG)
	resolve_btn.pressed.connect(_on_resolve)
	hbox.add_child(resolve_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Reiniciar"
	restart_btn.custom_minimum_size = Vector2(120, 40)
	UITheme.ghost_btn(restart_btn, UITheme.COL_INK_SOFT, 12)
	restart_btn.pressed.connect(_on_restart)
	hbox.add_child(restart_btn)


# =============================================
# ENERGY ICONS
# =============================================

func _get_pending_actions() -> int:
	var pending := 0
	for i in range(GameManager.characters.size()):
		if GameManager.characters[i].is_alive() and not actions_confirmed[i]:
			pending += 1
	return pending


func _update_energy_icons():
	var pending := _get_pending_actions()
	for i in range(energy_icons.size()):
		var icon: TextureRect = energy_icons[i]
		if i < pending:
			# Full energy — remaining action
			icon.modulate.a = 1.0
		elif i < 3:
			# Spent energy — very faded
			icon.modulate.a = 0.15
		else:
			icon.modulate.a = 0.15


func _on_energy_hover_enter():
	var pending := _get_pending_actions()
	energy_tooltip_label.text = "%d acciones restantes" % pending
	energy_tooltip.visible = true
	# Position near top-right
	var vp := get_viewport().get_mouse_position()
	energy_tooltip.position = vp + Vector2(-120, 30)


func _on_energy_hover_exit():
	energy_tooltip.visible = false


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
	_update_energy_icons()
	if GameManager.game_over or GameManager.game_won:
		resolve_btn.disabled = true
		return
	if _all_actions_confirmed():
		resolve_btn.disabled = false
		resolve_btn.text = "TERMINAR TURNO"
	else:
		resolve_btn.disabled = true
		var pending := _get_pending_actions()
		resolve_btn.text = "ASIGNA ACCIONES  (%d)" % pending


# =============================================
# HOVER & CLICK
# =============================================

func _on_char_hover_enter(idx: int):
	if GameManager.characters[idx].is_alive() and not night_screen.is_active and not food_screen.active:
		char_panels[idx]["is_hovered"] = true
		if cure_targeting:
			char_panels[idx]["container"].mouse_default_cursor_shape = Control.CURSOR_CROSS

func _on_char_hover_exit(idx: int):
	char_panels[idx]["is_hovered"] = false
	if cure_targeting:
		char_panels[idx]["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process_hover(_delta: float):
	for i in range(char_panels.size()):
		var p: Dictionary = char_panels[i]
		var alive = GameManager.characters[i].is_alive()
		var target := 0.0
		if (p["is_hovered"] or p["is_selected"]) and alive:
			target = 1.0

		p["hover_amount"] = lerpf(p["hover_amount"], target, 0.12)

		var sprite: TextureRect = p["sprite_rect"]
		var s := lerpf(1.0, 1.015, p["hover_amount"])
		sprite.pivot_offset = sprite.size / 2.0
		sprite.scale = Vector2(s, s)


func _on_char_gui_input(event: InputEvent, idx: int):
	if night_screen.is_active or food_screen.active:
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
		# Action already consumed — can't reopen
		if actions_confirmed[idx]:
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
	GameManager.apply_immediate_cure(cure_source_idx, target_idx)
	actions_confirmed[cure_source_idx] = true

	cure_targeting = false
	cure_source_idx = -1
	cure_preview.visible = false
	cure_hint_label.visible = false
	for i in range(char_panels.size()):
		if GameManager.characters[i].is_alive():
			char_panels[i]["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_update_ui()
	_update_resolve_btn()


func _cancel_cure_targeting():
	cure_targeting = false
	cure_source_idx = -1
	cure_preview.visible = false
	cure_hint_label.visible = false
	for i in range(char_panels.size()):
		if GameManager.characters[i].is_alive():
			char_panels[i]["container"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# =============================================
# OVERLAY (game end)
# =============================================

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
	inner.add_theme_stylebox_override("panel", UITheme.panel_style(40))
	inner.custom_minimum_size = Vector2(420, 160)
	center.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(vbox)

	overlay_label = UITheme.label("", 22, UITheme.COL_BONE)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(overlay_label)

	var btn := Button.new()
	btn.text = "JUGAR DE NUEVO"
	btn.custom_minimum_size = Vector2(220, 48)
	UITheme.solid_btn(btn, UITheme.COL_INK_SOFT, UITheme.COL_BG)
	btn.pressed.connect(_on_restart)
	vbox.add_child(btn)


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
		overlay_label.add_theme_color_override("font_color", UITheme.COL_MOSS)
	else:
		overlay_label.text = "Nadie sobrevivio.\nNoche %d." % GameManager.day
		overlay_label.add_theme_color_override("font_color", UITheme.COL_BLOOD)


# =============================================
# CALLBACKS
# =============================================

func _on_resolve():
	if GameManager.game_over or GameManager.game_won or night_screen.is_active or food_screen.active or cure_targeting:
		return
	if selected_char >= 0:
		_close_actions(selected_char)

	# Fade out background and characters
	var bg_tw := create_tween()
	bg_tw.set_ease(Tween.EASE_IN_OUT)
	bg_tw.set_trans(Tween.TRANS_SINE)
	bg_tw.tween_property(bg_texture, "modulate:a", 0.0, 0.35)
	bg_tw.parallel().tween_property(game_layer, "modulate:a", 0.0, 0.35)

	# Show food distribution
	food_screen.show_screen()


func _on_food_confirmed():
	GameManager.resolve_turn()


func _on_turn_resolved():
	_update_ui()
	night_screen.show_screen()


func _on_game_ended(_won: bool):
	_update_ui()
	night_screen.show_screen()


func _on_night_screen_hidden():
	if GameManager.game_won or GameManager.game_over:
		_show_end_overlay()
	else:
		# Fade background and characters back in
		var bg_tw := create_tween()
		bg_tw.set_ease(Tween.EASE_OUT)
		bg_tw.set_trans(Tween.TRANS_SINE)
		bg_tw.tween_property(bg_texture, "modulate:a", 1.0, 0.5)
		bg_tw.parallel().tween_property(game_layer, "modulate:a", 1.0, 0.5)

		actions_confirmed.fill(false)
		GameManager.cure_target = -1
		GameManager.food_produced.fill(0)
		GameManager.guarding.fill(false)
		GameManager.hunt_log_msgs.clear()
		for i in range(GameManager.characters.size()):
			var c: GameManager.Character = GameManager.characters[i]
			var p: Dictionary = char_panels[i]
			if c.is_alive():
				c.assigned_action = -1
				var actions_vbox: VBoxContainer = p["actions_vbox"]
				for child in actions_vbox.get_children():
					child.queue_free()
				p["action_buttons"].clear()
				_build_action_buttons(actions_vbox, p["action_buttons"], c, i)
		_update_resolve_btn()


func _on_restart():
	GameManager.restart()
	overlay.visible = false
	food_screen.reset()
	night_screen.reset()
	bg_texture.modulate.a = 1.0
	game_layer.modulate.a = 1.0
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
		food_label.add_theme_color_override("font_color", UITheme.COL_BLOOD)
	elif GameManager.food <= 5:
		food_label.add_theme_color_override("font_color", UITheme.COL_WARN)
	else:
		food_label.add_theme_color_override("font_color", UITheme.COL_INK_SOFT)

	for i in range(GameManager.characters.size()):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]

		var state_lbl: Label = p["state_lbl"]
		var sprite_overlay: ColorRect = p["sprite_overlay"]

		if not c.is_alive():
			state_lbl.text = "Muerto"
			state_lbl.add_theme_color_override("font_color", UITheme.COL_BLOOD)
			p["dead_lbl"].text = "MUERTO"
			p["dead_lbl"].visible = true
			sprite_overlay.color = Color(0, 0, 0, 0.55)
			p["container"].mouse_default_cursor_shape = Control.CURSOR_ARROW
			if selected_char == i:
				_close_actions(i)
		elif c.is_weak():
			state_lbl.text = "Debil"
			state_lbl.add_theme_color_override("font_color", UITheme.COL_BLOOD)
			sprite_overlay.color = Color(0.3, 0, 0, 0.15)
			var actions_vbox: VBoxContainer = p["actions_vbox"]
			for child in actions_vbox.get_children():
				child.queue_free()
			p["action_buttons"].clear()
			_build_action_buttons(actions_vbox, p["action_buttons"], c, i)
			var needs_reset := false
			if c.assigned_action == GameManager.Action.FAENAR and not c.can_faenar():
				needs_reset = true
			if needs_reset:
				GameManager._undo_immediate_action(i)
				c.assigned_action = -1
				actions_confirmed[i] = false
		else:
			state_lbl.text = "Normal"
			state_lbl.add_theme_color_override("font_color", UITheme.COL_MOSS)
			sprite_overlay.color = Color(0, 0, 0, 0)

		var need_lbl: Label = p["need_lbl"]
		var guard_note = " (+2 guardia)" if c.guarded_last_turn else ""
		need_lbl.text = "Necesita: %d%s" % [c.get_food_need(), guard_note]
		if c.is_weak():
			need_lbl.add_theme_color_override("font_color", UITheme.COL_BLOOD)
		else:
			need_lbl.add_theme_color_override("font_color", UITheme.COL_WARN)

		var food_lbl: Label = p["food_lbl"]
		if c.is_weak() and c.is_alive():
			food_lbl.text = "Come: %d+%d" % [c.food_consumption, GameManager.EXTRA_FOOD_WHEN_WEAK]
			food_lbl.add_theme_color_override("font_color", UITheme.COL_BLOOD)
		else:
			food_lbl.text = "Come: %d" % c.food_consumption
			food_lbl.add_theme_color_override("font_color", UITheme.COL_BONE)

	_update_resolve_btn()
