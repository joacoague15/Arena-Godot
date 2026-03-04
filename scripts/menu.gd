extends Control

## Sobrevivir la Pampa - Menu Principal
## Video: convert your mp4 to .ogv and place at VIDEO_PATH below.
## Music: place your audio at MUSIC_PATH below.

const COL_BG := Color(0.08, 0.06, 0.04)
const COL_ACCENT := Color(0.76, 0.60, 0.32)
const COL_TEXT := Color(0.90, 0.85, 0.75)
const COL_DIM := Color(0.55, 0.50, 0.43)

## --- CONFIG ---
## Video background (.ogv):  ffmpeg -i video.mp4 -codec:v libtheora -q:v 7 menu_bg.ogv
const VIDEO_PATH := "res://video/menu_bg.ogv"
## Music (.ogg / .wav / .mp3):
const MUSIC_PATH := "res://music/menu_theme.ogg"
const FADE_OUT_DURATION := 1.5  # seconds

var video_player: VideoStreamPlayer
var music_player: AudioStreamPlayer
var fade_tween: Tween


func _ready():
	# --- Dark background fallback (shows while video loads or if missing) ---
	var bg_color := ColorRect.new()
	bg_color.color = COL_BG
	bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_color)

	# --- Video background ---
	video_player = VideoStreamPlayer.new()
	video_player.name = "VideoBackground"
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.loop = true
	# Mute the video audio (we use our own music player)
	video_player.volume_db = -80.0
	add_child(video_player)
	_try_play_video()

	# --- Dark overlay to make text readable ---
	var dark_overlay := ColorRect.new()
	dark_overlay.color = Color(0, 0, 0, 0.45)
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark_overlay)

	# --- Music (separate from video) ---
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	music_player.volume_db = 0.0
	add_child(music_player)
	_try_play_music()

	# --- Centered content ---
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SOBREVIVIR\nLA PAMPA"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Cuatro almas. Diez noches. Una pampa infinita."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", COL_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	vbox.add_child(spacer)

	# Comenzar button
	var btn := Button.new()
	btn.text = "  COMENZAR  "
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", COL_BG)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = COL_ACCENT
	style_normal.set_corner_radius_all(10)
	style_normal.content_margin_left = 48
	style_normal.content_margin_right = 48
	style_normal.content_margin_top = 16
	style_normal.content_margin_bottom = 16
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	style_hover.bg_color = COL_ACCENT.lightened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = COL_ACCENT.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_comenzar)
	vbox.add_child(btn)


func _try_play_video():
	if ResourceLoader.exists(VIDEO_PATH):
		video_player.stream = load(VIDEO_PATH)
		video_player.play()
	else:
		push_warning("Menu video not found at: %s — add your .ogv file there." % VIDEO_PATH)


func _try_play_music():
	if ResourceLoader.exists(MUSIC_PATH):
		music_player.stream = load(MUSIC_PATH)
		music_player.play()
	else:
		push_warning("Menu music not found at: %s — add your audio file there." % MUSIC_PATH)


func _on_comenzar():
	# Fade out music + video, then change scene
	fade_tween = create_tween()
	fade_tween.set_parallel(true)

	if music_player.playing:
		fade_tween.tween_property(music_player, "volume_db", -40.0, FADE_OUT_DURATION)

	if video_player.is_playing():
		# Fade video to black via modulate alpha
		fade_tween.tween_property(video_player, "modulate:a", 0.0, FADE_OUT_DURATION)

	fade_tween.set_parallel(false)
	fade_tween.tween_callback(_go_to_game)


func _go_to_game():
	music_player.stop()
	video_player.stop()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
