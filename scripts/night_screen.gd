extends ColorRect
class_name NightScreenUI

## Night resolution screen — shows event log, continue to next day.

signal screen_done

var panel: PanelContainer
var log_rtl: RichTextLabel
var continue_btn: Button
var is_active := false


func build():
	color = Color(0.04, 0.03, 0.02)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(36))
	panel.custom_minimum_size = Vector2(500, 280)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true
	log_rtl.scroll_following = true
	log_rtl.fit_content = true
	log_rtl.add_theme_color_override("default_color", UITheme.COL_BONE)
	log_rtl.add_theme_font_size_override("normal_font_size", 14)
	log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_rtl.custom_minimum_size.y = 160
	vbox.add_child(log_rtl)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.06)
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

	continue_btn = Button.new()
	continue_btn.text = "COMENZAR SIGUIENTE DIA"
	continue_btn.custom_minimum_size = Vector2(280, 48)
	UITheme.solid_btn(continue_btn, UITheme.COL_GOLD.darkened(0.2), Color(0.95, 0.92, 0.85))
	continue_btn.pressed.connect(_on_continue)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(continue_btn)


func show_screen():
	is_active = true
	visible = true
	modulate.a = 0.0
	_populate_log()
	panel.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 1.0, 0.6)
	tween.tween_interval(0.15)
	tween.tween_callback(_animate_panel_in)


func _animate_panel_in():
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)


func _populate_log():
	log_rtl.clear()
	for msg in GameManager.log_messages:
		if msg == "":
			log_rtl.append_text("\n")
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
		elif "cuida el campamento" in msg or "cuida debilitado" in msg:
			colored = "[color=#bb9944]%s[/color]" % msg
		elif "Noche sin incidentes" in msg or "no detecto amenazas" in msg:
			colored = "[color=#557744]%s[/color]" % msg
		elif msg.begins_with("---"):
			colored = "[color=#9e8052][b]%s[/b][/color]" % msg
		elif "Total cazado" in msg:
			colored = "[color=#9e8852]%s[/color]" % msg
		log_rtl.append_text(colored + "\n")

	if GameManager.game_won or GameManager.game_over:
		continue_btn.text = "VER RESULTADO"
	else:
		continue_btn.text = "COMENZAR SIGUIENTE DIA"


func _on_continue():
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		visible = false
		is_active = false
		screen_done.emit()
	)


func reset():
	visible = false
	is_active = false
