class_name EarthBender
extends Bender
# Earth: rip boulders from the ground, raise ramparts, split the earth.

var side := 1.0


func _init() -> void:
	moves = ["Stone Shot", "Rampart", "Faultline", "Quake Leap", "Avalanche"]
	costs = [0, 30, 45, 30, 80]


func light() -> void:
	if cd_light > 0.0:
		return
	cd_light = 0.5
	var a: Dictionary = p.aim()
	p.face(a.dir, 0.6)
	p.slow(0.4)
	p.puppet.play("lift")
	p.note_cast()
	side = -side
	var fwd := flat(a.dir)
	var right := fwd.cross(Vector3.UP)
	var base: Vector3 = Game.floor_at(p.global_position + fwd * 1.6 + right * side * 0.8, 2.0)
	var s := Shot.new()
	s.active = false
	s.element = "earth"
	s.dmg = 24.0
	s.push = 10.0
	s.lift = 3.5
	s.radius = 0.6
	s.life = 2.2
	var rock := FX.prop("rock_%d" % (randi() % 4))
	rock.scale = Vector3.ONE * 1.2
	s.add_child(rock)
	s.spin = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	s.on_end = _rock_end
	Game.main.add_child(s)
	s.global_position = base + Vector3(0, -0.7, 0)
	FX.dust(base, 0.9, 10)
	FX.debris(base, 2, 4.0, 0.16)
	FX.crack(base, 2.6)
	Game.sfx("rumble", base, -5.0)
	Game.shake(0.12)
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", base + Vector3(0, 1.55, 0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await wait(0.24)
	if not is_instance_valid(s):
		return
	p.puppet.play("push")
	await wait(0.07)
	if not is_instance_valid(s):
		return
	a = p.aim()
	s.vel = (a.point - s.global_position).normalized() * 40.0
	s.spin *= 3.0
	s.active = true
	Trail.attach(s, 0.8, 0.2, Color(0.82, 0.76, 0.66, 0.55), Color(0.82, 0.76, 0.66, 0.0))
	Game.sfx("whoosh", s.global_position, -6.0, 0.8)


func _rock_end(pos: Vector3, _hit: bool) -> void:
	var ground: Vector3 = Game.floor_at(pos, 1.0)
	if pos.y - ground.y < 1.6:
		FX.crack(ground, 3.4)
	FX.debris(pos, 5, 6.5, 0.34)
	FX.dust(pos, 1.3, 14)
	Game.sfx("rock_hit", pos, -2.0)
	Game.shake(0.3, pos)


func heavy_start() -> void:
	if cd_heavy > 0.0 or not p.spend(costs[1]):
		return
	cd_heavy = 1.1
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var right := fwd.cross(Vector3.UP).normalized()
	p.face(a.dir, 0.7)
	p.slow(0.6)
	p.puppet.play("stomp")
	p.note_cast()
	var to: Vector3 = a.point - p.global_position
	to.y = 0.0
	var center: Vector3 = p.global_position + fwd * clampf(to.length(), 4.0, 15.0)
	await wait(0.16)
	Game.shake(0.5)
	Game.sfx("boom", center, -1.0)
	Game.sfx("rumble", center, -2.0, 0.8)
	var spots: Array = []
	for i in [-1, 0, 1]:
		spots.append(Game.floor_at(center + right * i * 1.6 - fwd * absf(i) * 0.4, 8.0))
	for i in 3:
		_pillar(spots[i], 1.18 if i == 1 else 1.0)


func _pillar(pos: Vector3, s: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	var mesh := FX.prop("pillar")
	mesh.scale = Vector3.ONE * s
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.85 * s
	sh.height = 3.2 * s
	cs.shape = sh
	cs.position = Vector3(0, 1.6 * s, 0)
	body.add_child(cs)
	Game.main.add_child(body)
	body.global_position = pos + Vector3(0, -3.5 * s, 0)
	body.rotation.y = randf() * TAU
	FX.dust(pos, 1.7, 18)
	FX.debris(pos, 3, 6.0, 0.24)
	FX.crack(pos, 5.0)
	FX.rubble(pos, 1.25 * s, 4)
	Game.hit_sphere(pos + Vector3(0, 1.0, 0), 2.3, 28.0, 4.0, 13.0, "earth")
	var tw := body.create_tween()
	tw.tween_property(body, "global_position", pos + Vector3(0, -0.2, 0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(7.0)
	tw.tween_property(body, "global_position", pos + Vector3(0, -3.6 * s, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(body.queue_free)


func special() -> void:
	if cd_special > 0.0 or not p.spend(costs[2]):
		return
	cd_special = 1.8
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var right := fwd.cross(Vector3.UP).normalized()
	p.face(a.dir, 0.9)
	p.slow(0.8)
	p.puppet.play("stomp")
	p.note_cast()
	var origin: Vector3 = p.global_position
	await wait(0.18)
	Game.shake(0.65)
	Game.sfx("boom", null, 0.0, 0.8)
	FX.ring(origin, Color(1.0, 0.8, 0.5, 0.9), 0.5, 5.0, 0.4)
	FX.dust(origin, 1.5, 16)
	FX.crack(origin, 4.5)
	# one long fissure tearing along the line of spikes
	FX.crack(Game.floor_at(origin + fwd * 12.0, 8.0), 6.5, "line", atan2(fwd.x, fwd.z), 9.0, 24.0)
	for i in 8:
		var pos: Vector3 = Game.floor_at(origin + fwd * (3.0 + i * 2.5) + right * randf_range(-0.5, 0.5), 8.0)
		_spike(pos, fwd, 1.0 + i * 0.09)
		await wait(0.055)


func _spike(pos: Vector3, fwd: Vector3, s: float, dmg := 34.0) -> void:
	var n := FX.prop("spike")
	Game.main.add_child(n)
	var axis := Vector3.UP.cross(fwd).normalized()
	n.global_basis = Basis(axis, 0.32) * Basis(Vector3.UP, randf() * TAU)
	n.scale = Vector3.ONE * s * randf_range(0.9, 1.25)
	n.global_position = pos + Vector3(0, -2.9 * s, 0)
	FX.dust(pos, 1.2, 10)
	FX.debris(pos, 2, 6.0, 0.22)
	Game.sfx("rock_hit", pos, -8.0, 1.2)
	Game.shake(0.14, pos)
	if dmg > 0.0:
		FX.rubble(pos, 0.95 * s, 3, 2.2)
		Game.hit_sphere(pos + Vector3(0, 1.0, 0), 2.2, dmg, 5.0, 11.0, "earth")
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", pos + Vector3(0, -0.25, 0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(n, "global_position", pos + Vector3(0, -3.2 * s, 0), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


func quick() -> void:
	# Quake Leap: jump to the aimed spot and crack the ground open on landing.
	if cd_q > 0.0 or not p.spend(costs[3]):
		return
	cd_q = 3.0
	var a: Dictionary = p.aim()
	var fwd := flat(a.dir)
	var to: Vector3 = a.point - p.global_position
	to.y = 0.0
	var dist := clampf(to.length(), 6.0, 17.0)
	p.face(a.dir, 1.0)
	p.puppet.play("leap")
	p.note_cast()
	FX.dust(p.global_position, 1.3, 14)
	FX.debris(p.global_position, 3, 5.0, 0.2)
	Game.sfx("rumble", null, -3.0)
	Game.sfx("jump", null, -4.0, 0.7)
	var vy := 13.0
	var air := 2.0 * vy / 28.0
	p.velocity.y = vy
	p.coyote = 0.0
	p.dash_dir = fwd
	p.dash_speed = dist / air
	p.dash_t = air
	p.iframes = maxf(p.iframes, air + 0.2)
	Game.cam.fov_kick = 8.0
	await wait(0.2)
	var t := 0.0
	while not p.is_on_floor() and t < 1.6:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	p.dash_t = 0.0
	var pos: Vector3 = p.global_position
	p.puppet.play("slam_down")
	p.slow(0.45)
	Game.shake(0.85)
	Game.hitstop(0.06)
	Game.sfx("boom", null, 1.0, 0.85)
	Game.sfx("rock_hit", null, -2.0, 0.7)
	FX.ring(pos, Color(1.0, 0.8, 0.5, 0.9), 0.5, 7.0, 0.45)
	FX.dust(pos, 2.4, 26)
	FX.debris(pos, 9, 9.0, 0.3)
	FX.crack(pos, 13.0)
	FX.rubble(pos, 2.6, 8)
	Game.hit_sphere(pos + Vector3(0, 1.0, 0), 5.6, 40.0, 9.0, 9.0, "earth")
	for i in 9:
		var ang := i * TAU / 9.0
		var out := Vector3(cos(ang), 0, sin(ang))
		_spike(Game.floor_at(pos + out * 3.3, 6.0), out, 0.62, 0.0)


func ultimate() -> void:
	# Avalanche: tear eight boulders from the ground and hurl them at everything nearby.
	if cd_ult > 0.0 or not p.spend(costs[4]):
		return
	cd_ult = 12.0
	p.slow(1.3)
	p.puppet.play("summon")
	p.note_cast()
	var a: Dictionary = p.aim()
	p.face(a.dir, 1.4)
	Game.shake(0.7)
	Game.sfx("boom", null, 0.0, 0.7)
	Game.sfx("rumble", null, 0.0, 0.7)
	FX.ring(p.global_position, Color(1.0, 0.8, 0.5, 0.9), 0.5, 6.0, 0.6)
	FX.crack(p.global_position, 9.0)
	var rocks: Array = []
	for i in 8:
		var ang := i * TAU / 8.0 + 0.3
		var base: Vector3 = Game.floor_at(p.global_position + Vector3(cos(ang), 0, sin(ang)) * 3.0, 3.0)
		var s := Shot.new()
		s.active = false
		s.element = "earth"
		s.dmg = 30.0
		s.push = 11.0
		s.lift = 5.0
		s.radius = 0.8
		s.life = 3.0
		var rock := FX.prop("rock_%d" % (i % 4))
		rock.scale = Vector3.ONE * randf_range(1.4, 1.9)
		s.add_child(rock)
		s.spin = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		s.on_end = _rock_end
		Game.main.add_child(s)
		s.global_position = base + Vector3(0, -1.0, 0)
		FX.dust(base, 1.1, 10)
		FX.debris(base, 2, 5.0, 0.18)
		FX.crack(base, 3.2)
		var tw := s.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(s, "global_position", base + Vector3(0, randf_range(2.4, 3.6), 0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rocks.append(s)
	await wait(0.75)
	p.puppet.play("push")
	var foes := nearest_targets(p.global_position, 45.0)
	for i in rocks.size():
		var s2 = rocks[i]
		if not is_instance_valid(s2):
			continue
		var point: Vector3
		if foes.is_empty():
			a = p.aim()
			point = a.point
		else:
			var f = foes[i % foes.size()]
			if is_instance_valid(f) and not f.dead:
				point = f.aim_point()
				s2.homing = f
				s2.homing_rate = 5.0
			else:
				point = p.aim().point
		s2.vel = (point - s2.global_position).normalized() * 44.0
		s2.spin *= 3.0
		s2.active = true
		Trail.attach(s2, 1.1, 0.22, Color(0.82, 0.76, 0.66, 0.6), Color(0.82, 0.76, 0.66, 0.0))
		Game.sfx("whoosh", s2.global_position, -4.0, 0.7)
		Game.shake(0.12)
		await wait(0.09)
