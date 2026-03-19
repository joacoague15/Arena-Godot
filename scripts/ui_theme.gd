extends RefCounted
class_name UITheme

## Shared constants and static helper functions for Sobrevivir la Pampa UI.

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

# --- Character layout: [x, top, width, feet_y_in_sprite, z_index] ---
const CHAR_LAYOUT := [
	[-60, 100, 700, 615, 1],   # Caudillo: left, tall standing
	[640, 110, 660, 615, 1],   # Vigia: right, standing
	[390, 280, 408, 520, 0],   # Curandera: center, seated (behind)
]
const GROUND_Y := 595

# --- Food token config ---
const FOOD_TOKEN_SIZE := 24
const FOOD_TOKEN_GAP := 5
const FOOD_GRID_COLS := 10

# --- Texture styles (editable .tres files in res://resources/) ---
static var _panel_res: StyleBoxTexture = null
static var _btn_normal: StyleBoxTexture = null
static var _btn_hover: StyleBoxTexture = null
static var _btn_pressed: StyleBoxTexture = null
static var _btn_disabled: StyleBoxTexture = null
static var _ghost_normal: StyleBoxTexture = null
static var _ghost_hover: StyleBoxTexture = null
static var _ghost_pressed: StyleBoxTexture = null


static func _ensure_resources():
	if _panel_res == null:
		_panel_res = load("res://resources/panel_style.tres")
	if _btn_normal == null:
		_btn_normal = load("res://resources/button_normal.tres")
		_btn_hover = load("res://resources/button_hover.tres")
		_btn_pressed = load("res://resources/button_pressed.tres")
		_btn_disabled = load("res://resources/button_disabled.tres")
	if _ghost_normal == null:
		_ghost_normal = load("res://resources/ghost_normal.tres")
		_ghost_hover = load("res://resources/ghost_hover.tres")
		_ghost_pressed = load("res://resources/ghost_pressed.tres")


static func label(text: String, size: int = 15, color: Color = COL_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Dark flat bubble (used for small UI: info bubbles, action panels)
static func bubble_style(radius: int = 14, pad: int = 14) -> StyleBoxFlat:
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


## Texture panel (loads from res://resources/panel_style.tres — edit in Godot editor)
static func panel_style(pad: int = 32) -> StyleBoxTexture:
	_ensure_resources()
	var s: StyleBoxTexture = _panel_res.duplicate()
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func ghost_btn(btn: Button, fg: Color, size: int = 14):
	_ensure_resources()
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_stylebox_override("normal", _ghost_normal.duplicate())
	btn.add_theme_stylebox_override("hover", _ghost_hover.duplicate())
	btn.add_theme_stylebox_override("pressed", _ghost_pressed.duplicate())


## Texture button (loads from res://resources/button_*.tres — edit in Godot editor)
static func solid_btn(btn: Button, _bg: Color, fg: Color):
	_ensure_resources()
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_stylebox_override("normal", _btn_normal.duplicate())
	btn.add_theme_stylebox_override("hover", _btn_hover.duplicate())
	btn.add_theme_stylebox_override("pressed", _btn_pressed.duplicate())
	btn.add_theme_stylebox_override("disabled", _btn_disabled.duplicate())
	btn.add_theme_color_override("font_disabled_color", fg.darkened(0.4))


static func load_sprite_frames(char_name: String) -> Array:
	var frames: Array = []
	var folder: String = SPRITE_FOLDERS.get(char_name, "")
	if folder == "":
		return frames
	for i in range(SPRITE_FRAME_COUNT):
		var path := "%sframe_%02d.png" % [folder, i]
		if ResourceLoader.exists(path):
			frames.append(load(path))
	return frames
