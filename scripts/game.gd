extends Node
# Global state shared by every system (autoloaded as "Game").

const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_DEBRIS := 8

const EL_COLORS := {
	"earth": Color(0.45, 0.78, 0.36),
	"fire": Color(1.0, 0.45, 0.2),
	"water": Color(0.3, 0.68, 1.0),
	"air": Color(0.75, 0.98, 0.92),
	"dark": Color(0.72, 0.38, 1.0),
}

var main: Node3D
var world
var player
var cam
var hud
var missions
var targets: Array = []
var input_enabled := false
var autopilot := false
var started := false
var music: AudioStreamPlayer

var _pool: Array = []
var _pool_i := 0
var _streams := {}
var _loops := {}
var _hs := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	autopilot = "--shots" in args or "--story" in args or "--bench" in args or "--lineup" in args or "--moves" in args
	_setup_input()
	for i in 20:
		var a := AudioStreamPlayer.new()
		add_child(a)
		_pool.append(a)


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("dash", [KEY_SHIFT])
	_key("special", [KEY_E])
	_key("quick", [KEY_Q])
	_key("ultimate", [KEY_R])
	_key("interact", [KEY_F, KEY_ENTER])
	_key("el_1", [KEY_1])
	_key("el_2", [KEY_2])
	_key("el_3", [KEY_3])
	_key("el_4", [KEY_4])
	_key("el_next", [KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("fullscreen", [KEY_F11])
	_key("quality", [KEY_F10])
	_key("new_game", [KEY_N])
	_mouse("light", MOUSE_BUTTON_LEFT)
	_mouse("heavy", MOUSE_BUTTON_RIGHT)


func _key(action: String, codes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for c in codes:
		var e := InputEventKey.new()
		e.physical_keycode = c
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func key_label(action: String) -> String:
	# Name of the key as printed on the user's keyboard layout (QWERTY, AZERTY, ...).
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: int = e.physical_keycode
			if k == KEY_SPACE:
				return "SPACE"
			if k == KEY_SHIFT:
				return "SHIFT"
			if k >= KEY_0 and k <= KEY_9:
				return str(k - KEY_0)
			var kc := DisplayServer.keyboard_get_keycode_from_physical(k)
			var s := OS.get_keycode_string(kc)
			return s.to_upper() if s != "" else OS.get_keycode_string(k)
		if e is InputEventMouseButton:
			return "LMB" if e.button_index == MOUSE_BUTTON_LEFT else "RMB"
	return "?"


func move_keys() -> String:
	var out := ""
	for a in ["move_forward", "move_left", "move_back", "move_right"]:
		out += key_label(a)
	return out


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif e.is_action_pressed("quality") and world != null:
		world.env.sdfgi_enabled = not world.env.sdfgi_enabled
		if hud:
			hud.toast("Bounced lighting: " + ("ON" if world.env.sdfgi_enabled else "OFF  (faster)"))
	elif e.is_action_pressed("pause") and started and not autopilot:
		var p := not get_tree().paused
		get_tree().paused = p
		hud.paused = p
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ combat helpers
func register(t: Node) -> void:
	if not targets.has(t):
		targets.append(t)


func unregister(t: Node) -> void:
	targets.erase(t)


func hit_sphere(center: Vector3, radius: float, dmg: float, push: float, lift: float, element: String) -> int:
	var n := 0
	for t in targets.duplicate():
		if not is_instance_valid(t) or t.dead:
			continue
		var c: Vector3 = t.aim_point()
		if c.distance_to(center) <= radius + t.hit_radius:
			var dir: Vector3 = c - center
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.05 else Vector3.FORWARD
			t.take_hit(dmg, dir * push + Vector3.UP * lift, element)
			n += 1
	return n


func floor_at(pos: Vector3, up := 6.0, down := 40.0) -> Vector3:
	# Nearest walkable surface below a point (terrain, platforms, raised stone).
	var space := main.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * up, pos - Vector3.UP * down, L_WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	return hit.position


func hitstop(d := 0.05) -> void:
	_hs += 1
	var id := _hs
	Engine.time_scale = 0.06
	await get_tree().create_timer(d, true, false, true).timeout
	if id == _hs:
		Engine.time_scale = 1.0


func shake(amount: float, at = null) -> void:
	if cam == null:
		return
	if at != null and player != null:
		var d: float = player.global_position.distance_to(at)
		amount *= clampf(1.0 - d / 45.0, 0.0, 1.0)
	cam.trauma = minf(1.0, cam.trauma + amount)


# ------------------------------------------------------------------ audio
func _stream(sname: String):
	if _streams.has(sname):
		return _streams[sname]
	var path := "res://assets/sfx/%s.wav" % sname
	var s = load(path) if ResourceLoader.exists(path) else null
	_streams[sname] = s
	return s


func sfx(sname: String, at = null, vol := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	var s = _stream(sname)
	if s == null:
		return
	if at != null and player != null:
		var d: float = player.global_position.distance_to(at)
		if d > 70.0:
			return
		vol -= d * 0.35
	var a: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	a.stream = s
	a.volume_db = vol
	a.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	a.play()


func loop(sname: String, on: bool, vol := -6.0) -> void:
	if not _loops.has(sname):
		var s = _stream(sname)
		if s == null:
			return
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		var a := AudioStreamPlayer.new()
		a.stream = s
		add_child(a)
		_loops[sname] = a
	var p: AudioStreamPlayer = _loops[sname]
	p.volume_db = vol
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()
