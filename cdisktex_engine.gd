@tool
extends Node
## ============================================================================
##  CdiskTex Engine  (CDT)  -  Center Diskent Tex            version 1.1.0
##  One file. Godot 4.x. Free.
##
##  Gives any 3D Godot project Source-engine style player movement:
##  the CS2 / CS:GO / CS:S feel - accelerate / friction / stopspeed, air-strafe,
##  bunnyhopping (scroll-wheel jump works), crouch + crouch-jump, stair stepping,
##  surfable ramps, ladders, 64-tick physics, CS mouse sensitivity (m_yaw 0.022)
##  and a speed / bhop HUD.  It also shows the CdiskTex logo before your game.
##
##  INSTALL (pick one, 10 seconds):
##    A) Drop this file anywhere in your project, then
##       Project > Project Settings > Globals > Autoload > choose this file,
##       Node Name "CDT" > Add.
##    B) Drop this file into your project and attach it (as a script) to any
##       node of any scene in the editor. It is a @tool script: it registers
##       itself as the autoload "CDT" and saves project.godot by itself.
##
##  USE: nothing to do. On run, CDT
##    - takes over the node(s) named *player* / in group "player" / "cdt_player"
##      (a CharacterBody3D whose origin is at its feet), or
##    - spawns its own first-person player when a 3D scene has none.
##  Settings are saved to  user://cdisktex_engine.cfg  automatically.
##
##  KEYS (own player):  WASD move | Space or Mouse Wheel jump | Ctrl duck |
##    Shift walk | Esc release mouse | F2 settings | F3 HUD | F4 next preset | F5 autohop |
##    F6 sensitivity - / F7 sensitivity +
##
##  API (autoload "CDT"):
##    CDT.set_preset("cs2" | "csgo" | "css" | "hl2")
##    CDT.spawn_player(Vector3) -> CharacterBody3D
##    CDT.attach(body: CharacterBody3D, own_view := false)
##    CDT.cfg["maxspeed"] = 260.0        # any value below, Source units/s
##    CDT.controller()                   # speed_u(), bhops, on_ground ...
##
##  F2 opens the in-game settings panel (preset, sensitivity, FOV, autohop...).
##
##  YOUR OWN PLAYER (optional, 1.1): CDT finds your player by itself (the body
##  that carries the current camera). To let your script keep its camera / recoil
##  / interaction code, give your CharacterBody3D this method, and CDT will drive
##  only the movement:
##      func _cdt_attached(c) -> void:      # c = the CDT controller
##          c.map_actions({"forward": "move_forward", "back": "move_back",
##              "left": "move_left", "right": "move_right", "jump": "jump",
##              "duck": "crouch", "walk": ""})       # use YOUR input actions
##          c.wheel_jump = false            # leave the mouse wheel alone
##          c.require_capture = true        # no movement while the mouse is free
##  then, every physics tick, read  c.ducked / c.duck_t / c.view_comp  for your
##  camera height, set  c.input_blocked = true  while a menu is open and
##  c.enabled = false while you move the body yourself (fly mode etc).
##
##  Units are Source units (1 unit = 0.01905 m), like the real thing.
##  Get updates / the source file:  see SITE_URL below.
##  License: free for any use, commercial included. No warranty. Independent
##  work, not affiliated with Valve; "Source" and "Counter-Strike" are theirs.
## ============================================================================

const VERSION := "1.1.0"
const SITE_URL := "https://qusderlol-glitch.github.io/CdiskTex-Engine/"
const U := 0.01905                       # metres per Source unit
const AUTOLOAD_NAME := "CDT"
const CFG_PATH := "user://cdisktex_engine.cfg"
const WEDGE_DEG := 54.0                  # 15 % of the disc is missing ...
const TILT_DEG := 15.0                   # ... and its edge is tilted 15 degrees

## Movement presets, all in Source units (u, u/s, u/s^2).
const PRESETS := {
	"cs2": {
		"accelerate": 5.5, "airaccelerate": 12.0, "friction": 5.2, "stopspeed": 80.0,
		"maxspeed": 250.0, "gravity": 800.0, "jump_speed": 301.99, "stepsize": 18.0,
		"bhop_cap": 0.0, "airspeed_cap": 30.0, "duck_speed": 0.34, "walk_speed": 0.52,
		"maxvelocity": 3500.0, "hull_w": 32.0, "hull_h": 72.0, "hull_duck": 54.0,
		"eye": 64.0, "eye_duck": 46.0, "ladder_speed": 200.0,
	},
	"csgo": {
		"accelerate": 5.5, "airaccelerate": 12.0, "friction": 5.2, "stopspeed": 80.0,
		"maxspeed": 250.0, "gravity": 800.0, "jump_speed": 301.99, "stepsize": 18.0,
		"bhop_cap": 1.1, "airspeed_cap": 30.0, "duck_speed": 0.34, "walk_speed": 0.52,
		"maxvelocity": 3500.0, "hull_w": 32.0, "hull_h": 72.0, "hull_duck": 54.0,
		"eye": 64.0, "eye_duck": 46.0, "ladder_speed": 200.0,
	},
	"css": {
		"accelerate": 5.0, "airaccelerate": 10.0, "friction": 4.0, "stopspeed": 75.0,
		"maxspeed": 250.0, "gravity": 800.0, "jump_speed": 301.99, "stepsize": 18.0,
		"bhop_cap": 0.0, "airspeed_cap": 30.0, "duck_speed": 0.34, "walk_speed": 0.52,
		"maxvelocity": 3500.0, "hull_w": 32.0, "hull_h": 72.0, "hull_duck": 54.0,
		"eye": 64.0, "eye_duck": 46.0, "ladder_speed": 200.0,
	},
	"hl2": {
		"accelerate": 10.0, "airaccelerate": 10.0, "friction": 4.0, "stopspeed": 100.0,
		"maxspeed": 190.0, "gravity": 600.0, "jump_speed": 158.74, "stepsize": 18.0,
		"bhop_cap": 0.0, "airspeed_cap": 30.0, "duck_speed": 0.33, "walk_speed": 0.52,
		"maxvelocity": 3500.0, "hull_w": 32.0, "hull_h": 72.0, "hull_duck": 36.0,
		"eye": 64.0, "eye_duck": 28.0, "ladder_speed": 200.0,
	},
}
const PRESET_ORDER := ["cs2", "csgo", "css", "hl2"]

const ACTION_KEYS := {
	"cdt_forward": KEY_W, "cdt_back": KEY_S, "cdt_left": KEY_A, "cdt_right": KEY_D,
	"cdt_jump": KEY_SPACE, "cdt_duck": KEY_CTRL, "cdt_walk": KEY_SHIFT,
}

static var _instance: Node = null

var cfg: Dictionary = {}
var preset_name := "cs2"
var _controllers: Array = []
var _hud_layer: CanvasLayer
var _hud: Label
var _cross: Control
var _splash_layer: CanvasLayer
var _splash_link: LinkButton
var _splash_open := false
var _saved_mouse := Input.MOUSE_MODE_VISIBLE
var _last_scene: Node = null
var _scan_wait := 0
var _spawn_tried := false
var _scan_i := 0
var _scan_found := false
static var menu_open := false
var _menu_layer: CanvasLayer
var _menu_prev_mouse := Input.MOUSE_MODE_VISIBLE
var _menu_prev_paused := false
const SCAN_STEPS := [3, 30, 90, 240]

# ============================================================================
#  startup / self-install
# ============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		_self_install()
		return
	if _instance != null and _instance != self:
		queue_free()                          # already running as the autoload
		return
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	cfg = (PRESETS["cs2"] as Dictionary).duplicate()
	cfg.merge({
		"sensitivity": 1.0, "fov": 73.74, "autohop": false, "hud": true, "tickrate": 64,
		"splash": true, "capture_mouse": true, "auto_spawn": true, "takeover": true,
		"crosshair": true, "jump_wheel": true, "preset": "cs2",
	}, true)
	_load_cfg()
	_make_actions()
	if int(cfg["tickrate"]) > 0:
		Engine.physics_ticks_per_second = int(cfg["tickrate"])
	_build_hud()
	_maybe_splash()
	print("[CdiskTex Engine %s] ready - preset %s, %d tick. %s" % [VERSION, preset_name, Engine.physics_ticks_per_second, SITE_URL])

func _self_install() -> void:
	var path := ""
	var scr: Script = get_script()
	if scr != null:
		path = scr.resource_path
	if path == "" or not path.begins_with("res://"):
		return
	var key := "autoload/" + AUTOLOAD_NAME
	var cur: String = str(ProjectSettings.get_setting(key, ""))
	if cur == "*" + path:
		return
	ProjectSettings.set_setting(key, "*" + path)
	var err := ProjectSettings.save()
	print("[CdiskTex Engine] installed itself as autoload '%s' (%s). Run your game." % [AUTOLOAD_NAME, "saved" if err == OK else "save failed: %d" % err])

func _make_actions() -> void:
	for a in ACTION_KEYS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = ACTION_KEYS[a]
			InputMap.action_add_event(a, ev)

func _load_cfg() -> void:
	var f := ConfigFile.new()
	if f.load(CFG_PATH) != OK:
		set_preset("cs2", false)
		return
	for k in ["sensitivity", "fov", "autohop", "hud", "tickrate", "splash", "capture_mouse", "auto_spawn", "takeover", "crosshair", "jump_wheel"]:
		if f.has_section_key("cdt", k):
			cfg[k] = f.get_value("cdt", k)
	set_preset(str(f.get_value("cdt", "preset", "cs2")), false)
	for k in f.get_section_keys("override") if f.has_section("override") else PackedStringArray():
		cfg[k] = f.get_value("override", k)

func save_cfg() -> void:
	var f := ConfigFile.new()
	for k in ["sensitivity", "fov", "autohop", "hud", "tickrate", "splash", "capture_mouse", "auto_spawn", "takeover", "crosshair", "jump_wheel"]:
		f.set_value("cdt", k, cfg[k])
	f.set_value("cdt", "preset", preset_name)
	f.save(CFG_PATH)

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and _instance == self:
		save_cfg()
		_instance = null

## Switch movement preset: "cs2", "csgo", "css", "hl2".
func set_preset(pname: String, save := true) -> void:
	if not PRESETS.has(pname):
		return
	preset_name = pname
	cfg.merge(PRESETS[pname] as Dictionary, true)
	cfg["preset"] = pname
	if save:
		save_cfg()

func controller() -> CDTController:
	for c in _controllers:
		if is_instance_valid(c):
			return c
	return null

# ============================================================================
#  scene scanning: take over / spawn a player
# ============================================================================

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	var scn := get_tree().current_scene
	if scn != _last_scene:
		_last_scene = scn
		_scan_i = 0
		_scan_wait = SCAN_STEPS[0]
		_spawn_tried = false
		_scan_found = false
		_controllers = _controllers.filter(func(c): return is_instance_valid(c))
	if _scan_wait > 0:
		_scan_wait -= 1
		if _scan_wait == 0 and scn != null:
			_scan_scene(scn)
			if not _scan_found and _scan_i < SCAN_STEPS.size() - 1:      # a player spawned later is still found
				_scan_i += 1
				_scan_wait = SCAN_STEPS[_scan_i] - SCAN_STEPS[_scan_i - 1]
	_update_hud()

func _scan_scene(scn: Node) -> void:
	var found := false
	if bool(cfg["takeover"]):
		var cand: Array = []
		for g in ["cdt_player", "player"]:
			for n in get_tree().get_nodes_in_group(g):
				if n is CharacterBody3D and not cand.has(n):
					cand.append(n)
		var cam := scn.get_viewport().get_camera_3d()                   # the body that carries the camera you look through
		if cam != null:
			var a: Node = cam.get_parent()
			while a != null and a != scn.get_parent():
				if a is CharacterBody3D:
					if not cand.has(a):
						cand.append(a)
					break
				a = a.get_parent()
		for n in scn.find_children("*", "CharacterBody3D", true, false):
			if (n as Node).name.to_lower().contains("player") and not cand.has(n):
				cand.append(n)
		for n in cand:
			if (n as Node).has_node("CDTController"):
				found = true
				continue
			attach(n as CharacterBody3D, false)
			found = true
	var has_cam := scn.get_viewport().get_camera_3d() != null
	if found:
		_scan_found = true
	elif not has_cam and bool(cfg["auto_spawn"]) and scn is Node3D and not _spawn_tried:
		_spawn_tried = true
		var has_world := false
		for n in scn.find_children("*", "CollisionObject3D", true, false):
			has_world = true
			break
		if has_world:
			var sp := Vector3(0, 1.0, 0)
			for nm in ["CDTSpawn", "PlayerStart", "SpawnPoint", "Spawn", "PlayerSpawn"]:
				var m := scn.find_child(nm, true, false)
				if m is Node3D:
					sp = (m as Node3D).global_position
					break
			spawn_player(sp)
			_scan_found = true

## Spawn CDT's own first-person player.
func spawn_player(pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "CDTPlayer"
	body.add_to_group("cdt_player")
	var scn := get_tree().current_scene
	if scn == null:
		scn = get_tree().root
	scn.add_child(body)
	body.global_position = pos
	var c := attach(body, true)
	if bool(cfg["capture_mouse"]):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return c.body

## Put a CharacterBody3D (origin at its feet) under Source movement.
## own_view = true: CDT also owns the camera + mouse look.
func attach(body: CharacterBody3D, own_view := false) -> CDTController:
	var c := CDTController.new()
	c.name = "CDTController"
	body.add_child(c)
	c.setup(body, cfg, own_view)
	_controllers.append(c)
	return c

# ============================================================================
#  input
# ============================================================================

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _splash_open:
		_splash_input(event)
		return
	if menu_open:
		if event is InputEventKey and event.pressed and not event.echo and ((event as InputEventKey).physical_keycode == KEY_F2 or (event as InputEventKey).physical_keycode == KEY_ESCAPE):
			_toggle_menu()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F2:
		_toggle_menu()
		get_viewport().set_input_as_handled()
		return
	var wheel: bool = event is InputEventMouseButton and event.pressed and ((event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN)
	for c in _controllers:
		if not is_instance_valid(c):
			continue
		var cc := c as CDTController
		var ja: String = cc.acts["jump"]
		if ja != "" and event.is_action_pressed(ja) and not event.is_echo():
			cc.jump_buffer = true
		elif wheel and cc.wheel_jump and bool(cfg["jump_wheel"]):
			cc.jump_buffer = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		for c in _controllers:
			if is_instance_valid(c) and (c as CDTController).own_view:
				(c as CDTController).look((event as InputEventMouseMotion).relative)
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		match k:
			KEY_F3:
				cfg["hud"] = not bool(cfg["hud"]); save_cfg()
			KEY_F4:
				var i := PRESET_ORDER.find(preset_name)
				set_preset(PRESET_ORDER[(i + 1) % PRESET_ORDER.size()])
				_flash("preset: " + preset_name)
			KEY_F5:
				cfg["autohop"] = not bool(cfg["autohop"]); save_cfg()
				_flash("autohop: " + ("ON" if bool(cfg["autohop"]) else "OFF"))
			KEY_F6, KEY_F7:
				var s := float(cfg["sensitivity"])
				s = clampf(s * (0.9 if k == KEY_F6 else 1.1), 0.05, 20.0)
				cfg["sensitivity"] = snappedf(s, 0.01); save_cfg()
				_flash("sensitivity: %s" % str(cfg["sensitivity"]))
			KEY_ESCAPE:
				var cap := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				for c in _controllers:
					if is_instance_valid(c) and (c as CDTController).own_view:
						Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cap else Input.MOUSE_MODE_CAPTURED
						break
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and bool(cfg["capture_mouse"]):
			for c in _controllers:
				if is_instance_valid(c) and (c as CDTController).own_view:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					break

# ============================================================================
#  F1 settings panel
# ============================================================================

func _toggle_menu() -> void:
	for c in _controllers:
		if is_instance_valid(c):
			(c as CDTController).menu_blocked = not menu_open
	if menu_open:
		menu_open = false
		if _menu_layer != null:
			_menu_layer.queue_free()
			_menu_layer = null
		get_tree().paused = _menu_prev_paused
		Input.mouse_mode = _menu_prev_mouse
		save_cfg()
		return
	menu_open = true
	_menu_prev_mouse = Input.mouse_mode
	_menu_prev_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 150
	add_child(_menu_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_menu_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	var title := Label.new()
	title.text = "CdiskTex Engine %s  -  settings" % VERSION
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
	box.add_child(title)
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = "Movement preset"
	lab.custom_minimum_size = Vector2(150, 0)
	row.add_child(lab)
	var ob := OptionButton.new()
	for pn in PRESET_ORDER:
		ob.add_item(pn)
	ob.selected = maxi(PRESET_ORDER.find(preset_name), 0)
	ob.item_selected.connect(func(ix: int) -> void: set_preset(PRESET_ORDER[ix], false))
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ob)
	box.add_child(row)
	_menu_slider(box, "Sensitivity", "sensitivity", 0.1, 5.0, 0.05)
	_menu_slider(box, "Field of view", "fov", 50.0, 110.0, 1.0)
	_menu_check(box, "Autohop (hold jump)", "autohop")
	_menu_check(box, "Speed HUD", "hud")
	_menu_check(box, "Crosshair", "crosshair")
	_menu_check(box, "Mouse wheel jumps", "jump_wheel")
	var hint := Label.new()
	hint.text = "F2 or Esc closes.  F4 next preset, F5 autohop in game."
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))
	box.add_child(hint)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_toggle_menu)
	box.add_child(close)
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS

func _menu_slider(box: VBoxContainer, label: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(cfg[key])
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	var v := Label.new()
	v.custom_minimum_size = Vector2(52, 0)
	v.text = str(snappedf(sl.value, step))
	row.add_child(v)
	sl.value_changed.connect(func(x: float) -> void:
		cfg[key] = x
		v.text = str(snappedf(x, step)))
	box.add_child(row)

func _menu_check(box: VBoxContainer, label: String, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = bool(cfg[key])
	cb.toggled.connect(func(on: bool) -> void: cfg[key] = on)
	box.add_child(cb)

# ============================================================================
#  HUD
# ============================================================================

var _flash_t := 0.0
var _flash_txt := ""

func _flash(t: String) -> void:
	_flash_txt = t
	_flash_t = 1.6

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	add_child(_hud_layer)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(1, 0.86, 0.6))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("outline_size", 4)
	_hud_layer.add_child(_hud)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	_hud_layer.add_child(_cross)

func _draw_cross() -> void:
	var own := false
	for c in _controllers:
		if is_instance_valid(c) and (c as CDTController).own_view:
			own = true
	if not own or not bool(cfg["crosshair"]):
		return
	var m := _cross.size * 0.5
	var col := Color(0.2, 1.0, 0.3, 0.95)
	var edge := Color(0, 0, 0, 0.6)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_cross.draw_line(m + d * 3.0, m + d * 9.0, edge, 4.0)
		_cross.draw_line(m + d * 3.0, m + d * 9.0, col, 2.0)

func _update_hud() -> void:
	if _hud == null:
		return
	_flash_t = maxf(_flash_t - get_process_delta_time(), 0.0)
	var c := controller()
	var show := bool(cfg["hud"]) and c != null and not _splash_open
	_hud.visible = show or _flash_t > 0.0
	_cross.visible = c != null and not _splash_open
	_cross.queue_redraw()
	if not _hud.visible:
		return
	var txt := ""
	if show and c != null:
		txt = "SPEED %4d u/s   PRE %4d   HOPS %d   %s%s\n%s | %d tick | sens %s | autohop %s\nF2 menu  F3 hud  F4 preset  F5 autohop  F6/F7 sens" % [
			int(c.speed_u()), int(c.last_prespeed), c.bhops, "GROUND" if c.on_ground else "AIR",
			"  DUCK" if c.ducked else "", preset_name, Engine.physics_ticks_per_second, str(cfg["sensitivity"]),
			"on" if bool(cfg["autohop"]) else "off"]
	if _flash_t > 0.0:
		txt += ("\n" if txt != "" else "") + ">> " + _flash_txt
	_hud.text = txt
	var vs := get_viewport().get_visible_rect().size                  # your own HUD keeps the top-left; ours drops to the bottom-left
	_hud.position = Vector2(14, 10) if (c != null and c.own_view) else Vector2(14, maxf(vs.y - _hud.get_minimum_size().y - 14.0, 10.0))

# ============================================================================
#  splash (the CdiskTex logo comes first)
# ============================================================================

func _maybe_splash() -> void:
	if not bool(cfg["splash"]):
		return
	if DisplayServer.get_name() == "headless" or "--cdt-nosplash" in OS.get_cmdline_user_args() or "--cdt-nosplash" in OS.get_cmdline_args():
		return
	_splash_layer = CanvasLayer.new()
	_splash_layer.layer = 200
	add_child(_splash_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.035, 0.037, 0.05)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_layer.add_child(bg)
	var logo := CDTLogo.new()
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_layer.add_child(logo)
	_splash_link = LinkButton.new()
	_splash_link.text = "Free download:  " + SITE_URL
	_splash_link.uri = SITE_URL
	_splash_link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	_splash_link.add_theme_font_size_override("font_size", 15)
	_splash_link.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
	_splash_link.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.5))
	_splash_link.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_splash_link.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_splash_link.position.y -= 44
	_splash_layer.add_child(_splash_link)
	_saved_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_splash_open = true
	_splash_layer.offset = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.7).from(0.0)

func _splash_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		pressed = event.pressed
		if pressed and _splash_link != null and _splash_link.get_global_rect().has_point((event as InputEventMouseButton).position):
			return                                  # clicking the link opens the site, not the game
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_splash_open = false
	var tw := create_tween()
	tw.tween_property(_splash_layer, "offset:y", 0.0, 0.0)
	for ch in _splash_layer.get_children():
		if ch is CanvasItem:
			tw.parallel().tween_property(ch, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		_splash_layer.queue_free()
		get_tree().paused = false
		Input.mouse_mode = _saved_mouse
		for c in _controllers:
			if is_instance_valid(c) and (c as CDTController).own_view and bool(cfg["capture_mouse"]):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

# ============================================================================
#  the logo: a CD / disc with 15 % cut out, edge tilted 15 degrees, "Cd" in the hub
# ============================================================================

class CDTLogo extends Control:
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var R := minf(size.x * 0.27, size.y * 0.185)
		var c := Vector2(size.x * 0.5, size.y * 0.315)
		draw_emblem(self, font, c, R, t)
		# wordmark
		var fs := int(R * 0.44)
		var base_y := c.y + R * 1.62 + fs * 0.95
		var w1 := font.get_string_size("Cdisk", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w2 := font.get_string_size("Tex", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := c.x - (w1 + w2) * 0.5
		draw_string(font, Vector2(x0, base_y), "Cdisk", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.96, 0.98))
		draw_string(font, Vector2(x0 + w1, base_y), "Tex", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.5, 0.12))
		# ENGINE, letter-spaced
		var fs2 := int(R * 0.15)
		var word := "E N G I N E"
		var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(font, Vector2(c.x - ww * 0.5, base_y + fs2 * 1.9), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.72, 0.74, 0.82))
		var fs3 := int(R * 0.105)
		var sub := "CENTER DISKENT TEX   ·   CDT   ·   v%s" % VERSION
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
		draw_string(font, Vector2(c.x - sw * 0.5, base_y + fs2 * 1.9 + fs3 * 2.2), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, Color(0.5, 0.52, 0.6))
		var blink := 0.55 + 0.45 * sin(t * 3.2)
		var press := "PRESS ANY KEY"
		var pw := font.get_string_size(press, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3 + 3).x
		draw_string(font, Vector2(c.x - pw * 0.5, size.y - 92), press, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3 + 3, Color(1, 1, 1, blink))

	## Draws the emblem centred at c with disc radius R (works in any CanvasItem).
	static func draw_emblem(ci: CanvasItem, font: Font, c: Vector2, R: float, t: float) -> void:
		var a_w1 := deg_to_rad(-TILT_DEG)                       # wedge edge, 15 degrees above horizontal
		var a_w0 := a_w1 - deg_to_rad(WEDGE_DEG)                # wedge spans 54 degrees (= 15 % of 360)
		var a_start := a_w1
		var a_end := a_w0 + TAU
		var sweep := a_end - a_start
		# glow
		for i in 6:
			ci.draw_circle(c, R * (1.55 - i * 0.12), Color(1.0, 0.45, 0.1, 0.012 + 0.006 * i))
		# disc body
		var seg := 144
		var r_in := R * 0.34
		for i in seg:
			var a0 := a_start + sweep * float(i) / seg
			var a1 := a_start + sweep * float(i + 1) / seg
			var col0 := _sheen(a0, t)
			var col1 := _sheen(a1, t)
			var pts := PackedVector2Array([
				c + Vector2(cos(a0), sin(a0)) * R, c + Vector2(cos(a1), sin(a1)) * R,
				c + Vector2(cos(a1), sin(a1)) * r_in, c + Vector2(cos(a0), sin(a0)) * r_in])
			var cols := PackedColorArray([col0, col1, col1 * 0.45, col0 * 0.45])
			for k in cols.size():
				cols[k].a = 1.0
			ci.draw_polygon(pts, cols)
		# data grooves
		for k in 11:
			var r := lerpf(r_in * 1.08, R * 0.97, float(k) / 10.0)
			ci.draw_arc(c, r, a_start, a_end, 160, Color(0, 0, 0, 0.2 if k % 3 else 0.32), 1.0, true)
		# shine streaks
		for s in [0.9, 3.9]:
			var ang: float = s + sin(t * 0.4) * 0.12
			for k in 7:
				var r2 := lerpf(R * 0.45, R * 0.94, float(k) / 6.0)
				ci.draw_arc(c, r2, ang - 0.32, ang + 0.32, 24, Color(1, 1, 1, 0.1 + 0.02 * k), 2.0, true)
		# bright rim
		ci.draw_arc(c, R, a_start, a_end, 200, Color(1, 0.93, 0.82, 0.95), 3.0, true)
		ci.draw_arc(c, R * 0.985, a_start, a_end, 200, Color(1.0, 0.55, 0.15, 0.7), 2.0, true)
		# micro text ring (clockwise, outside the cut)
		var ring := "CENTER DISKENT TEX · CDT · "
		var fsr := maxi(int(R * 0.062), 6)
		var rr := R * 0.76
		var ang2 := a_start + 0.16
		var ix := 0
		while ang2 < a_end - 0.16:
			var ch := ring[ix % ring.length()]
			var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsr).x
			var mid := ang2 + (cw * 0.5) / rr
			ci.draw_set_transform(c + Vector2(cos(mid), sin(mid)) * rr, mid + PI * 0.5, Vector2.ONE)
			ci.draw_string(font, Vector2(-cw * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsr, Color(0.1, 0.02, 0.0, 0.62))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ang2 += (cw + 1.2) / rr
			ix += 1
		# hub
		ci.draw_circle(c, R * 0.34, Color(0.045, 0.047, 0.06))
		ci.draw_arc(c, R * 0.34, 0.0, TAU, 96, Color(1.0, 0.6, 0.2, 0.95), 2.5, true)
		ci.draw_arc(c, R * 0.305, 0.0, TAU, 96, Color(1, 1, 1, 0.2), 1.0, true)
		var fsh := int(R * 0.27)
		var wC := font.get_string_size("C", HORIZONTAL_ALIGNMENT_LEFT, -1, fsh).x
		var wd := font.get_string_size("d", HORIZONTAL_ALIGNMENT_LEFT, -1, fsh).x
		var tx := c.x - (wC + wd) * 0.5
		var ty := c.y + fsh * 0.33
		ci.draw_string(font, Vector2(tx, ty), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, fsh, Color(0.97, 0.97, 1.0))
		ci.draw_string(font, Vector2(tx + wC, ty), "d", HORIZONTAL_ALIGNMENT_LEFT, -1, fsh, Color(1.0, 0.52, 0.14))
		# cut edges
		for a in [a_w1, a_w0]:
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(c + d * R * 0.34, c + d * R * 1.0, Color(1, 1, 1, 0.9), 2.0, true)
			ci.draw_line(c + d * R * 1.0, c + d * R * 1.1, Color(1.0, 0.55, 0.15, 0.9), 2.0, true)
		# ghost of the missing 15 % (dashed) + scan dot sliding in the gap
		var gaps := 18
		for i in gaps:
			if i % 2 == 0:
				var g0 := a_w0 + (a_w1 - a_w0) * float(i) / gaps
				var g1 := a_w0 + (a_w1 - a_w0) * float(i + 1) / gaps
				ci.draw_arc(c, R, g0, g1, 6, Color(1, 1, 1, 0.38), 1.5, true)
				ci.draw_arc(c, R * 0.66, g0, g1, 6, Color(1, 1, 1, 0.16), 1.0, true)
		var am := (a_w0 + a_w1) * 0.5
		var fr := fmod(t * 0.45, 1.0)
		var sp := c + Vector2(cos(am), sin(am)) * R * lerpf(0.4, 1.0, fr)
		ci.draw_circle(sp, R * 0.05, Color(1.0, 0.6, 0.2, 0.18))
		ci.draw_circle(sp, R * 0.022, Color(1.0, 0.9, 0.7, 0.95))
		# tick marks (only where the disc exists)
		for deg in range(0, 360, 6):
			var a := deg_to_rad(float(deg)) - PI * 0.5
			var aa := fposmod(a - a_start, TAU)
			if aa > sweep - 0.02:
				continue
			var long := deg % 30 == 0
			var d2 := Vector2(cos(a), sin(a))
			ci.draw_line(c + d2 * R * 1.07, c + d2 * R * (1.16 if long else 1.11), Color(1, 1, 1, 0.65 if long else 0.32), 1.5 if long else 1.0, true)
		# orbit with satellites
		ci.draw_arc(c, R * 1.3, a_start + 0.1, a_end - 0.1, 200, Color(1, 1, 1, 0.14), 1.0, true)
		for i in 3:
			var sa := a_start + 0.4 + fposmod(t * 0.08 + i * 0.31, 1.0) * (sweep - 0.8)
			ci.draw_circle(c + Vector2(cos(sa), sin(sa)) * R * 1.3, R * (0.022 + 0.008 * i), Color(1.0, 0.6, 0.2, 0.85))
		# arrow marker where the 15 % went
		var tip := c + Vector2(cos(am), sin(am)) * R * 1.34
		var perp := Vector2(-sin(am), cos(am))
		ci.draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(cos(am), sin(am)) * R * 0.09 + perp * R * 0.05, tip - Vector2(cos(am), sin(am)) * R * 0.09 - perp * R * 0.05]), Color(1.0, 0.55, 0.15))
		# corner brackets
		var m := R * 1.62
		var l := R * 0.18
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p := c + Vector2(sx * m, sy * m)
				ci.draw_line(p, p + Vector2(-sx * l, 0), Color(1, 1, 1, 0.4), 1.5)
				ci.draw_line(p, p + Vector2(0, -sy * l), Color(1, 1, 1, 0.4), 1.5)
		# little pixel stack by the cut
		var px := c + Vector2(cos(am), sin(am)) * R * 1.52 + Vector2(R * 0.05, 0)
		for i in 3:
			ci.draw_rect(Rect2(px + Vector2(i * R * 0.07, -i * R * 0.07), Vector2(R * 0.045, R * 0.045)), Color(1.0, 0.55, 0.15, 0.4 + 0.25 * i))

	static func _sheen(a: float, t: float) -> Color:
		var h := 0.065 + 0.035 * sin(a * 2.0 + t * 0.5)
		var v := 0.82 + 0.18 * sin(a * 3.0 - t * 0.8)
		return Color.from_hsv(h, 0.9, v)

# ============================================================================
#  the Source-style movement controller
# ============================================================================

class CDTController extends Node:
	var cfg: Dictionary
	var body: CharacterBody3D
	var hull: CollisionShape3D
	var box := BoxShape3D.new()
	var head: Node3D
	var cam: Camera3D
	var own_view := false
	var yaw := 0.0
	var pitch := 0.0
	var ducked := false
	var duck_t := 0.0
	var on_ground := false
	var ground_normal := Vector3.UP
	var jump_buffer := false
	var jump_held := false
	var view_comp := 0.0
	var prev_pos := Vector3.ZERO
	var cur_pos := Vector3.ZERO
	var ground_ticks := 0
	var bhops := 0
	var last_prespeed := 0.0
	var jumps_total := 0
	var on_ladder := false
	var _foreign_cam: Camera3D
	var enabled := true                    # false: CDT does not move the body (fly mode ...)
	var input_blocked := false             # true: ignore keys this tick (menus)
	var menu_blocked := false              # set by CDT while its F2 panel is open
	var require_capture := false           # true: no input while the mouse is not captured
	var wheel_jump := true                 # mouse wheel = jump
	var hull_ov := {}                      # per-body hull override (units), read from your collision shape
	var acts := {"forward": "cdt_forward", "back": "cdt_back", "left": "cdt_left", "right": "cdt_right", "jump": "cdt_jump", "duck": "cdt_duck", "walk": "cdt_walk"}

	## Point CDT at your own input actions. Keys: forward back left right jump duck walk. "" = unused.
	func map_actions(m: Dictionary) -> void:
		for k in m:
			if acts.has(k):
				acts[k] = String(m[k])

	func hv(key: String) -> float:
		return float(hull_ov.get(key, cfg[key]))

	func _act(k: String) -> bool:
		var a: String = acts[k]
		return a != "" and InputMap.has_action(a) and Input.is_action_pressed(a)

	func _axis(neg: String, pos: String) -> float:
		return (1.0 if _act(pos) else 0.0) - (1.0 if _act(neg) else 0.0)

	func setup(b: CharacterBody3D, c: Dictionary, own: bool) -> void:
		body = b
		cfg = c
		own_view = own
		for ch in body.get_children():
			if ch is CollisionShape3D:
				if not own and (ch as CollisionShape3D).shape != null and not (ch as CollisionShape3D).disabled and hull_ov.is_empty():
					var sh: Shape3D = (ch as CollisionShape3D).shape
					var bw := 0.0
					var bh := 0.0
					if sh is CapsuleShape3D:
						bw = (sh as CapsuleShape3D).radius * 2.0
						bh = (sh as CapsuleShape3D).height
					elif sh is BoxShape3D:
						bw = maxf((sh as BoxShape3D).size.x, (sh as BoxShape3D).size.z)
						bh = (sh as BoxShape3D).size.y
					elif sh is CylinderShape3D:
						bw = (sh as CylinderShape3D).radius * 2.0
						bh = (sh as CylinderShape3D).height
					if bw > 0.05 and bh > 0.2:                           # keep YOUR body size, not the 72 unit CS hull
						hull_ov = {"hull_w": bw / U, "hull_h": bh / U, "hull_duck": bh * 0.75 / U}
				ch.set_deferred("disabled", true)
		hull = CollisionShape3D.new()
		hull.name = "CDT_Hull"
		hull.shape = box
		body.add_child(hull)
		body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		body.floor_max_angle = acos(0.7)                  # Source: walkable when normal.y >= 0.7
		body.floor_stop_on_slope = false
		body.floor_constant_speed = false
		body.floor_block_on_wall = false
		body.floor_snap_length = 0.0
		body.max_slides = 4
		body.wall_min_slide_angle = 0.0
		body.safe_margin = 0.001
		body.up_direction = Vector3.UP
		_apply_hull(false)
		if own_view:
			head = Node3D.new()
			head.name = "CDT_Head"
			head.top_level = true
			body.add_child(head)
			cam = Camera3D.new()
			cam.name = "CDT_Camera"
			cam.fov = float(cfg["fov"])
			cam.near = 0.03
			cam.far = 2000.0
			head.add_child(cam)
			cam.current = true
		else:
			for n in body.find_children("*", "Camera3D", true, false):
				_foreign_cam = n
				break
			if not body.has_method("_cdt_attached"):
				body.set_physics_process(false)           # CDT drives the body now (it has no cooperating script)
		cur_pos = body.global_position
		prev_pos = cur_pos
		_apply_hull(false)
		if not own and body.has_method("_cdt_attached"):
			body.call("_cdt_attached", self)

	func _apply_hull(duck: bool) -> void:
		var w := hv("hull_w") * U
		var h := (hv("hull_duck") if duck else hv("hull_h")) * U
		box.size = Vector3(w, h, w)
		hull.position = Vector3(0, h * 0.5, 0)

	func speed_u() -> float:
		return Vector2(body.velocity.x, body.velocity.z).length() / U

	func look(rel: Vector2) -> void:
		var k := deg_to_rad(0.022) * float(CDT_sens())      # CS: m_yaw = m_pitch = 0.022
		yaw -= rel.x * k
		pitch = clampf(pitch - rel.y * k, deg_to_rad(-89.0), deg_to_rad(89.0))

	func CDT_sens() -> float:
		return float(cfg["sensitivity"])

	# -------------------------------------------------------------- per frame

	func _process(dt: float) -> void:
		view_comp *= exp(-12.0 * dt)
		if body == null or not is_instance_valid(body) or not own_view:
			return
		var a := Engine.get_physics_interpolation_fraction()
		var pos := prev_pos.lerp(cur_pos, a)
		var eye := lerpf(float(cfg["eye"]), float(cfg["eye_duck"]), smoothstep(0.0, 1.0, duck_t)) * U
		head.global_position = pos + Vector3(0, eye + view_comp, 0)
		head.rotation = Vector3(0, yaw, 0)
		cam.rotation = Vector3(pitch, 0, 0)

	# --------------------------------------------------------- physics ticks

	func _physics_process(dt: float) -> void:
		if body == null or not is_instance_valid(body):
			queue_free()
			return
		prev_pos = cur_pos
		if not enabled:
			cur_pos = body.global_position
			jump_buffer = false
			return
		if not own_view:
			if _foreign_cam != null and is_instance_valid(_foreign_cam):
				yaw = _foreign_cam.global_rotation.y
			else:
				yaw = body.global_rotation.y
		var captured_ok: bool = ((not own_view and not require_capture) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) and not input_blocked and not menu_blocked
		var f := _axis("back", "forward") if captured_ok else 0.0
		var s := _axis("left", "right") if captured_ok else 0.0
		var walk := _act("walk") and captured_ok
		jump_held = _act("jump") and captured_ok
		var pressed := jump_buffer and captured_ok
		jump_buffer = false
		var g := float(cfg["gravity"]) * U
		duck_t = move_toward(duck_t, 1.0 if ducked else 0.0, dt / 0.2)

		_check_ground()
		var ladder := _find_ladder()
		on_ladder = ladder != null
		body.velocity.y -= g * 0.5 * dt                                   # StartGravity
		_update_duck(captured_ok and _act("duck"))

		var jumped := false
		if on_ladder:
			_ladder_move(f, s, pressed)
		else:
			if on_ground and (pressed or (bool(cfg["autohop"]) and jump_held)):
				_do_jump(walk)
				jumped = true
			var basis := Basis(Vector3.UP, yaw)
			var fwd := -basis.z
			var right := basis.x
			var maxs := float(cfg["maxspeed"]) * U
			if walk:
				maxs *= float(cfg["walk_speed"])
			if ducked:
				maxs *= float(cfg["duck_speed"])
			var wishvel := (fwd * f + right * s) * (450.0 * U)
			var wishspeed := wishvel.length()
			if wishspeed > maxs:
				wishvel *= maxs / wishspeed
				wishspeed = maxs
			var wishdir := wishvel.normalized() if wishspeed > 0.0001 else Vector3.ZERO
			if on_ground:
				_friction(dt)
				_accelerate(wishdir, wishspeed, float(cfg["accelerate"]), dt)
				body.velocity.y = 0.0
			else:
				_air_accelerate(wishdir, wishspeed, float(cfg["airaccelerate"]), dt)
			_clamp_velocity()
			_move(dt, jumped)

		_check_ground()
		body.velocity.y -= g * 0.5 * dt                                   # FinishGravity (the jump tick gets it twice, like Source)
		if on_ground and body.velocity.y < 0.0:
			body.velocity.y = 0.0
		ground_ticks = ground_ticks + 1 if on_ground else 0
		cur_pos = body.global_position

	# ---------------------------------------------------------------- pieces

	func _check_ground() -> void:
		on_ground = false
		ground_normal = Vector3.UP
		if body.velocity.y > 140.0 * U:
			return                                                        # leaving the ground fast
		var p := PhysicsTestMotionParameters3D.new()
		p.from = body.global_transform
		p.motion = Vector3.DOWN * 2.0 * U
		p.max_collisions = 4
		p.margin = 0.001
		var r := PhysicsTestMotionResult3D.new()
		if PhysicsServer3D.body_test_motion(body.get_rid(), p, r):
			for i in r.get_collision_count():
				var n := r.get_collision_normal(i)
				if n.y >= 0.7:
					on_ground = true
					ground_normal = n
					return

	func _friction(dt: float) -> void:
		var v := body.velocity
		var speed := Vector2(v.x, v.z).length()
		if speed < 0.1 * U:
			return
		var control := maxf(speed, float(cfg["stopspeed"]) * U)
		var drop := control * float(cfg["friction"]) * dt
		var ns := maxf(speed - drop, 0.0)
		var k := ns / speed
		body.velocity.x *= k
		body.velocity.z *= k

	func _accelerate(wishdir: Vector3, wishspeed: float, accel: float, dt: float) -> void:
		if wishspeed <= 0.0:
			return
		var cur := Vector2(body.velocity.x, body.velocity.z).dot(Vector2(wishdir.x, wishdir.z))
		var add := wishspeed - cur
		if add <= 0.0:
			return
		var a := minf(accel * dt * wishspeed, add)
		body.velocity.x += a * wishdir.x
		body.velocity.z += a * wishdir.z

	func _air_accelerate(wishdir: Vector3, wishspeed: float, accel: float, dt: float) -> void:
		if wishspeed <= 0.0:
			return
		var wishspd := minf(wishspeed, float(cfg["airspeed_cap"]) * U)     # the 30 u/s cap = air strafing
		var cur := Vector2(body.velocity.x, body.velocity.z).dot(Vector2(wishdir.x, wishdir.z))
		var add := wishspd - cur
		if add <= 0.0:
			return
		var a := minf(accel * wishspeed * dt, add)
		body.velocity.x += a * wishdir.x
		body.velocity.z += a * wishdir.z

	func _do_jump(walk: bool) -> void:
		last_prespeed = speed_u()
		if ground_ticks <= 1:
			bhops += 1
		else:
			bhops = 0
		jumps_total += 1
		var cap := float(cfg["bhop_cap"])
		if cap > 0.0:                                                     # CS:GO PreventBunnyJumping
			var maxs := float(cfg["maxspeed"]) * U * cap
			if walk:
				maxs *= float(cfg["walk_speed"])
			var sp := Vector2(body.velocity.x, body.velocity.z).length()
			if sp > maxs:
				var k := maxs / sp
				body.velocity.x *= k
				body.velocity.z *= k
		body.velocity.y = float(cfg["jump_speed"]) * U
		body.velocity.y -= float(cfg["gravity"]) * U * 0.5 * get_physics_process_delta_time()
		on_ground = false

	func _clamp_velocity() -> void:
		var m := float(cfg["maxvelocity"]) * U
		body.velocity = body.velocity.clamp(Vector3(-m, -m, -m), Vector3(m, m, m))

	func _move(dt: float, jumped: bool) -> void:
		var start := body.global_position
		var vel0 := body.velocity
		var was_ground := on_ground
		body.move_and_slide()
		var stepsize := float(cfg["stepsize"]) * U
		# stairs
		if was_ground and not jumped:
			var want := Vector2(vel0.x, vel0.z).length() * dt
			var moved := Vector2(body.global_position.x - start.x, body.global_position.z - start.z).length()
			if want > 0.0005 and moved < want * 0.98:
				var end_pos := body.global_position
				var end_vel := body.velocity
				body.global_position = start
				body.move_and_collide(Vector3.UP * stepsize, false, 0.001)
				body.velocity = Vector3(vel0.x, 0.0, vel0.z)
				body.move_and_slide()
				var down := body.move_and_collide(Vector3.DOWN * (stepsize + 0.02), false, 0.001)
				var ok := false
				if down != null and down.get_normal().y >= 0.7:
					var moved2 := Vector2(body.global_position.x - start.x, body.global_position.z - start.z).length()
					if moved2 > moved + 0.002:
						ok = true
				if ok:
					view_comp -= body.global_position.y - start.y
					body.velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)
				else:
					body.global_position = end_pos
					body.velocity = end_vel
		# stay glued to ramps / stairs going down
		if was_ground and not jumped and body.velocity.y <= 0.001:
			var test := body.move_and_collide(Vector3.DOWN * stepsize, true, 0.001)
			if test != null and test.get_normal().y >= 0.7:
				var d := test.get_travel().length()
				if d > 0.0003:
					body.move_and_collide(Vector3.DOWN * d, false, 0.001)
					view_comp += d

	func _update_duck(want: bool) -> void:
		var diff := (hv("hull_h") - hv("hull_duck")) * U
		if want and not ducked:
			ducked = true
			if not on_ground:
				body.global_position.y += diff                            # crouch-jump: legs pull up
				view_comp -= diff
			_apply_hull(true)
		elif not want and ducked:
			var shift := 0.0 if on_ground else diff
			if _room_to_stand(shift):
				ducked = false
				if not on_ground:
					body.global_position.y -= shift
					view_comp += shift
				_apply_hull(false)

	func _room_to_stand(shift: float) -> bool:
		var w := hv("hull_w") * U
		var h := hv("hull_h") * U
		var sh := BoxShape3D.new()
		sh.size = Vector3(w - 0.004, h - 0.01, w - 0.004)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sh
		q.transform = Transform3D(Basis.IDENTITY, body.global_position + Vector3(0, h * 0.5 - shift + 0.006, 0))
		q.collision_mask = body.collision_mask
		q.exclude = [body.get_rid()]
		var res := body.get_world_3d().direct_space_state.intersect_shape(q, 1)
		return res.is_empty()

	# --- ladders: Area3D in group "cdt_ladder" (or "ladder")

	func _find_ladder() -> Area3D:
		for g in ["cdt_ladder", "ladder"]:
			for n in get_tree().get_nodes_in_group(g):
				if n is Area3D and (n as Area3D).overlaps_body(body):
					return n
		return null

	func _ladder_move(f: float, s: float, pressed: bool) -> void:
		var sp := float(cfg["ladder_speed"]) * U
		var look_up := -sin(pitch) if own_view else 0.35
		var vy := f * sp * (1.0 if look_up >= -0.05 else -1.0)
		body.velocity = Vector3(0, vy, 0) + Basis(Vector3.UP, yaw).x * s * sp * 0.5
		if pressed:                                                       # jump off, away from the ladder
			body.velocity = Basis(Vector3.UP, yaw).z * sp * 0.9                # push off the ladder, away from the view
			body.velocity.y = sp * 0.6
			on_ladder = false
		body.move_and_slide()
