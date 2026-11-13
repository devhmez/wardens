class_name Shot
extends Node3D
# Generic bending projectile. Visuals are added as children by whoever fires it.

var vel := Vector3.ZERO
var radius := 0.5
var dmg := 10.0
var push := 5.0
var lift := 2.0
var element := "earth"
var life := 3.0
var gravity := 0.0
var active := true
var from_enemy := false
var pierce := false
var homing: Node = null
var homing_rate := 0.0
var spin := Vector3.ZERO
var align_y := false
var on_end := Callable()
var on_target := Callable()
var _done: Array = []


func _physics_process(dt: float) -> void:
	if spin != Vector3.ZERO:
		rotate_x(spin.x * dt)
		rotate_y(spin.y * dt)
		rotate_z(spin.z * dt)
	if not active:
		return
	life -= dt
	if life <= 0.0:
		finish(false)
		return
	if homing != null and is_instance_valid(homing) and not homing.dead:
		var want: Vector3 = (homing.aim_point() - global_position).normalized() * vel.length()
		vel = vel.lerp(want, clampf(homing_rate * dt, 0.0, 1.0))
	vel.y -= gravity * dt
	var from := global_position
	var to := from + vel * dt
	var dirn := vel.normalized()
	if align_y and vel.length() > 0.1:
		var sc := scale
		global_basis = Basis(Quaternion(Vector3.UP, dirn))
		scale = sc
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to + dirn * radius * 0.4, Game.L_WORLD)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and not pierce:
		global_position = hit.position
		finish(true)
		return
	global_position = to
	if to.y < -0.1 and Game.world.height_at(to.x, to.z) < -0.2:
		FX.splash(Vector3(to.x, 0.1, to.z), 1.0, 14)
		finish(false)
		return
	if from_enemy:
		var pl = Game.player
		if pl != null and not pl.dead and _seg_dist(from, to, pl.chest()) < radius + 0.65:
			pl.take_hit(dmg, dirn * push + Vector3.UP * lift, element)
			finish(true)
		return
	for t in Game.targets.duplicate():
		if not is_instance_valid(t) or t.dead or _done.has(t):
			continue
		var c: Vector3 = t.aim_point()
		var d := _seg_vec(from, to, c)
		d.y *= 0.55
		if d.length() < radius + t.hit_radius:
			t.take_hit(dmg, dirn * push + Vector3.UP * lift, element)
			if on_target.is_valid():
				on_target.call(t)
			if pierce:
				_done.append(t)
			else:
				global_position = c - dirn * t.hit_radius
				finish(true)
				return


func _seg_vec(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var k := 0.0
	if ab.length_squared() > 0.000001:
		k = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p - (a + ab * k)


func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	return _seg_vec(a, b, p).length()


func finish(hit: bool) -> void:
	if on_end.is_valid():
		on_end.call(global_position, hit)
	for c in get_children():
		if c is GPUParticles3D:
			FX.release(c)
	queue_free()
