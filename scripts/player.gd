class_name Player
extends CharacterBody3D
# The four Wardens share one body: switching element swaps the character and move set.

signal element_changed(i: int)
signal cast(element: String)
signal died
signal chi_denied

const ELEMENTS := ["earth", "fire", "water", "air"]
const WARDENS := {"earth": "KAEL", "fire": "RHEN", "water": "ILYA", "air": "SORA"}
const SPEEDS := {"earth": 7.0, "fire": 7.8, "water": 7.6, "air": 8.6}

var el := 0
var puppets: Array = []
var puppet: Puppet
var benders: Array = []
var bender: Bender
var model: Node3D
var hp := 100.0
var max_hp := 100.0
var chi := 100.0
var max_chi := 100.0
var dead := false
var yaw := 0.0
var face_t := 0.0
var face_yaw := 0.0
var slow_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 22.0
var iframes := 0.0
var air_jumps := 0
var gliding := false
var coyote := 0.0
var kb := Vector3.ZERO
var last_safe := Vector3.ZERO
var checkpoint := Vector3.ZERO
var hurt_flash := 0.0
var _safe_t := 0.0
var _was_floor := true
var _fall_v := 0.0
var _heavy_down := false
var auto_move := Vector2.ZERO      # used by cinematics / autopilot


func _ready() -> void:
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(52.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	model = Node3D.new()
	add_child(model)
	for e in ELEMENTS:
		var pu := Puppet.new()
		model.add_child(pu)
		pu.setup("warden_" + e)
		pu.set_active(false)
		puppets.append(pu)
	benders = [EarthBender.new(), FireBender.new(), WaterBender.new(), AirBender.new()]
	for b in benders:
		b.p = self
		add_child(b)
	set_element(0, true)


func element() -> String:
	return ELEMENTS[el]


func set_element(i: int, silent := false) -> void:
	if i == el and not silent:
		return
	if bender:
		bender.deactivate()
		_heavy_down = false
	if puppet:
		puppet.set_active(false)
	el = i
	puppet = puppets[i]
	puppet.set_active(true)
	bender = benders[i]
	if not silent:
		var col: Color = Game.EL_COLORS[element()]
		FX.wisps(chest(), col, 1.0, 22)
		FX.ring(global_position, Color(col.r, col.g, col.b, 0.9), 0.4, 3.2, 0.35, 0.3)
		FX.flash(chest(), col, 4.0, 7.0, 0.3)
		puppet.flash(0.9)
		Game.sfx("switch", null, -5.0, 0.8 + i * 0.12, 0.0)
	element_changed.emit(i)


# ------------------------------------------------------------------ helpers used by benders
func chest() -> Vector3:
	return global_position + Vector3(0, 1.25, 0)


func aim_point() -> Vector3:
	return chest()


func face(dirn: Vector3, t := 0.4) -> void:
	face_yaw = atan2(dirn.x, dirn.z)
	face_t = t


func slow(t: float) -> void:
	slow_t = maxf(slow_t, t)


func note_cast() -> void:
	cast.emit(element())


func spend(cost: float) -> bool:
	if chi < cost:
		chi_denied.emit()
		Game.sfx("deny", null, -8.0)
		return false
	chi -= cost
	return true


func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)


func aim() -> Dictionary:
	var cam: Camera3D = Game.cam.cam
	var o := cam.global_position
	var f := -cam.global_basis.z
	var best = null
	var best_s := 1e9
	for t in Game.targets:
		if not is_instance_valid(t) or t.dead:
			continue
		var tp: Vector3 = t.aim_point()
		var to := tp - o
		var d := to.length()
		if d > 60.0 or d < 0.5:
			continue
		var ang := f.angle_to(to)
		if ang > 0.16 + 1.6 / d:
			continue
		var s := ang * 3.0 + d * 0.012
		if s < best_s:
			best_s = s
			best = t
	var origin := chest()
	var point: Vector3
	if best != null:
		point = best.aim_point()
	else:
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(o + f * 2.0, o + f * 80.0, Game.L_WORLD)
		var hit := space.intersect_ray(q)
		point = hit.position if not hit.is_empty() else o + f * 60.0
		if (point - origin).dot(f) < 2.0:
			point = origin + f * 20.0
	return {"origin": origin, "point": point, "dir": (point - origin).normalized(), "target": best}


# ------------------------------------------------------------------ damage
func take_hit(dmg: float, impulse: Vector3, _element := "dark") -> void:
	if dead or iframes > 0.0 or Game.autopilot:
		return
	hp -= dmg
	iframes = 0.55
	kb = Vector3(impulse.x, 0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)
	hurt_flash = 1.0
	puppet.play("hit")
	puppet.flash(0.9)
	bender.deactivate()
	_heavy_down = false
	Game.shake(0.45)
	Game.sfx("hurt")
	FX.sparks(chest(), Color(0.8, 0.4, 1.0), 10, 6.0)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	hp = 0.0
	died.emit()
	Game.sfx("die")
	create_tween().tween_property(puppet, "down", 1.0, 0.5)
	await get_tree().create_timer(2.8, false).timeout
	global_position = checkpoint
	velocity = Vector3.ZERO
	kb = Vector3.ZERO
	hp = max_hp
	chi = max_chi
	puppet.down = 0.0
	dead = false
	iframes = 2.5
	Game.cam.snap()
	FX.wisps(chest(), Game.EL_COLORS[element()], 1.4, 30)


# ------------------------------------------------------------------ main loop
func _physics_process(dt: float) -> void:
	bender.tick(dt)
	for b in benders:
		if b != bender:
			b.tick(dt)
	face_t = maxf(0.0, face_t - dt)
	slow_t = maxf(0.0, slow_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	iframes = maxf(0.0, iframes - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt * 2.2)
	kb = kb.move_toward(Vector3.ZERO, 30.0 * dt)
	var control := Game.input_enabled and not dead
	var iv := Vector2.ZERO
	if control:
		iv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if auto_move != Vector2.ZERO:
		iv = auto_move
	var wish := Vector3.ZERO
	if iv.length() > 0.1:
		wish = (Game.cam.flat_basis() * Vector3(iv.x, 0, iv.y)).normalized()
	var on_floor := is_on_floor()
	coyote = 0.12 if on_floor else maxf(0.0, coyote - dt)
	var name_el := element()
	var speed: float = SPEEDS[name_el] * (0.42 if slow_t > 0.0 else 1.0)

	# horizontal
	var hv := Vector3(velocity.x, 0, velocity.z) - kb
	if dash_t > 0.0:
		dash_t -= dt
		hv = dash_dir * dash_speed
	else:
		hv = hv.move_toward(wish * speed, (75.0 if on_floor else 30.0) * dt)
	# vertical
	gliding = false
	if not on_floor:
		velocity.y -= 28.0 * dt
		if name_el == "air" and control and Input.is_action_pressed("jump") and velocity.y < -1.0:
			gliding = true
			velocity.y = maxf(velocity.y, -2.4)
	if control:
		if Input.is_action_just_pressed("jump"):
			if coyote > 0.0:
				velocity.y = 11.2
				coyote = 0.0
				FX.dust(global_position, 0.6, 6)
				Game.sfx("jump", null, -8.0)
			elif name_el == "air" and air_jumps > 0:
				air_jumps -= 1
				velocity.y = 11.5
				FX.air_puff(global_position, 1.0, 12)
				FX.ring(global_position, Color(0.9, 1.0, 0.97, 0.8), 0.3, 2.4, 0.3, 0.3)
				Game.sfx("air_shot", null, -8.0, 1.3)
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
			dash_t = 0.2
			dash_speed = 25.0 if name_el == "air" else 22.0
			dash_cd = 0.75
			iframes = maxf(iframes, 0.3)
			dash_dir = wish if wish != Vector3.ZERO else Vector3(sin(yaw), 0, cos(yaw))
			Game.cam.fov_kick = 9.0
			Game.sfx("dash", null, -6.0)
			puppet.play("roll")
			_dash_fx()
	velocity.x = hv.x + kb.x
	velocity.z = hv.z + kb.z
	if not on_floor:
		_fall_v = velocity.y
	move_and_slide()
	on_floor = is_on_floor()
	if on_floor:
		air_jumps = 1 if name_el == "air" else 0
		if not _was_floor and _fall_v < -12.0:
			FX.dust(global_position, 1.0, 10)
			Game.shake(0.12)
			Game.sfx("land", null, -8.0)
	_was_floor = on_floor

	# safety: deep water throws you back to shore
	_safe_t -= dt
	if on_floor and global_position.y > 0.6 and _safe_t <= 0.0:
		_safe_t = 0.6
		last_safe = global_position
	if global_position.y < -2.3 and not dead:
		FX.splash(Vector3(global_position.x, 0.2, global_position.z), 2.0, 30)
		Game.sfx("splash")
		global_position = last_safe + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
		hp = maxf(1.0, hp - 8.0)
		hurt_flash = 0.7
		Game.cam.snap()

	# facing
	var want_yaw := yaw
	if face_t > 0.0:
		want_yaw = face_yaw
	elif wish != Vector3.ZERO:
		want_yaw = atan2(wish.x, wish.z)
	yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-dt * 18.0))
	model.rotation.y = yaw

	# abilities
	if control:
		for i in 4:
			if Input.is_action_just_pressed("el_%d" % (i + 1)):
				set_element(i)
		if Input.is_action_just_pressed("el_next"):
			set_element((el + 1) % 4)
		if Input.is_action_pressed("light"):
			bender.light()
		if Input.is_action_just_pressed("heavy"):
			_heavy_down = true
			bender.heavy_start()
		if _heavy_down and Input.is_action_pressed("heavy"):
			bender.heavy_hold(dt)
		if _heavy_down and not Input.is_action_pressed("heavy"):
			_heavy_down = false
			bender.heavy_end()
		if Input.is_action_just_pressed("special"):
			bender.special()
		if Input.is_action_just_pressed("quick"):
			bender.quick()
		if Input.is_action_just_pressed("ultimate"):
			bender.ultimate()
	chi = minf(max_chi, chi + 9.0 * dt)

	# animation inputs
	puppet.move = Vector3(velocity.x, 0, velocity.z).length() / 7.6
	puppet.grounded = on_floor or coyote > 0.0
	puppet.gliding = gliding
	puppet.stance = lerpf(puppet.stance, 1.0 if (slow_t > 0.0 or face_t > 0.0) else 0.0, 1.0 - exp(-dt * 12.0))


func _dash_fx() -> void:
	match element():
		"earth":
			FX.dust(global_position, 1.1, 12)
		"fire":
			FX.fire_burst(global_position + Vector3(0, 0.5, 0), 0.7, 14)
		"water":
			FX.splash(global_position + Vector3(0, 0.3, 0), 0.9, 16)
		"air":
			FX.air_puff(chest(), 1.2, 14)
