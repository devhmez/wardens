class_name AirBender
extends Bender
# Air: wide gale blasts, a cyclone that lifts enemies, and a launching tempest.
# Passive: double jump and glide (handled by the player).

var hand := 1


func _init() -> void:
	moves = ["Gale Palm", "Cyclone", "Tempest", "Vacuum", "Skyfall"]
	costs = [0, 35, 40, 25, 80]


func light() -> void:
	if cd_light > 0.0:
		return
	cd_light = 0.3
	var a: Dictionary = p.aim()
	p.face(a.dir, 0.4)
	p.slow(0.15)
	hand = -hand
	p.puppet.play("punchR" if hand > 0 else "punchL")
	p.note_cast()
	await wait(0.06)
	a = p.aim()
	var from: Vector3 = p.chest() + flat(a.dir) * 0.9
	var s := Shot.new()
	s.element = "air"
	s.dmg = 8.0
	s.push = 15.0
	s.lift = 4.5
	s.radius = 1.15
	s.life = 0.75
	s.pierce = true
	s.align_y = true
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.82
	tm.rings = 24
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = FX.flow(Color(0.8, 1.0, 0.97, 0.55), Color(1, 1, 1, 0.95), {"scroll": Vector2(1.4, 0.3),
		"tiling": Vector2(3.0, 1.0), "cut": 0.35, "soft": 0.2, "energy": 1.3})
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(ring)
	ring.create_tween().tween_property(ring, "scale", Vector3(2.3, 1.0, 2.3), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	s.add_child(FX.particles({"amount": 22, "life": 0.3, "vmin": 0.2, "vmax": 1.5, "size": 0.7, "scurve": [0.8, 0.1],
		"radius": 0.7, "colors": [Color(1, 1, 1, 0.7), Color(0.9, 1.0, 0.98, 0.0)]}))
	s.on_end = _gale_end
	Game.main.add_child(s)
	s.global_position = from
	s.vel = (a.point - from).normalized() * 42.0
	Trail.attach(s, 0.9, 0.16, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0))
	Game.sfx("air_shot", from, -5.0)


func _gale_end(pos: Vector3, _hit: bool) -> void:
	FX.air_puff(pos, 1.2, 12)


func heavy_start() -> void:
	if cd_heavy > 0.0 or not p.spend(costs[1]):
		return
	cd_heavy = 1.8
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	p.face(a.dir, 0.8)
	p.slow(0.5)
	p.puppet.play("raise")
	p.note_cast()
	var to: Vector3 = a.point - p.global_position
	to.y = 0.0
	var center: Vector3 = Game.floor_at(p.global_position + fwd * clampf(to.length(), 4.0, 22.0), 10.0)
	await wait(0.3)
	var c := Cyclone.new()
	c.drift = fwd * 1.8
	Game.main.add_child(c)
	c.global_position = center


func special() -> void:
	if cd_special > 0.0 or not p.spend(costs[2]):
		return
	cd_special = 1.8
	p.puppet.play("burst")
	p.note_cast()
	var feet: Vector3 = p.global_position
	var c := feet + Vector3(0, 0.9, 0)
	Game.sfx("air_burst")
	Game.shake(0.5)
	FX.ring(feet, Color(0.9, 1.0, 0.97, 0.95), 1.0, 10.5, 0.45, 0.25)
	FX.ring(feet + Vector3(0, 0.5, 0), Color(0.7, 1.0, 0.95, 0.6), 0.5, 7.0, 0.6, 0.4)
	FX.air_puff(c, 2.4, 30)
	FX.burst(c, {"amount": 90, "life": 0.5, "dir": Vector3(1, 0, 0), "spread": 180.0, "flat": 1.0, "vmin": 22.0, "vmax": 28.0,
		"damping": 30.0, "size": 1.6, "scurve": [0.4, 1.2], "colors": [Color(1, 1, 1, 0.8), Color(0.9, 1.0, 0.98, 0.0)], "aabb": 14.0})
	Game.hit_sphere(c, 9.4, 22.0, 17.0, 8.0, "air")
	p.velocity.y = 17.5
	p.air_jumps = 1
	p.coyote = 0.0


func quick() -> void:
	# Vacuum: drag every enemy toward one point so the next move hits them all.
	if cd_q > 0.0 or not p.spend(costs[3]):
		return
	cd_q = 4.0
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var to: Vector3 = a.point - p.global_position
	to.y = 0.0
	var center: Vector3 = Game.floor_at(p.global_position + fwd * clampf(to.length(), 5.0, 18.0), 8.0) + Vector3(0, 1.2, 0)
	p.face(a.dir, 0.8)
	p.slow(0.5)
	p.puppet.play("raise")
	p.note_cast()
	Game.sfx("air_burst", null, 0.0, 1.4)
	FX.ring(center - Vector3(0, 1.1, 0), Color(0.85, 1.0, 0.97, 0.9), 11.0, 0.6, 0.6, 0.2)
	FX.ring(center - Vector3(0, 1.1, 0), Color(0.85, 1.0, 0.97, 0.7), 11.0, 0.6, 0.9, 0.3)
	FX.burst(center, {"amount": 110, "life": 0.7, "ring": 9.0, "ring_h": 3.0, "vmin": 0.0, "vmax": 0.5, "radial": -42.0, "size": 0.9,
		"scurve": [1.0, 0.2], "explosive": 0.3, "colors": [Color(1, 1, 1, 0.0), Color(0.9, 1.0, 0.98, 0.8), Color(1, 1, 1, 0.0)], "aabb": 14.0})
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	orb.mesh = sm
	orb.material_override = FX.flow(Color(0.8, 1.0, 0.97, 0.35), Color(1, 1, 1, 0.9), {"scroll": Vector2(2.0, 0.6), "tiling": Vector2(3.0, 2.0),
		"cut": 0.45, "soft": 0.08, "fresnel": 0.7, "energy": 1.2})
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.main.add_child(orb)
	orb.global_position = center
	orb.scale = Vector3.ONE * 0.2
	orb.create_tween().tween_property(orb, "scale", Vector3.ONE * 1.5, 0.9)
	var t := 0.0
	while t < 0.95:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		orb.rotation.y += dt * 9.0
		for foe in Game.targets:
			if not is_instance_valid(foe) or foe.dead or not foe.has_method("push"):
				continue
			var rel: Vector3 = center - foe.aim_point()
			rel.y = 0.0
			var d := rel.length()
			if d > 13.0:
				continue
			if d > 1.3:
				foe.push(rel.normalized() * 70.0 * dt * foe.mass)
			else:
				foe.kb = Vector3.ZERO
			foe.stun_t = maxf(foe.stun_t, 0.3)
	FX.air_puff(center, 2.0, 22)
	Game.sfx("air_shot", center, 0.0, 0.8)
	Game.hit_sphere(center, 3.6, 12.0, 2.0, 5.0, "air")
	orb.queue_free()


func ultimate() -> void:
	# Skyfall: throw every nearby enemy into the sky, then slam them back down.
	if cd_ult > 0.0 or not p.spend(costs[4]):
		return
	cd_ult = 12.0
	p.puppet.play("burst")
	p.slow(0.6)
	p.note_cast()
	var feet: Vector3 = p.global_position
	Game.sfx("air_burst", null, 3.0, 0.8)
	Game.shake(0.7)
	FX.ring(feet, Color(0.9, 1.0, 0.97, 1.0), 1.0, 13.0, 0.5, 0.25)
	FX.air_puff(feet + Vector3(0, 1, 0), 3.0, 36)
	FX.burst(feet + Vector3(0, 0.5, 0), {"amount": 120, "life": 0.9, "ring": 6.0, "ring_h": 0.5, "dir": Vector3.UP, "spread": 8.0,
		"vmin": 14.0, "vmax": 24.0, "size": 1.2, "scurve": [0.6, 1.2], "explosive": 0.7, "aabb": 30.0,
		"colors": [Color(1, 1, 1, 0.8), Color(0.9, 1.0, 0.98, 0.0)]})
	var victims: Array = []
	var trails: Array = []
	for foe in nearest_targets(feet + Vector3(0, 1, 0), 12.5):
		if foe.has_method("push"):
			foe.take_hit(10.0, Vector3.ZERO, "air")
			if foe.dead:
				continue
			foe.velocity.y = 21.0 / sqrt(foe.mass)
			foe.stun_t = maxf(foe.stun_t, 2.2)
			foe.knock_down()
			trails.append(Trail.attach(foe, 1.2, 0.4, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)))
			victims.append(foe)
		else:
			foe.take_hit(45.0, Vector3.ZERO, "air")
	await wait(0.85)
	p.puppet.play("stomp")
	Game.sfx("whoosh", null, 2.0, 0.6)
	for foe in victims:
		if is_instance_valid(foe) and not foe.dead:
			foe.velocity.y = -46.0
	await wait(0.3)
	Game.shake(0.9)
	Game.hitstop(0.06)
	Game.sfx("boom", null, 2.0, 0.9)
	for tr in trails:
		if is_instance_valid(tr):
			tr.emitting = false
	for foe in victims:
		if not is_instance_valid(foe) or foe.dead:
			continue
		var pos: Vector3 = foe.global_position
		FX.ring(pos, Color(0.9, 1.0, 0.97, 0.9), 0.5, 5.0, 0.4, 0.3)
		FX.dust(pos, 1.8, 16)
		FX.debris(pos, 3, 7.0, 0.22)
		foe.take_hit(58.0, Vector3.UP * 3.0, "air")
