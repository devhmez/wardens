class_name CameraRig
extends Node3D
# Over-the-shoulder follow camera with collision, shake and a cinematic orbit mode.

var cam: Camera3D
var target: Node3D
var yaw := 0.0
var pitch := -0.22
var dist := 5.0
var trauma := 0.0
var orbit := false
var orbit_center := Vector3.ZERO
var orbit_radius := 16.0
var orbit_height := 5.0
var fov_kick := 0.0
var _pivot := Vector3.ZERO
var _dist := 5.0
var _t := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 64.0
	cam.near = 0.15
	cam.far = 900.0
	add_child(cam)
	cam.make_current()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not orbit:
		yaw -= e.relative.x * 0.0026
		pitch = clampf(pitch - e.relative.y * 0.0026, -1.25, 0.55)


func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func snap() -> void:
	if target:
		_pivot = target.global_position + Vector3(0, 1.7, 0)


func _process(dt: float) -> void:
	_t += dt
	trauma = maxf(0.0, trauma - dt * 1.6)
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-dt * 6.0))
	cam.fov = 64.0 + fov_kick
	var sh := trauma * trauma
	var shake_rot := Vector3(sin(_t * 71.0) * 0.035, sin(_t * 53.0 + 1.3) * 0.035, sin(_t * 61.0 + 2.1) * 0.03) * sh
	if orbit:
		var a := _t * 0.12
		var p := orbit_center + Vector3(cos(a) * orbit_radius, orbit_height, sin(a) * orbit_radius)
		cam.global_position = p
		cam.look_at(orbit_center + Vector3(0, 2.0, 0))
		return
	if target == null:
		return
	var focus := target.global_position + Vector3(0, 1.7, 0)
	_pivot = _pivot.lerp(focus, 1.0 - exp(-dt * 16.0))
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
	var off := b * Vector3(0.7, 0.15, dist)
	var want := off.length()
	var dirn := off / want
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_pivot, _pivot + dirn * (want + 0.4), Game.L_WORLD)
	var hit := space.intersect_ray(q)
	var d := want
	if not hit.is_empty():
		d = maxf(0.8, _pivot.distance_to(hit.position) - 0.4)
	_dist = d if d < _dist else lerpf(_dist, d, 1.0 - exp(-dt * 5.0))
	cam.global_position = _pivot + dirn * _dist
	cam.global_basis = b * Basis.from_euler(shake_rot)
