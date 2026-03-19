extends Control

## Sobrevivir la Pampa - Menu Principal
## Two video players for smooth crossfade transitions.

const COL_BG := Color(0.08, 0.06, 0.04)
const COL_ACCENT := Color(0.76, 0.60, 0.32)
const COL_TEXT := Color(0.90, 0.85, 0.75)
const COL_DIM := Color(0.55, 0.50, 0.43)

## --- CONFIG ---
const VIDEO_PATHS := [
	"res://video/menu_bg.ogv",
	"res://video/menu_bg_2.ogv",
]
const MUSIC_PATH := "res://music/menu_bg.wav"
const CROSSFADE_DURATION := 1.5   # seconds between videos
const FADE_OUT_DURATION := 1.5    # seconds when pressing COMENZAR

# Two video players for crossfade (A on bottom, B on top)
var video_a: VideoStreamPlayer
var video_b: VideoStreamPlayer
var active_player: VideoStreamPlayer  # which one is currently visible
var music_player: AudioStreamPlayer
var fade_tween: Tween
var crossfade_tween: Tween
var current_video_index := 0
var dark_overlay: ColorRect


func _ready():
	# --- Dark background fallback ---
	var bg_color := ColorRect.new()
	bg_color.color = COL_BG
	bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_color)

	# --- Video player A (bottom layer) ---
	video_a = _create_video_player("VideoA")
	add_child(video_a)

	# --- Video player B (top layer, for crossfade) ---
	video_b = _create_video_player("VideoB")
	video_b.modulate.a = 0.0
	add_child(video_b)

	# Start first video on player A
	active_player = video_a
	_load_and_play(video_a, 0)

	# --- Dark overlay ---
	dark_overlay = ColorRect.new()
	dark_overlay.color = Color(0, 0, 0, 0.45)
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark_overlay)

	# --- Music ---
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

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "  COMENZAR  "
	btn.custom_minimum_size = Vector2(300, 120)
	UITheme.solid_btn(btn, COL_ACCENT, COL_BG)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_comenzar)
	vbox.add_child(btn)


func _create_video_player(node_name: String) -> VideoStreamPlayer:
	var vp := VideoStreamPlayer.new()
	vp.name = node_name
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.expand = true
	vp.loop = false
	vp.volume_db = -80.0
	vp.finished.connect(_on_video_finished.bind(vp))
	return vp


func _load_and_play(player: VideoStreamPlayer, index: int):
	var path: String = VIDEO_PATHS[index]
	if ResourceLoader.exists(path):
		player.stream = load(path)
		player.play()
	else:
		push_warning("Video not found: %s" % path)


func _on_video_finished(finished_player: VideoStreamPlayer):
	# The finished player is the active one. Crossfade to the other.
	var next_index := (current_video_index + 1) % VIDEO_PATHS.size()
	current_video_index = next_index

	# Determine which player is the incoming one
	var incoming: VideoStreamPlayer
	if finished_player == video_a:
		incoming = video_b
	else:
		incoming = video_a

	# Load and start the next video on the incoming player
	_load_and_play(incoming, next_index)

	# Crossfade: fade in incoming, fade out finished
	if crossfade_tween and crossfade_tween.is_running():
		crossfade_tween.kill()

	crossfade_tween = create_tween()
	crossfade_tween.set_parallel(true)
	crossfade_tween.set_ease(Tween.EASE_IN_OUT)
	crossfade_tween.set_trans(Tween.TRANS_SINE)
	crossfade_tween.tween_property(incoming, "modulate:a", 1.0, CROSSFADE_DURATION)
	crossfade_tween.tween_property(finished_player, "modulate:a", 0.0, CROSSFADE_DURATION)

	crossfade_tween.set_parallel(false)
	crossfade_tween.tween_callback(func(): finished_player.stop())

	active_player = incoming


func _try_play_music():
	if ResourceLoader.exists(MUSIC_PATH):
		music_player.stream = load(MUSIC_PATH)
		music_player.play()
	else:
		push_warning("Menu music not found at: %s" % MUSIC_PATH)


func _on_comenzar():
	# Fade everything to black, then change scene
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_SINE)

	if music_player.playing:
		fade_tween.tween_property(music_player, "volume_db", -40.0, FADE_OUT_DURATION)

	fade_tween.tween_property(video_a, "modulate:a", 0.0, FADE_OUT_DURATION)
	fade_tween.tween_property(video_b, "modulate:a", 0.0, FADE_OUT_DURATION)

	fade_tween.set_parallel(false)
	fade_tween.tween_callback(_go_to_game)


func _go_to_game():
	music_player.stop()
	video_a.stop()
	video_b.stop()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
