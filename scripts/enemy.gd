class_name Enemy
extends CharacterBody3D
# The Ashen: hollow masked raiders. Kinds: grunt, caster, brute, king (boss).

signal died(e)
signal summon(e)

const STATS := {
	"grunt": {"model": "ashen_grunt", "hp": 44.0, "speed": 5.4, "scale": 1.0, "mass": 1.0, "dmg": 10.0},
	"caster": {"model": "ashen_caster", "hp": 32.0, "speed": 4.4, "scale": 0.96, "mass": 0.9, "dmg": 9.0},
	"brute": {"model": "ashen_brute", "hp": 130.0, "speed": 3.5, "scale": 1.45, "mass": 2.6, "dmg": 24.0},
	"king": {"model": "ashen_king", "hp": 560.0, "speed": 4.7, "scale": 1.9, "mass": 6.0, "dmg": 26.0},
}

var kind := "grunt"
var hp := 40.0
var max_hp := 40.0
var speed := 5.0
var mass := 1.0
var dmg := 10.0
var size := 1.0
var hit_radius := 0.75
var dead := false
var show_bar := true
var puppet: Puppet
var state := "idle"
var state_t := 0.0
var kb := Vector3.ZERO
var stun_t := 0.0
var burn_t := 0.0
var chill_t := 0.0
var frozen_t := 0.0
var yaw := 0.0
var aggro := 30.0
var alerted := false
var strafe := 1.0
var atk_cd := 0.0
var pattern := 0
var charge_dir := Vector3.ZERO
var _burn_tick := 0.0
var _burn_fx: GPUParticles3D
var _summons := 0
var _ring: MeshInstance3D


func setup(k: String) -> void:
	kind = k
	var s: Dictionary = STATS[k]
	hp = s["hp"]
	max_hp = hp
	speed = s["speed"]
	mass = s["mass"]
	dmg = s["dmg"]
	size = s["scale"]
	hit_radius = 0.75 * size
	collision_layer = Game.L_ENEMY
	collision_mask = Game.L_WORLD
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45 * size
	cap.height = 1.8 * size
	cs.shape = cap
	cs.position = Vector3(0, 0.9 * size, 0)
	add_child(cs)
	puppet = Puppet.new()
	add_child(puppet)
	puppet.setup(s["model"], 0.012)
	puppet.scale = Vector3.ONE * size
	puppet.bob_scale = 1.0
	strafe = 1.0 if randf() < 0.5 else -1.0
	atk_cd = randf_range(0.8, 2.2)


func _ready() -> void:
	Game.register(self)
	yaw = randf() * TAU


func aim_point() -> Vector3:
	return global_position + Vector3(0, 1.1 * size, 0)


func push(impulse: Vector3) -> void:
	kb += Vector3(impulse.x, 0, impulse.z) / mass
	velocity.y += impulse.y / mass


func freeze(dur: float) -> void:
	if dead:
		return
	if kind == "king":
		dur *= 0.35
	frozen_t = dur
	stun_t = maxf(stun_t, dur)
	kb = Vector3.ZERO
	state = "chase"
	_clear_ring()
	puppet.set_frost(1.0)
	puppet.set_paused(true)


func knock_down() -> void:
	# thrown onto their back, then climbing up again; helpless for the duration
	if dead or mass >= 2.0:
		return
	puppet.play("knockdown")
	stun_t = maxf(stun_t, 1.85)
	state = "chase"
	_clear_ring()


func _thaw() -> void:
	frozen_t = 0.0
	stun_t = minf(stun_t, 0.2)
	puppet.set_frost(0.0)
	puppet.set_paused(false)
	FX.ice_burst(aim_point(), 1.2 * size)
	Game.sfx("ice_hit", global_position, -5.0)


func take_hit(amount: float, impulse: Vector3, element: String) -> void:
	if dead:
		return
	if frozen_t > 0.0 and element != "water" and amount >= 8.0:
		amount *= 1.6
		_thaw()
		FX.number(aim_point() + Vector3(0, 1.4 * size, 0), "SHATTER", Color(0.7, 0.92, 1.0), true)
	hp -= amount
	alerted = true
	kb += Vector3(impulse.x, 0, impulse.z) / mass
	if impulse.y > 0.0:
		velocity.y = maxf(velocity.y, impulse.y / sqrt(mass))
	puppet.flash(1.0)
	if amount >= 8.0:
		if mass < 2.0:
			stun_t = maxf(stun_t, 0.35)
			if state == "windup":
				state = "chase"
				puppet.stop()
				_clear_ring()
			if frozen_t <= 0.0 and (amount >= 30.0 or impulse.y >= 7.5):
				knock_down()
			else:
				puppet.play("hit")
		Game.sfx("hit", global_position, -4.0)
		FX.sparks(aim_point(), Game.EL_COLORS.get(element, Color.WHITE), 8, 7.0)
	if amount >= 20.0:
		Game.hitstop(0.045)
	if amount >= 1.0:
		FX.number(aim_point() + Vector3(0, 0.6 * size, 0), str(int(round(amount))), Game.EL_COLORS.get(element, Color.WHITE), amount >= 25.0)
	match element:
		"fire":
			burn_t = 3.0
		"water":
			chill_t = 3.0
	if kind == "king":
		var frac := hp / max_hp
		if (_summons == 0 and frac < 0.66) or (_summons == 1 and frac < 0.33):
			_summons += 1
			summon.emit(self)
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	Game.unregister(self)
	collision_layer = 0
	_clear_ring()
	if frozen_t > 0.0:
		frozen_t = 0.0
		puppet.set_frost(0.0)
		puppet.set_paused(false)
	if _burn_fx:
		_burn_fx.emitting = false
	puppet.stop()
	puppet.play("hit")
	died.emit(self)
	Game.sfx("enemy_die", global_position, -3.0)
	FX.wisps(aim_point(), Game.EL_COLORS["dark"], size, int(18 * size))
	if Game.player and not Game.player.dead:
		Game.player.heal(3.0)
		Game.player.chi = minf(Game.player.max_chi, Game.player.chi + 8.0)
	var tw := create_tween()
	tw.tween_property(puppet, "down", 1.0, 0.45)
	tw.tween_interval(0.5)
	tw.tween_method(puppet.set_dissolve, 0.0, 1.0, 0.9)
	tw.tween_callback(queue_free)


func _clear_ring() -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _telegraph(radius: float, dur: float) -> void:
	_clear_ring()
	_ring = FX.ring(global_position, Color(1.0, 0.25, 0.3, 0.9), 0.4, radius, dur, 0.12, 0.35)


func _physics_process(dt: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * dt)
		velocity.y -= 28.0 * dt
		move_and_slide()
		return
	var pl = Game.player
	state_t -= dt
	atk_cd -= dt
	stun_t = maxf(0.0, stun_t - dt)
	chill_t = maxf(0.0, chill_t - dt)
	if frozen_t > 0.0:
		frozen_t -= dt
		if frozen_t <= 0.0:
			_thaw()
	_status(dt)
	kb = kb.move_toward(Vector3.ZERO, 16.0 * dt)
	if not is_on_floor():
		velocity.y -= 28.0 * dt
	var move := Vector3.ZERO
	var to: Vector3 = pl.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var dirn := flat.normalized() if dist > 0.01 else Vector3.FORWARD
	var look := dirn
	if stun_t > 0.0 or pl.dead:
		if pl.dead and state != "idle":
			state = "idle"
			puppet.stop()
			_clear_ring()
	else:
		match kind:
			"grunt":
				move = _ai_grunt(dist, dirn, pl)
			"caster":
				move = _ai_caster(dist, dirn, pl)
			"brute":
				move = _ai_brute(dist, dirn, pl)
			"king":
				move = _ai_king(dist, dirn, pl)
	if state == "charge":
		look = charge_dir
	# keep some space between enemies
	if move != Vector3.ZERO:
		for o in Game.targets:
			if o == self or not (o is Enemy) or o.dead:
				continue
			var away: Vector3 = global_position - o.global_position
			away.y = 0.0
			var ad := away.length()
			if ad < 1.6 * size and ad > 0.01:
				move += away.normalized() * (1.6 * size - ad) * 0.9
	var spd := speed * (0.5 if chill_t > 0.0 else 1.0)
	velocity.x = move.x * spd + kb.x
	velocity.z = move.z * spd + kb.z
	move_and_slide()
	if global_position.y < -1.9:
		FX.splash(Vector3(global_position.x, 0.2, global_position.z), 1.5 * size, 24)
		Game.sfx("splash", global_position)
		if kind == "king":
			global_position = Game.world.ground(World.FORT.x, World.FORT.y, 1.0)
			velocity = Vector3.ZERO
		else:
			FX.number(aim_point() + Vector3(0, 2, 0), "SUNK", Color(0.5, 0.8, 1.0), true)
			die()
			return
	if stun_t <= 0.0:
		yaw = lerp_angle(yaw, atan2(look.x, look.z), 1.0 - exp(-dt * 10.0))
	puppet.rotation.y = yaw
	puppet.move = clampf(Vector2(move.x, move.z).length(), 0.0, 1.0) * (spd / 6.0)
	puppet.grounded = is_on_floor()


func _status(dt: float) -> void:
	if burn_t > 0.0:
		burn_t -= dt
		_burn_tick -= dt
		if _burn_fx == null:
			_burn_fx = FX.particles({"amount": 12, "life": 0.6, "vmin": 0.6, "vmax": 1.8, "dir": Vector3.UP, "spread": 20.0,
				"size": 1.1 * size, "scurve": [0.7, 1.0, 0.8], "flame": true, "upright": true, "radius": 0.35 * size,
				"gravity": Vector3(0, 3, 0), "colors": FX.FADE})
			add_child(_burn_fx)
			_burn_fx.position = Vector3(0, 1.0 * size, 0)
		_burn_fx.emitting = true
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			hp -= 2.0
			FX.number(aim_point() + Vector3(0, 0.6, 0), "2", Game.EL_COLORS["fire"])
			if hp <= 0.0:
				die()
	elif _burn_fx:
		_burn_fx.emitting = false


func _wake(dist: float) -> bool:
	if state == "idle":
		if dist < aggro or alerted:
			state = "chase"
			alerted = true
			# wake nearby friends
			for o in Game.targets:
				if o is Enemy and o.global_position.distance_to(global_position) < 22.0:
					o.alerted = true
		return state != "idle"
	return true


func _ai_grunt(dist: float, dirn: Vector3, pl) -> Vector3:
	if not _wake(dist):
		return Vector3.ZERO
	match state:
		"chase":
			if dist < 2.3 * size and atk_cd <= 0.0:
				state = "windup"
				state_t = 0.48
				puppet.play("windup")
				_telegraph(2.6, 0.48)
				return Vector3.ZERO
			if dist < 1.8:
				return Vector3.ZERO
			return dirn
		"windup":
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.75
				atk_cd = 1.0
				puppet.play("strike")
				kb += dirn * 7.0
				Game.sfx("whoosh", global_position, -8.0, 1.3)
				if dist < 3.1 and absf(pl.global_position.y - global_position.y) < 2.2:
					pl.take_hit(dmg, dirn * 9.0 + Vector3.UP * 3.0)
		"recover":
			if state_t <= 0.0:
				state = "chase"
	return Vector3.ZERO


func _bolt(from: Vector3, dirn: Vector3, spd := 17.0) -> void:
	var s := Shot.new()
	s.from_enemy = true
	s.element = "dark"
	s.dmg = dmg if kind == "caster" else 11.0
	s.push = 7.0
	s.lift = 2.0
	s.radius = 0.4
	s.life = 3.0
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	core.mesh = sm
	core.material_override = FX.glow_mat(Color(0.85, 0.45, 1.0), 3.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(core)
	s.add_child(FX.particles({"amount": 18, "life": 0.35, "vmin": 0.1, "vmax": 0.8, "size": 0.8, "scurve": [1.0, 0.0], "add": true,
		"colors": [Color(2.2, 0.9, 3.0, 1.0), Color(0.6, 0.1, 1.2, 0.0)]}))
	s.on_end = _bolt_end
	Game.main.add_child(s)
	s.global_position = from
	s.vel = dirn * spd
	Game.sfx("dark_shot", from, -6.0)


func _bolt_end(pos: Vector3, _hit: bool) -> void:
	FX.wisps(pos, Game.EL_COLORS["dark"], 0.6, 10)


func _ai_caster(dist: float, dirn: Vector3, pl) -> Vector3:
	if not _wake(dist):
		return Vector3.ZERO
	match state:
		"chase":
			if atk_cd <= 0.0 and dist < 26.0:
				state = "windup"
				state_t = 0.6
				puppet.play("cast")
				FX.wisps(aim_point() + Vector3(0, 0.6, 0), Game.EL_COLORS["dark"], 0.5, 10)
				return Vector3.ZERO
			var side := dirn.cross(Vector3.UP) * strafe
			if dist < 9.0:
				return (-dirn + side * 0.4).normalized()
			if dist > 17.0:
				return dirn
			if randf() < 0.01:
				strafe = -strafe
			return side * 0.6
		"windup":
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.45
				atk_cd = randf_range(2.0, 3.0)
				puppet.play("shoot")
				var from := aim_point() + dirn * 0.8 + Vector3(0, 0.3, 0)
				var lead: Vector3 = pl.chest() + pl.velocity * (dist / 17.0) * 0.5
				_bolt(from, (lead - from).normalized())
		"recover":
			if state_t <= 0.0:
				state = "chase"
	return Vector3.ZERO


func _slam(radius: float, pl) -> void:
	puppet.play("slam_down")
	Game.shake(0.6, global_position)
	Game.sfx("boom", global_position)
	FX.ring(global_position, Color(1.0, 0.4, 0.3, 1.0), 1.0, radius, 0.35, 0.3, 0.2)
	FX.dust(global_position, 2.2 * size * 0.7, 22)
	FX.debris(global_position, 5, 7.0, 0.28)
	FX.crack(global_position, radius * 1.7)
	FX.rubble(global_position, radius * 0.35, 5, 4.0)
	var d: float = pl.global_position.distance_to(global_position)
	if d < radius and pl.is_on_floor():
		var out: Vector3 = Bender.flat(pl.global_position - global_position)
		pl.take_hit(dmg, out * 12.0 + Vector3.UP * 7.0)


func _ai_brute(dist: float, dirn: Vector3, pl) -> Vector3:
	if not _wake(dist):
		return Vector3.ZERO
	match state:
		"chase":
			if dist < 3.8 and atk_cd <= 0.0:
				state = "windup"
				state_t = 0.95
				puppet.play("slam_up")
				_telegraph(5.0, 0.95)
				return Vector3.ZERO
			return dirn if dist > 2.6 else Vector3.ZERO
		"windup":
			if state_t <= 0.0:
				state = "recover"
				state_t = 1.3
				atk_cd = 1.6
				_clear_ring()
				_slam(5.0, pl)
		"recover":
			if state_t <= 0.0:
				state = "chase"
	return Vector3.ZERO


func _ai_king(dist: float, dirn: Vector3, pl) -> Vector3:
	if not _wake(dist):
		return Vector3.ZERO
	var enraged := hp < max_hp * 0.5
	match state:
		"chase":
			if atk_cd <= 0.0:
				var choice := pattern % 3
				pattern += 1
				if choice == 0 and dist > 7.0:
					choice = 2
				if choice == 0:
					state = "slam_w"
					state_t = 0.85
					puppet.play("slam_up")
					_telegraph(6.8, 0.85)
				elif choice == 1:
					state = "volley_w"
					state_t = 0.7
					puppet.play("cast")
					FX.wisps(aim_point() + Vector3(0, 1.5, 0), Game.EL_COLORS["dark"], 1.2, 24)
				else:
					state = "charge_w"
					state_t = 0.6
					puppet.play("brace")
					FX.ring(global_position, Color(1.0, 0.2, 0.4, 1.0), 3.0, 0.6, 0.6, 0.3)
				return Vector3.ZERO
			return dirn if dist > 3.2 else Vector3.ZERO
		"slam_w":
			if state_t <= 0.0:
				_clear_ring()
				_slam(6.8, pl)
				state = "recover"
				state_t = 1.1
				atk_cd = 1.5 if not enraged else 0.9
		"volley_w":
			if state_t <= 0.0:
				puppet.play("shoot")
				var from := aim_point() + dirn * 1.5 + Vector3(0, 0.6, 0)
				var base: Vector3 = (pl.chest() - from).normalized()
				var n := 7 if enraged else 5
				for i in n:
					var ang := lerpf(-0.5, 0.5, float(i) / (n - 1))
					_bolt(from, base.rotated(Vector3.UP, ang), 19.0)
				state = "recover"
				state_t = 0.8
				atk_cd = 1.4 if not enraged else 0.8
		"charge_w":
			if state_t <= 0.0:
				state = "charge"
				state_t = 0.85
				charge_dir = dirn
				puppet.play("charge")
				Game.sfx("whoosh", global_position, 0.0, 0.6)
		"charge":
			FX.dust(global_position, 0.8, 3)
			if dist < 2.8 and absf(pl.global_position.y - global_position.y) < 3.0:
				pl.take_hit(20.0, charge_dir * 15.0 + Vector3.UP * 5.0)
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.9
				atk_cd = 1.2 if not enraged else 0.7
				return Vector3.ZERO
			return charge_dir * 4.2
		"recover":
			if state_t <= 0.0:
				state = "chase"
	return Vector3.ZERO
