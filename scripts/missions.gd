class_name Missions
extends Node
# Chapter One of the story: three missions, then free roam.

const SAVE := "user://wardens_save.json"
const MAX := 3

var index := 0
var enemies: Array = []
var hud
var world
var pl
var _smoke: Array = []


static func load_index() -> int:
	if not FileAccess.file_exists(SAVE):
		return -1
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.has("mission"):
		return int(d["mission"])
	return -1


func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"mission": index}))


func begin(from: int) -> void:
	hud = Game.hud
	world = Game.world
	pl = Game.player
	index = clampi(from, 0, MAX)
	var starts := [world.ground(World.SHRINE.x, World.SHRINE.y, 1.0), world.ground(World.SHRINE.x + 17.0, World.SHRINE.y - 2.0, 1.0),
		world.ground(World.VILLAGE.x, World.VILLAGE.y - 20.0, 1.0), world.ground(World.VILLAGE.x, World.VILLAGE.y, 1.0)]
	var moods := ["dawn", "dawn", "sunset", "day"]
	pl.global_position = starts[index]
	pl.checkpoint = starts[index]
	pl.last_safe = starts[index]
	world.apply_mood(World.MOODS[moods[index]])
	Game.cam.yaw = -PI * 0.5
	Game.cam.snap()
	_run()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	while index < MAX:
		match index:
			0:
				await _first_light()
			1:
				await _smoke_over_mirren()
			2:
				await _hollow_gate()
		index += 1
		save()
	_free_roam()


func _until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().create_timer(0.15, false).timeout


func _alive() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n


func spawn(kind: String, pos: Vector3, idle := false) -> Enemy:
	var e := Enemy.new()
	e.setup(kind)
	Game.main.add_child(e)
	var g: Vector3 = Game.floor_at(pos, 12.0)
	e.global_position = g + Vector3(0, 0.3, 0)
	e.alerted = not idle
	if idle:
		e.aggro = 24.0
	FX.wisps(g + Vector3(0, 1, 0), Game.EL_COLORS["dark"], 1.3 * e.size, 22)
	FX.ring(g, Color(0.75, 0.4, 1.0, 0.9), 0.3, 2.6 * e.size, 0.5, 0.3)
	Game.sfx("spawn", g, -6.0)
	enemies.append(e)
	return e


func _ring_pos(center: Vector2, rmin: float, rmax: float) -> Vector3:
	for i in 20:
		var a := randf() * TAU
		var r := randf_range(rmin, rmax)
		var x := center.x + cos(a) * r
		var z := center.y + sin(a) * r
		if world.height_at(x, z) > 1.0:
			return Vector3(x, world.height_at(x, z), z)
	return world.ground(center.x, center.y)


# ------------------------------------------------------------------ Mission 1
func _first_light() -> void:
	var sh: Vector3 = world.ground(World.SHRINE.x, World.SHRINE.y)
	pl.checkpoint = sh + Vector3(0, 1.0, 0)
	hud.banner("FIRST LIGHT", "Chapter I  -  The Dawn Shrine")
	await get_tree().create_timer(3.2, false).timeout
	await hud.say("ELDER MARO", "Four Wardens, one breath. The shrine woke you all at once - so learn to move as one.")
	var state := {"broken": 0, "used": {}}
	var total := 6
	for i in total:
		var a := i * TAU / total + 0.3
		var b := Breakable.new()
		b.setup("totem")
		Game.main.add_child(b)
		var p: Vector3 = Game.floor_at(sh + Vector3(cos(a) * 6.2, 2.0, sin(a) * 6.2), 4.0)
		b.global_position = p
		b.rotation.y = -a + PI * 0.5
		FX.dust(p, 1.0, 8)
		b.broken.connect(func(_b): state["broken"] += 1)
	var on_cast := func(e: String): state["used"][e] = true
	pl.cast.connect(on_cast)
	hud.hint = "Aim with the mouse  -  %s  %s  E  Q to bend  -  R ultimate  -  1 2 3 4 to change Warden" % [Game.key_label("light"), Game.key_label("heavy")]
	while state["broken"] < total or state["used"].size() < 4:
		hud.set_objective("First Light", "Break the training totems   %d / %d\nBend with every Warden   %d / 4" % [state["broken"], total, state["used"].size()])
		await get_tree().create_timer(0.15, false).timeout
	pl.cast.disconnect(on_cast)
	hud.hint = ""
	hud.set_objective("First Light", "")
	Game.sfx("chime")
	await hud.say("ELDER MARO", "Good. Earth holds. Fire strikes. Water mends. Air moves. Know which one the moment needs.")
	await hud.say("ELDER MARO", "Smoke over Mirren - the Ashen have come down from the ridge. Take the east road. Go!")


# ------------------------------------------------------------------ Mission 2
func _smoke_over_mirren() -> void:
	world.set_mood("sunset", 9.0)
	hud.banner("SMOKE OVER MIRREN", "Chapter II  -  The Lake Village")
	var vc: Vector3 = world.ground(World.VILLAGE.x, World.VILLAGE.y)
	for off in [Vector3(-13, 5, -9), Vector3(10, 5, -14), Vector3(-4, 5, 16.5)]:
		var sm := FX.particles({"amount": 40, "life": 5.0, "vmin": 1.5, "vmax": 3.0, "dir": Vector3(0.3, 1, 0.1), "spread": 14.0,
			"size": 5.0, "scurve": [0.3, 1.0, 1.4], "radius": 1.0, "aabb": 30.0,
			"colors": [Color(0.12, 0.1, 0.12, 0.0), Color(0.14, 0.12, 0.14, 0.75), Color(0.25, 0.22, 0.25, 0.0)]})
		Game.main.add_child(sm)
		sm.global_position = vc + off
		var fl := FX.particles({"amount": 18, "life": 1.0, "vmin": 1.0, "vmax": 3.0, "dir": Vector3.UP, "spread": 18.0, "size": 3.4,
			"scurve": [0.7, 1.0, 0.8], "flame": true, "upright": true, "radius": 1.1, "gravity": Vector3(0, 3, 0), "colors": FX.FADE})
		Game.main.add_child(fl)
		fl.global_position = vc + off + Vector3(0, -0.5, 0)
		_smoke.append(sm)
		_smoke.append(fl)
	hud.set_objective("Smoke over Mirren", "Follow the east road to Mirren village")
	hud.marker = vc
	await _until(func(): return pl.global_position.distance_to(vc) < 36.0)
	hud.marker = null
	pl.checkpoint = world.ground(World.VILLAGE.x - 30.0, World.VILLAGE.y + 5.0, 1.0)
	var waves := [["grunt", "grunt", "grunt", "grunt"], ["grunt", "grunt", "grunt", "caster", "caster"],
		["brute", "grunt", "grunt", "caster", "caster"]]
	for w in waves.size():
		hud.toast("Wave %d of %d" % [w + 1, waves.size()])
		for k in waves[w]:
			spawn(k, _ring_pos(World.VILLAGE, 7.0, 15.0))
			await get_tree().create_timer(0.25, false).timeout
		while _alive() > 0:
			hud.set_objective("Smoke over Mirren", "Drive the Ashen out of Mirren   -   wave %d / %d\n%d remaining" % [w + 1, waves.size(), _alive()])
			await get_tree().create_timer(0.15, false).timeout
		await get_tree().create_timer(1.2, false).timeout
	for s in _smoke:
		s.emitting = false
	hud.set_objective("Smoke over Mirren", "")
	Game.sfx("chime")
	pl.heal(100.0)
	await hud.say("VILLAGER", "They came through the Hollow Gate on the north ridge. Their crystals are poisoning the ground up there.")
	await hud.say("ELDER MARO", "Then break the crystals, Wardens. And whatever guards them - end it.")


# ------------------------------------------------------------------ Mission 3
func _hollow_gate() -> void:
	world.set_mood("dusk", 10.0)
	hud.banner("THE HOLLOW GATE", "Chapter III  -  The North Ridge")
	var fc: Vector3 = world.ground(World.FORT.x, World.FORT.y)
	var state := {"broken": 0}
	for i in 3:
		var a := i * TAU / 3.0 - PI * 0.5
		var cp: Vector3 = fc + Vector3(cos(a) * 12.5, 0, sin(a) * 12.5)
		cp.y = world.height_at(cp.x, cp.z) - 0.1
		var c := Breakable.new()
		c.setup("crystal")
		Game.main.add_child(c)
		c.global_position = cp
		c.broken.connect(func(_b): state["broken"] += 1)
		spawn("grunt", cp + Vector3(cos(a + 0.5) * 3.5, 0, sin(a + 0.5) * 3.5), true)
		spawn("caster" if i != 0 else "brute", cp + Vector3(cos(a - 0.5) * 3.5, 0, sin(a - 0.5) * 3.5), true)
	hud.set_objective("The Hollow Gate", "Climb the north road to the Hollow Gate")
	hud.marker = fc + Vector3(0, 0, 24)
	await _until(func(): return pl.global_position.distance_to(fc) < 42.0)
	hud.marker = null
	pl.checkpoint = world.ground(World.FORT.x, World.FORT.y + 38.0, 1.0)
	while state["broken"] < 3:
		hud.set_objective("The Hollow Gate", "Shatter the corruption crystals   %d / 3" % state["broken"])
		await get_tree().create_timer(0.15, false).timeout
	hud.set_objective("The Hollow Gate", "")
	await get_tree().create_timer(1.0, false).timeout
	hud.banner("VARRIK", "The Hollow King", 3.2)
	Game.shake(0.8)
	FX.flash(fc + Vector3(0, 3, 0), Color(0.8, 0.3, 1.0), 20.0, 40.0, 1.2)
	FX.ring(fc, Color(0.8, 0.3, 1.0, 1.0), 1.0, 20.0, 1.0, 0.2)
	Game.sfx("explode", null, 0.0, 0.6)
	var boss := spawn("king", fc)
	boss.summon.connect(_on_summon)
	hud.boss = boss
	hud.boss_name = "VARRIK,  THE HOLLOW KING"
	hud.set_objective("The Hollow Gate", "Defeat Varrik, the Hollow King")
	await _until(func(): return not is_instance_valid(boss) or boss.dead)
	hud.boss = null
	Game.hitstop(0.25)
	Game.shake(1.0)
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			e.die()
	world.set_mood("day", 7.0)
	hud.set_objective("The Hollow Gate", "")
	Game.sfx("chime")
	pl.heal(100.0)
	await get_tree().create_timer(2.0, false).timeout
	await hud.say("ELDER MARO", "The ridge is quiet. Aerath breathes again - because the four of you moved as one.")
	hud.banner("AERATH IS FREE", "Chapter One complete", 5.0)
	await get_tree().create_timer(5.0, false).timeout


func _on_summon(b) -> void:
	hud.toast("Varrik calls the Ashen!")
	for i in 3:
		var a2 := i * TAU / 3.0
		spawn("grunt", b.global_position + Vector3(cos(a2) * 5.0, 0, sin(a2) * 5.0))


# ------------------------------------------------------------------ after the story
func _free_roam() -> void:
	hud.set_objective("Free roam", "The island is yours. Ashen patrols still wander - hunt them down.")
	pl.checkpoint = world.ground(World.SHRINE.x, World.SHRINE.y, 1.0)
	while true:
		await get_tree().create_timer(6.0, false).timeout
		if _alive() == 0:
			var c := Vector2(pl.global_position.x, pl.global_position.z)
			var pack := ["grunt", "grunt", "caster", "grunt"]
			if randf() < 0.4:
				pack.append("brute")
			for k in pack:
				spawn(k, _ring_pos(c, 22.0, 32.0))
