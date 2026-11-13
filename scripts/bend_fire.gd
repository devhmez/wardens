class_name FireBender
extends Bender
# Fire: rapid ember jabs, a sustained flame stream, and a spinning sunwheel.

const FLAME := [Color(1.9, 1.5, 0.7, 0.85), Color(1.7, 0.62, 0.1, 0.7), Color(0.9, 0.13, 0.02, 0.4), Color(0.15, 0.03, 0.01, 0.0)]

const STREAM := [Color(1.7, 1.15, 0.45, 0.6), Color(1.7, 0.6, 0.1, 0.7), Color(1.0, 0.15, 0.02, 0.45), Color(0.15, 0.03, 0.01, 0.0)]

var hand := 1
var streaming := false
var stream: GPUParticles3D
var stream_light: OmniLight3D
var _tick := 0.0


func _init() -> void:
	moves = ["Ember Jab", "Flame Stream", "Sunwheel", "Blaze Dash", "Meteor"]
	costs = [0, 26, 45, 25, 80]


func light() -> void:
	if cd_light > 0.0 or streaming:
		return
	cd_light = 0.2
	var a: Dictionary = p.aim()
	p.face(a.dir, 0.4)
	p.slow(0.12)
	hand = -hand
	p.puppet.play("punchR" if hand > 0 else "punchL")
	p.note_cast()
	await wait(0.07)
	a = p.aim()
	var fwd := flat(a.dir)
	var from: Vector3 = p.chest() + fwd * 0.9 + fwd.cross(Vector3.UP) * hand * 0.35 + Vector3(0, 0.15, 0)
	var s := Shot.new()
	s.element = "fire"
	s.dmg = 11.0
	s.push = 3.0
	s.lift = 1.0
	s.radius = 0.45
	s.life = 1.5
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	core.mesh = sm
	core.material_override = FX.glow_mat(Color(1.0, 0.8, 0.4), 4.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(core)
	s.add_child(FX.particles({"amount": 22, "life": 0.34, "vmin": 0.2, "vmax": 1.6, "size": 1.15, "scurve": [0.9, 1.0, 0.5],
		"flame": true, "colors": FX.FADE, "radius": 0.12}))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 6.0
	s.add_child(l)
	s.on_end = _ball_end
	Game.main.add_child(s)
	s.global_position = from
	s.vel = (a.point - from).normalized() * 46.0
	Game.sfx("fire_shot", from, -6.0)


func _ball_end(pos: Vector3, _hit: bool) -> void:
	FX.fire_burst(pos, 0.9, 16)
	FX.flash(pos, Color(1.0, 0.5, 0.2), 5.0, 7.0, 0.2)
	Game.sfx("fire_hit", pos, -5.0)
	Game.shake(0.08, pos)


func _make_stream() -> void:
	stream = FX.particles({"amount": 60, "life": 0.55, "dir": Vector3(0, 0, -1), "spread": 6.0, "vmin": 17.0, "vmax": 22.0,
		"size": 2.2, "scurve": [0.12, 0.7, 1.4], "damping": 2.5, "flame": true, "energy": 0.7, "colors": FX.FADE,
		"gravity": Vector3(0, 2.5, 0), "aabb": 16.0})
	stream.emitting = false
	Game.main.add_child(stream)
	stream_light = OmniLight3D.new()
	stream_light.light_color = Color(1.0, 0.5, 0.2)
	stream_light.omni_range = 14.0
	stream_light.light_energy = 0.0
	stream.add_child(stream_light)
	stream_light.position = Vector3(0, 0, -4.0)


func heavy_start() -> void:
	if p.chi < 6.0:
		p.spend(999.0)
		return
	if stream == null:
		_make_stream()
	streaming = true
	_tick = 0.0
	p.puppet.play("channel")
	p.note_cast()
	Game.loop("fire_loop", true, -5.0)


func heavy_hold(dt: float) -> void:
	if not streaming:
		return
	if p.chi < costs[1] * dt:
		heavy_end()
		return
	p.chi -= costs[1] * dt
	var a: Dictionary = p.aim()
	p.face(a.dir, 0.2)
	p.slow(0.2)
	if p.puppet.action != "channel":
		p.puppet.play("channel")
	var from: Vector3 = p.chest() + flat(a.dir) * 0.9 + Vector3(0, 0.1, 0)
	var dirn: Vector3 = (a.point - from).normalized()
	stream.global_position = from
	if absf(dirn.y) < 0.98:
		stream.look_at(from + dirn)
	stream.emitting = true
	stream_light.light_energy = 5.0 + sin(Time.get_ticks_msec() * 0.03) * 1.2
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.2
		Game.shake(0.05)
		for t in Game.targets.duplicate():
			if not is_instance_valid(t) or t.dead:
				continue
			var to: Vector3 = t.aim_point() - from
			var d := to.length()
			if d < 11.0 and (dirn.angle_to(to) < 0.36 + 0.6 / maxf(d, 1.0)):
				t.take_hit(7.0, dirn * 2.0, "fire")


func heavy_end() -> void:
	if not streaming:
		return
	streaming = false
	if stream:
		stream.emitting = false
		stream_light.light_energy = 0.0
	p.puppet.stop("channel")
	Game.loop("fire_loop", false)


func special() -> void:
	if cd_special > 0.0 or not p.spend(costs[2]):
		return
	cd_special = 2.0
	heavy_end()
	p.slow(0.6)
	p.puppet.play("spin")
	p.note_cast()
	var tw: Tween = p.create_tween()
	tw.tween_property(p.puppet, "spin", TAU, 0.42).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): p.puppet.spin = 0.0)
	Game.sfx("fire_shot", null, 0.0, 0.6)
	await wait(0.13)
	var feet: Vector3 = p.global_position
	var c := feet + Vector3(0, 0.9, 0)
	Game.shake(0.65)
	Game.sfx("explode")
	Game.hitstop(0.05)
	FX.ring(feet, Color(1.0, 0.45, 0.12, 0.8), 1.0, 9.5, 0.5, 0.3, 0.1)
	FX.flash(c, Color(1.0, 0.5, 0.2), 7.0, 18.0, 0.45)
	FX.burst(c, {"amount": 64, "life": 0.6, "dir": Vector3(1, 0, 0), "spread": 180.0, "flat": 1.0, "vmin": 20.0, "vmax": 26.0,
		"damping": 26.0, "size": 2.3, "scurve": [0.5, 1.2, 0.8], "flame": true, "colors": FX.FADE, "gravity": Vector3(0, 6, 0), "aabb": 14.0})
	FX.burst(feet + Vector3(0, 0.3, 0), {"amount": 64, "life": 0.9, "ring": 7.5, "ring_h": 0.3, "dir": Vector3.UP, "spread": 12.0,
		"vmin": 4.0, "vmax": 9.0, "size": 2.4, "scurve": [0.8, 1.0, 0.7], "flame": true, "upright": true, "colors": FX.FADE, "explosive": 0.6, "aabb": 14.0})
	FX.embers(c, 2.2, 40)
	Game.hit_sphere(c, 9.0, 38.0, 9.0, 5.0, "fire")


func _fire_patch(pos: Vector3, dur := 2.6) -> void:
	var fl := FX.particles({"amount": 14, "life": 0.8, "vmin": 0.8, "vmax": 2.4, "dir": Vector3.UP, "spread": 16.0, "size": 2.0,
		"scurve": [0.7, 1.0, 0.8], "flame": true, "upright": true, "radius": 0.8, "gravity": Vector3(0, 3, 0), "colors": FX.FADE})
	Game.main.add_child(fl)
	fl.global_position = pos + Vector3(0, 0.2, 0)
	var t := 0.0
	while t < dur:
		await wait(0.4)
		t += 0.4
		Game.hit_sphere(pos + Vector3(0, 0.6, 0), 1.7, 4.0, 0.0, 0.0, "fire")
	if is_instance_valid(fl):
		fl.emitting = false
		FX._free_later(fl, 1.0)


func quick() -> void:
	# Blaze Dash: rocket forward as a comet, burning everything on the way.
	if cd_q > 0.0 or not p.spend(costs[3]):
		return
	cd_q = 2.5
	heavy_end()
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	p.face(fwd, 0.5)
	p.puppet.play("dash_strike")
	p.note_cast()
	p.dash_dir = fwd
	p.dash_speed = 36.0
	p.dash_t = 0.34
	p.iframes = maxf(p.iframes, 0.5)
	Game.cam.fov_kick = 14.0
	Game.sfx("fire_shot", null, 0.0, 0.6)
	Game.sfx("dash", null, -2.0, 0.8)
	var anchor := Node3D.new()
	p.add_child(anchor)
	anchor.position = Vector3(0, 1.0, 0)
	Trail.attach(anchor, 1.6, 0.35, Color(2.2, 1.0, 0.25, 0.9), Color(1.0, 0.15, 0.0, 0.0), true)
	var fire := FX.particles({"amount": 50, "life": 0.5, "vmin": 0.5, "vmax": 3.0, "size": 2.0, "scurve": [0.8, 1.0, 0.6], "flame": true,
		"radius": 0.6, "gravity": Vector3(0, 3, 0), "colors": FX.FADE})
	anchor.add_child(fire)
	var done: Array = []
	var t := 0.0
	var last_patch: Vector3 = p.global_position
	while t < 0.34:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var c: Vector3 = p.chest()
		for foe in Game.targets.duplicate():
			if not is_instance_valid(foe) or foe.dead or done.has(foe):
				continue
			if foe.aim_point().distance_to(c) < 2.5 + foe.hit_radius:
				done.append(foe)
				var side: Vector3 = fwd.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
				foe.take_hit(26.0, side * 7.0 + fwd * 3.0 + Vector3.UP * 5.0, "fire")
				FX.fire_burst(foe.aim_point(), 0.9, 12)
		if p.global_position.distance_to(last_patch) > 2.6:
			last_patch = p.global_position
			_fire_patch(Game.floor_at(last_patch, 2.0))
	FX.fire_burst(p.chest(), 1.4, 24)
	FX.release(fire)
	anchor.queue_free()


func ultimate() -> void:
	# Meteor: call a burning rock down from the sky onto the aimed spot.
	if cd_ult > 0.0 or not p.spend(costs[4]):
		return
	cd_ult = 12.0
	heavy_end()
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var to: Vector3 = a.point - p.global_position
	to.y = 0.0
	var point: Vector3 = Game.floor_at(p.global_position + fwd * clampf(to.length(), 5.0, 36.0), 12.0)
	p.face(a.dir, 1.2)
	p.slow(1.0)
	p.puppet.play("raise")
	p.note_cast()
	Game.sfx("fire_shot", null, 2.0, 0.45)
	FX.ring(point, Color(1.0, 0.35, 0.1, 0.9), 9.5, 9.6, 1.0, 0.1, 0.25)
	FX.ring(point, Color(1.0, 0.6, 0.2, 1.0), 9.5, 0.5, 1.0, 0.25)
	var m := Node3D.new()
	var rock := FX.model("rock_1")
	for mi in rock.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = FX.glow_mat(Color(1.0, 0.5, 0.15), 3.0)
	rock.scale = Vector3.ONE * 3.2
	m.add_child(rock)
	m.add_child(FX.particles({"amount": 70, "life": 0.7, "vmin": 0.5, "vmax": 4.0, "size": 4.6, "scurve": [0.9, 1.0, 0.6], "flame": true,
		"radius": 1.2, "colors": FX.FADE, "aabb": 40.0}))
	m.add_child(FX.particles({"amount": 40, "life": 1.6, "vmin": 0.3, "vmax": 2.0, "size": 4.0, "scurve": [0.5, 1.3], "radius": 1.0, "aabb": 40.0,
		"colors": [Color(0.1, 0.08, 0.08, 0.0), Color(0.12, 0.1, 0.1, 0.6), Color(0.2, 0.2, 0.2, 0.0)]}))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 14.0
	l.omni_range = 26.0
	m.add_child(l)
	Game.main.add_child(m)
	var start := point + Vector3(0, 34, 0) - fwd * 16.0
	m.global_position = start
	Trail.attach(m, 3.0, 0.5, Color(2.4, 1.1, 0.3, 0.9), Color(1.0, 0.1, 0.0, 0.0), true)
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", point, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rock.create_tween().tween_property(rock, "rotation", Vector3(7, 3, 5), 0.95)
	await wait(0.78)
	p.puppet.play("stomp")
	await wait(0.17)
	Game.hitstop(0.09)
	Game.shake(1.0)
	Game.sfx("explode", null, 3.0, 0.8)
	Game.sfx("boom", null, 2.0, 0.6)
	FX.flash(point + Vector3(0, 2, 0), Color(1.0, 0.55, 0.2), 30.0, 40.0, 0.7)
	FX.fire_burst(point + Vector3(0, 1, 0), 3.4, 70)
	FX.ring(point, Color(1.0, 0.5, 0.15, 1.0), 1.0, 12.0, 0.6, 0.3, 0.2)
	FX.dust(point, 3.0, 30)
	FX.debris(point, 12, 13.0, 0.4)
	FX.crack(point, 15.0)
	FX.rubble(point, 3.2, 8)
	FX.embers(point + Vector3(0, 1, 0), 3.0, 60)
	FX.burst(point + Vector3(0, 0.5, 0), {"amount": 80, "life": 0.7, "dir": Vector3(1, 0, 0), "spread": 180.0, "flat": 1.0, "vmin": 22.0,
		"vmax": 30.0, "damping": 26.0, "size": 3.2, "scurve": [0.5, 1.2, 0.8], "flame": true, "colors": FX.FADE, "aabb": 16.0})
	Game.hit_sphere(point + Vector3(0, 1, 0), 9.6, 90.0, 14.0, 10.0, "fire")
	for c in m.get_children():
		if c is GPUParticles3D:
			FX.release(c)
	m.queue_free()
	for i in 6:
		var ang := i * TAU / 6.0
		_fire_patch(Game.floor_at(point + Vector3(cos(ang), 0, sin(ang)) * 4.0, 4.0), 3.2)
