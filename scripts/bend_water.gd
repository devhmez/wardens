class_name WaterBender
extends Bender
# Water: sweeping whips that heal, frost lances, and a breaking wave.

var sweep := 1.0


func _init() -> void:
	moves = ["Tide Whip", "Frost Lances", "Breaker", "Frost Nova", "River Serpent"]
	costs = [0, 30, 50, 35, 80]


func light() -> void:
	if cd_light > 0.0:
		return
	cd_light = 0.42
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	p.face(a.dir, 0.5)
	p.slow(0.3)
	sweep = -sweep
	p.puppet.play("sweepR" if sweep > 0.0 else "sweepL")
	p.note_cast()
	Game.sfx("whip", null, -3.0)
	var head := Node3D.new()
	Game.main.add_child(head)
	head.global_position = p.chest()
	Trail.attach(head, 0.85, 0.3, Color(0.5, 0.82, 1.0, 0.95), Color(0.15, 0.5, 1.0, 0.0))
	Trail.attach(head, 0.28, 0.22, Color(1.6, 1.9, 2.0, 1.0), Color(1, 1, 1, 0.0), true)
	var drops := FX.particles({"amount": 36, "life": 0.5, "vmin": 0.5, "vmax": 2.5, "size": 0.38, "scurve": [1.0, 0.0],
		"gravity": Vector3(0, -9, 0), "colors": [Color(0.9, 0.98, 1.0, 1.0), Color(0.4, 0.75, 1.0, 0.0)], "radius": 0.25})
	head.add_child(drops)
	var yaw0 := atan2(fwd.x, fwd.z)
	var dur := 0.27
	var t := 0.0
	var struck := false
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / dur, 0.0, 1.0)
		var ang := yaw0 + sweep * lerpf(1.3, -1.3, k)
		var r := sin(k * PI) * 5.6 + 1.3
		var o: Vector3 = p.chest()
		head.global_position = o + Vector3(sin(ang), 0, cos(ang)) * r + Vector3(0, a.dir.y * r - 0.15 + sin(k * TAU) * 0.3, 0)
		if not struck and k >= 0.45:
			struck = true
			_whip_damage(o, fwd)
	FX.release(drops)
	head.queue_free()


func _whip_damage(o: Vector3, fwd: Vector3) -> void:
	var n := 0
	for t in Game.targets.duplicate():
		if not is_instance_valid(t) or t.dead:
			continue
		var to: Vector3 = t.aim_point() - o
		var f := Vector3(to.x, 0, to.z)
		var d := f.length()
		if d < 7.8 and absf(to.y) < 4.0 and (d < 1.8 or f.angle_to(fwd) < 1.2):
			t.take_hit(15.0, f.normalized() * 5.5 + Vector3.UP * 2.0, "water")
			FX.splash(t.aim_point(), 0.7, 10)
			n += 1
	if n > 0:
		p.heal(2.0 * n)
		Game.sfx("splash", null, -8.0)


func heavy_start() -> void:
	if cd_heavy > 0.0 or not p.spend(costs[1]):
		return
	cd_heavy = 1.3
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var right := fwd.cross(Vector3.UP).normalized()
	p.face(a.dir, 1.0)
	p.slow(0.7)
	p.puppet.play("raise")
	p.note_cast()
	Game.sfx("ice", null, -3.0)
	var shards: Array = []
	for i in 5:
		var s := Shot.new()
		s.active = false
		s.element = "water"
		s.dmg = 13.0
		s.push = 4.0
		s.lift = 1.0
		s.radius = 0.42
		s.life = 2.0
		s.align_y = true
		s.on_end = _shard_end
		var m := FX.prop("ice_shard")
		m.scale = Vector3.ONE * 1.6
		s.add_child(m)
		Game.main.add_child(s)
		var ang := lerpf(-1.15, 1.15, i / 4.0)
		var dest: Vector3 = p.global_position + right * sin(ang) * 1.7 + Vector3(0, 1.7 + cos(ang) * 1.1, 0) - fwd * 0.2
		s.global_position = p.chest()
		s.scale = Vector3.ONE * 0.1
		var tw := s.create_tween().set_parallel()
		tw.tween_property(s, "global_position", dest, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3.ONE, 0.26)
		shards.append(s)
	FX.ice_burst(p.chest() + Vector3(0, 0.8, 0), 0.8)
	await wait(0.44)
	for s2 in shards:
		if not is_instance_valid(s2):
			continue
		a = p.aim()
		s2.vel = (a.point - s2.global_position).normalized() * 52.0
		s2.homing = a.target
		s2.homing_rate = 7.0
		s2.active = true
		Trail.attach(s2, 0.32, 0.2, Color(1.4, 1.8, 2.0, 0.9), Color(0.5, 0.8, 1.0, 0.0), true)
		Game.sfx("ice_shot", s2.global_position, -7.0)
		await wait(0.07)


func _shard_end(pos: Vector3, _hit: bool) -> void:
	FX.ice_burst(pos, 1.0)
	Game.sfx("ice_hit", pos, -6.0)


func special() -> void:
	if cd_special > 0.0 or not p.spend(costs[2]):
		return
	cd_special = 2.4
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var right := fwd.cross(Vector3.UP).normalized()
	p.face(a.dir, 0.9)
	p.slow(0.8)
	p.puppet.play("shove")
	p.note_cast()
	p.heal(12.0)
	Game.sfx("wave")
	Game.shake(0.4)
	var node := Node3D.new()
	var mesh := FX.model("wave")
	var wm := FX.flow(Color(0.08, 0.42, 0.9, 0.93), Color(0.82, 0.96, 1.0, 1.0), {"scroll": Vector2(0.0, 0.7), "tiling": Vector2(3.0, 1.4),
		"cut": 0.47, "soft": 0.03, "solid": 1.0, "fresnel": 0.3, "energy": 1.1, "v_grad": 1.0, "v0": 0.33, "v1": 0.4})
	for mi in mesh.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = wm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.scale = Vector3(5.8, 2.3, 2.6)
	node.add_child(mesh)
	var foam := FX.particles({"amount": 70, "life": 0.7, "box": Vector3(5.5, 0.4, 0.6), "vmin": 1.0, "vmax": 5.0, "spread": 60.0,
		"size": 1.1, "scurve": [1.0, 0.3], "gravity": Vector3(0, -8, 0),
		"colors": [Color(0.95, 1.0, 1.0, 0.95), Color(0.6, 0.85, 1.0, 0.0)], "aabb": 12.0})
	foam.position = Vector3(0, 2.6, 0.6)
	node.add_child(foam)
	Game.main.add_child(node)
	var pos: Vector3 = p.global_position + fwd * 1.6
	node.global_position = pos
	node.rotation.y = atan2(fwd.x, fwd.z)
	node.scale = Vector3(0.3, 0.2, 0.3)
	node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var travelled := 0.0
	var done: Array = []
	while travelled < 25.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		pos += fwd * 19.0 * dt
		travelled += 19.0 * dt
		pos.y = lerpf(pos.y, maxf(Game.world.height_at(pos.x, pos.z), 0.0), 0.25)
		node.global_position = pos
		for t in Game.targets.duplicate():
			if not is_instance_valid(t) or t.dead or done.has(t):
				continue
			var rel: Vector3 = t.global_position - pos
			if absf(rel.dot(fwd)) < 2.2 and absf(rel.dot(right)) < 6.0 and absf(rel.y) < 4.5:
				done.append(t)
				t.take_hit(34.0, fwd * 17.0 + Vector3.UP * 5.0, "water")
				FX.splash(t.aim_point(), 1.0, 12)
	FX.splash(pos + Vector3(0, 0.8, 0), 2.6, 40)
	Game.sfx("splash", pos, 0.0, 0.8)
	FX.release(foam)
	var tw2 := node.create_tween()
	tw2.tween_property(node, "scale", Vector3(1.3, 0.05, 1.0), 0.25)
	tw2.tween_callback(node.queue_free)


func quick() -> void:
	# Frost Nova: freeze everything around you solid. Frozen enemies shatter for extra damage.
	if cd_q > 0.0 or not p.spend(costs[3]):
		return
	cd_q = 5.0
	p.puppet.play("burst")
	p.slow(0.4)
	p.note_cast()
	var feet: Vector3 = p.global_position
	var c := feet + Vector3(0, 1.0, 0)
	Game.sfx("ice", null, 1.0, 0.8)
	Game.sfx("shatter", null, -6.0, 1.3)
	Game.shake(0.4)
	FX.ring(feet, Color(0.7, 0.92, 1.0, 1.0), 1.0, 10.0, 0.45, 0.3, 0.15)
	FX.flash(c, Color(0.6, 0.85, 1.0), 8.0, 16.0, 0.4)
	FX.burst(c, {"amount": 90, "life": 0.6, "dir": Vector3(1, 0, 0), "spread": 180.0, "flat": 1.0, "vmin": 20.0, "vmax": 26.0,
		"damping": 28.0, "size": 1.3, "scurve": [0.5, 1.1, 0.2], "add": true, "aabb": 14.0,
		"colors": [Color(1.4, 1.8, 2.0, 0.9), Color(0.6, 0.85, 1.0, 0.5), Color(0.5, 0.8, 1.0, 0.0)]})
	for i in 12:
		var ang := i * TAU / 12.0 + randf() * 0.3
		var r := randf_range(2.5, 8.0)
		var pos: Vector3 = Game.floor_at(feet + Vector3(cos(ang), 0, sin(ang)) * r, 4.0)
		var sh := FX.prop("ice_shard")
		Game.main.add_child(sh)
		sh.global_position = pos + Vector3(0, -1.6, 0)
		sh.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		sh.scale = Vector3.ONE * randf_range(2.0, 3.6)
		var tw := sh.create_tween()
		tw.tween_property(sh, "global_position", pos + Vector3(0, -0.2, 0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.8)
		tw.tween_property(sh, "scale", Vector3.ZERO, 0.35)
		tw.tween_callback(sh.queue_free)
	for t in Game.targets.duplicate():
		if not is_instance_valid(t) or t.dead:
			continue
		if t.aim_point().distance_to(c) < 9.5 + t.hit_radius:
			t.take_hit(14.0, Vector3.ZERO, "water")
			if not t.dead and t.has_method("freeze"):
				t.freeze(3.2)


func ultimate() -> void:
	# River Serpent: a living stream that hunts enemy after enemy and heals you with each strike.
	if cd_ult > 0.0 or not p.spend(costs[4]):
		return
	cd_ult = 12.0
	p.puppet.play("raise")
	p.slow(0.8)
	p.note_cast()
	var a: Dictionary = p.aim()
	p.face(a.dir, 1.0)
	Game.sfx("wave", null, 2.0, 1.2)
	var head := Node3D.new()
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	ball.mesh = sm
	ball.material_override = FX.flow(Color(0.1, 0.5, 0.95, 0.95), Color(0.9, 0.98, 1.0, 1.0), {"scroll": Vector2(0.6, 1.2), "tiling": Vector2(2.0, 2.0),
		"cut": 0.45, "soft": 0.05, "solid": 1.0, "fresnel": 0.8, "energy": 1.3})
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(ball)
	head.add_child(FX.particles({"amount": 50, "life": 0.6, "vmin": 0.5, "vmax": 3.0, "size": 0.5, "scurve": [1.0, 0.0],
		"gravity": Vector3(0, -9, 0), "radius": 0.5, "colors": [Color(0.9, 0.98, 1.0, 1.0), Color(0.4, 0.75, 1.0, 0.0)]}))
	Game.main.add_child(head)
	var pos: Vector3 = p.chest() + Vector3(0, 1.2, 0)
	head.global_position = pos
	Trail.attach(head, 1.5, 0.75, Color(0.2, 0.6, 1.0, 0.95), Color(0.1, 0.4, 0.95, 0.0))
	Trail.attach(head, 0.5, 0.55, Color(1.6, 1.9, 2.0, 1.0), Color(1, 1, 1, 0.0), true)
	FX.splash(pos, 1.5, 20)
	var struck: Array = []
	for hop in 7:
		var foes := nearest_targets(pos, 34.0)
		var foe = null
		for f in foes:
			if not struck.has(f):
				foe = f
				break
		if foe == null and not foes.is_empty() and hop < 4:
			struck.clear()
			foe = foes[0]
		var from := pos
		var dest: Vector3 = foe.aim_point() if foe != null else from + flat(a.dir) * 16.0
		var mid := (from + dest) * 0.5 + Vector3(randf_range(-4, 4), randf_range(2.5, 5.0), randf_range(-4, 4))
		var dur := clampf(from.distance_to(dest) / 30.0, 0.22, 0.6)
		var t := 0.0
		while t < dur:
			await get_tree().process_frame
			t += get_process_delta_time()
			var k := clampf(t / dur, 0.0, 1.0)
			if foe != null and is_instance_valid(foe) and not foe.dead:
				dest = foe.aim_point()
			pos = from.lerp(mid, k).lerp(mid.lerp(dest, k), k)
			head.global_position = pos
		if foe != null and is_instance_valid(foe) and not foe.dead:
			struck.append(foe)
			foe.take_hit(38.0, (dest - mid).normalized() * 6.0 + Vector3.UP * 6.0, "water")
			FX.splash(dest, 1.6, 24)
			Game.sfx("splash", dest, -2.0)
			Game.shake(0.2, dest)
			p.heal(5.0)
		if foe == null:
			break
	FX.splash(pos, 2.2, 36)
	for c in head.get_children():
		if c is GPUParticles3D:
			FX.release(c)
	head.queue_free()
