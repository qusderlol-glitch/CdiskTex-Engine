# CdiskTex Engine (CDT) — Center Diskent Tex

One GDScript file for Godot 4.4+. Drop it into any 3D project and get Counter-Strike style movement:
bunnyhop, air strafing, crouch, stair stepping, ladders, 64 tick, CS mouse sensitivity.
It installs itself and shows the CdiskTex logo before your game starts. Free.

![CdiskTex logo](logo_preview.png)

## Download
Click **Code → Download ZIP** on this page, or download `cdisktex_engine.gd` directly.
Website with the same download: open `index.html` (or enable GitHub Pages for this repo).

## Install
**A. Autoload:** copy `cdisktex_engine.gd` into your project, then Project → Project Settings → Globals → Autoload,
pick the file, name it `CDT`, press Add.

**B. Attach once:** copy the file, attach it as a script to any Node in any scene. It is a `@tool` script,
so it registers itself as the `CDT` autoload and saves `project.godot`.

Run the game. CDT takes over `CharacterBody3D` nodes named `player` (or in group `player` / `cdt_player`,
origin at the feet) or spawns its own first-person player.

## Controls
WASD move · Space / mouse wheel jump · Ctrl crouch · Shift walk · F2 settings panel · F3 HUD · F4 next preset · F5 autohop · F6/F7 sensitivity

## API
```gdscript
CDT.set_preset("csgo")            # cs2 | csgo | css | hl2
CDT.spawn_player(Vector3(0, 1, 0))
CDT.attach(my_body)               # CharacterBody3D, origin at the feet
CDT.cfg["autohop"] = true
CDT.save_cfg()
```

## Use it with your own player (1.1)
CDT finds your player by itself (the body that carries the current camera). To keep your own camera, recoil and
interaction code, add this to your `CharacterBody3D` script and CDT drives only the movement:
```gdscript
func _cdt_attached(c) -> void:
	c.map_actions({"forward": "move_forward", "back": "move_back", "left": "move_left",
		"right": "move_right", "jump": "jump", "duck": "crouch", "walk": ""})
	c.wheel_jump = false
	# every tick: c.ducked, c.duck_t, c.view_comp for the camera height,
	# c.input_blocked = true during menus, c.enabled = false while you move the body yourself
```

## Changes in 1.1.0
Finds the player by its camera, keeps your collision size, per-body input mapping, F2 settings panel,
HUD moves out of the way of your own HUD, no second player is spawned when you already have one.

## Measured (Godot 4.4.1, 64 tick)
Jump apex 57.0 u · 0→250 u/s in 12 ticks · stop in 26 ticks · ~460 u/s after 11 air-strafed hops (cs2/css) ·
17 u step climbed, 19 u blocked.

## Limits
No sub-tick input, no CS:GO stamina, approximate surfing, 3D only. Independent re-implementation of the
published movement formulas; not Source or Source 2 and contains no Valve code. Not affiliated with Valve.

## License
MIT, see `LICENSE`.
