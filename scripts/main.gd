extends Control

## Sobrevivir la Pampa - Main UI
## Minimal, clear, everything built in code.

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

const ACTION_LABELS := ["Cazar", "Cuidar", "Dormir"]

# --- UI Refs ---
var day_label: Label
var food_label: Label
var resolve_btn: Button
var log_label: RichTextLabel
var overlay: PanelContainer
var overlay_label: Label
var char_panels: Array = []  # Array of Dictionaries


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
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_build_top_bar(vbox)
	_build_characters(vbox)
	_build_buttons(vbox)
	_build_log(vbox)
	_build_overlay()

	GameManager.turn_resolved.connect(_on_turn_resolved)
	GameManager.game_ended.connect(_on_game_ended)

	_update_ui()
	_show_intro()


func _build_top_bar(parent: VBoxContainer):
	var panel := PanelContainer.new()
	_style(panel, COL_PANEL)
	parent.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var title := _label("SOBREVIVIR LA PAMPA", 22, COL_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	day_label = _label("Noche 1 / 10", 18)
	hbox.add_child(day_label)

	hbox.add_child(_label("|", 18, COL_DIM))

	food_label = _label("Comida: 10", 18, COL_YELLOW)
	hbox.add_child(food_label)


func _build_characters(parent: VBoxContainer):
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)

	for i in range(4):
		var data := _build_char_panel(hbox, i)
		char_panels.append(data)


func _build_char_panel(parent: HBoxContainer, idx: int) -> Dictionary:
	var c: GameManager.Character = GameManager.characters[idx]

	var panel := PanelContainer.new()
	_style(panel, COL_PANEL)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Color bar
	var bar := ColorRect.new()
	bar.color = c.color
	bar.custom_minimum_size.y = 5
	vbox.add_child(bar)

	# Name
	var name_lbl := _label(c.char_name, 20, c.color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Separator
	var sep := ColorRect.new()
	sep.color = COL_DIM
	sep.custom_minimum_size.y = 1
	vbox.add_child(sep)

	# Stats
	var food_lbl := _label("Come: %d / dia" % c.food_consumption, 13, COL_DIM)
	vbox.add_child(food_lbl)

	var hunt_text := "Caza: +%d" % c.hunt_yield if c.hunt_yield > 0 else "Caza: --"
	var hunt_lbl := _label(hunt_text, 13, COL_DIM)
	vbox.add_child(hunt_lbl)

	var guard_text := "Guardia: -%d%%" % int(c.guard_reduction * 100) if c.guard_reduction > 0 else "Guardia: --"
	var guard_lbl := _label(guard_text, 13, COL_DIM)
	vbox.add_child(guard_lbl)

	# Separator
	var sep2 := ColorRect.new()
	sep2.color = COL_DIM
	sep2.custom_minimum_size.y = 1
	vbox.add_child(sep2)

	# State
	var state_lbl := _label("Estado: Normal", 14, COL_GREEN)
	vbox.add_child(state_lbl)

	# Sleep
	var sleep_lbl := _label("Despierto: 0 noches", 13, COL_TEXT)
	vbox.add_child(sleep_lbl)

	# Food need (dynamic)
	var need_lbl := _label("Necesita: %d comida" % c.get_food_need(), 13, COL_YELLOW)
	vbox.add_child(need_lbl)

	# Separator
	var sep3 := ColorRect.new()
	sep3.color = COL_DIM
	sep3.custom_minimum_size.y = 1
	vbox.add_child(sep3)

	# Action selector
	vbox.add_child(_label("Accion:", 14))

	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 16)
	_populate_actions(opt, c)

	# Default action
	var default_act := _default_action(idx)
	c.assigned_action = default_act
	# Find the item index matching our default action
	for j in range(opt.item_count):
		if opt.get_item_id(j) == default_act:
			opt.selected = j
			break

	opt.item_selected.connect(_on_action_selected.bind(idx))
	vbox.add_child(opt)

	# Dead overlay label
	var dead_lbl := _label("", 22, COL_RED)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_lbl.visible = false
	vbox.add_child(dead_lbl)

	return {
		"panel": panel,
		"color_bar": bar,
		"state_lbl": state_lbl,
		"sleep_lbl": sleep_lbl,
		"need_lbl": need_lbl,
		"food_lbl": food_lbl,
		"opt": opt,
		"dead_lbl": dead_lbl,
	}


func _populate_actions(opt: OptionButton, c: GameManager.Character):
	opt.clear()
	# Always add DORMIR
	# Add CAZAR if possible
	if c.can_hunt():
		opt.add_item("Cazar (+%d)" % c.hunt_yield, GameManager.Action.CAZAR)
	if c.can_guard():
		opt.add_item("Cuidar (-%d%%)" % int(c.guard_reduction * 100), GameManager.Action.CUIDAR)
	opt.add_item("Dormir", GameManager.Action.DORMIR)


func _default_action(idx: int) -> int:
	match idx:
		0: return GameManager.Action.CAZAR     # Caudillo hunts
		1: return GameManager.Action.CAZAR     # Gaucho hunts
		2: return GameManager.Action.CUIDAR    # Vigia guards
		3: return GameManager.Action.DORMIR    # Curandera sleeps
	return GameManager.Action.DORMIR


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
	panel.custom_minimum_size.y = 160
	parent.add_child(panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_color_override("default_color", COL_TEXT)
	log_label.add_theme_font_size_override("normal_font_size", 14)
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

func _on_action_selected(item_index: int, char_idx: int):
	var opt: OptionButton = char_panels[char_idx]["opt"]
	var action_id := opt.get_item_id(item_index)
	GameManager.characters[char_idx].assigned_action = action_id


func _on_resolve():
	if GameManager.game_over or GameManager.game_won:
		return
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
	# Rebuild action dropdowns (states reset)
	for i in range(4):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]
		var opt: OptionButton = p["opt"]
		_populate_actions(opt, c)
		var default_act := _default_action(i)
		c.assigned_action = default_act
		for j in range(opt.item_count):
			if opt.get_item_id(j) == default_act:
				opt.selected = j
				break
		p["dead_lbl"].visible = false
		p["color_bar"].color = c.color
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

	for i in range(4):
		var c: GameManager.Character = GameManager.characters[i]
		var p: Dictionary = char_panels[i]

		# State
		var state_lbl: Label = p["state_lbl"]
		if not c.is_alive():
			state_lbl.text = "Estado: MUERTO"
			state_lbl.add_theme_color_override("font_color", COL_RED)
			p["dead_lbl"].text = "MUERTO"
			p["dead_lbl"].visible = true
			p["opt"].disabled = true
			p["color_bar"].color = COL_DIM
		elif c.is_weak():
			state_lbl.text = "Estado: DEBIL"
			state_lbl.add_theme_color_override("font_color", COL_RED)
			# Refresh actions (can't guard when weak)
			var opt: OptionButton = p["opt"]
			_populate_actions(opt, c)
			# Keep current action or fall back to DORMIR
			var found := false
			for j in range(opt.item_count):
				if opt.get_item_id(j) == c.assigned_action:
					opt.selected = j
					found = true
					break
			if not found:
				c.assigned_action = GameManager.Action.DORMIR
				for j in range(opt.item_count):
					if opt.get_item_id(j) == GameManager.Action.DORMIR:
						opt.selected = j
						break
		else:
			state_lbl.text = "Estado: Normal"
			state_lbl.add_theme_color_override("font_color", COL_GREEN)

		# Sleep
		var sleep_lbl: Label = p["sleep_lbl"]
		if c.nights_awake == 0:
			sleep_lbl.text = "Despierto: 0 noches"
			sleep_lbl.add_theme_color_override("font_color", COL_TEXT)
		else:
			sleep_lbl.text = "Despierto: %d noche/s" % c.nights_awake
			sleep_lbl.add_theme_color_override("font_color", COL_YELLOW)

		# Food need
		var need_lbl: Label = p["need_lbl"]
		need_lbl.text = "Necesita: %d comida" % c.get_food_need()
		if c.is_weak():
			need_lbl.add_theme_color_override("font_color", COL_RED)
		else:
			need_lbl.add_theme_color_override("font_color", COL_YELLOW)

		# Food consumption label update for weak
		var food_lbl: Label = p["food_lbl"]
		if c.is_weak() and c.is_alive():
			food_lbl.text = "Come: %d+%d / dia (debil)" % [c.food_consumption, GameManager.EXTRA_FOOD_WHEN_WEAK]
			food_lbl.add_theme_color_override("font_color", COL_RED)
		else:
			food_lbl.text = "Come: %d / dia" % c.food_consumption
			food_lbl.add_theme_color_override("font_color", COL_DIM)

	resolve_btn.disabled = GameManager.game_over or GameManager.game_won


func _show_intro():
	log_label.clear()
	log_label.append_text("[color=#c19a52]SOBREVIVIR LA PAMPA[/color]\n")
	log_label.append_text("Cuatro almas en la inmensidad de la pampa.\n")
	log_label.append_text("Sobrevivan %d noches hasta que llegue la caravana.\n\n" % GameManager.NIGHTS_TO_SURVIVE)
	log_label.append_text("[color=#8a7d6a]CAZAR: produce comida, pero no protege ni descansa.\n")
	log_label.append_text("CUIDAR: reduce chance de eventos, pero no produce ni descansa.\n")
	log_label.append_text("DORMIR: necesario cada 2 noches, pero no produce ni protege.[/color]\n\n")
	log_label.append_text("[color=#c19a52]Asigna acciones y presiona TERMINAR TURNO.[/color]\n")


func _show_log():
	log_label.clear()
	for msg in GameManager.log_messages:
		# Color code certain keywords
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
