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


static func label(text: String, size: int = 15, color: Color = COL_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


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


static func ghost_btn(btn: Button, fg: Color, size: int = 14):
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


static func solid_btn(btn: Button, bg: Color, fg: Color):
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
