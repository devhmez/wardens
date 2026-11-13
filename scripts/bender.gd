class_name Bender
extends Node
# Base class for one element's move set.

var p                       # the Player
var moves := ["", "", "", "", ""]      # light, heavy, special, quick, ultimate
var costs := [0, 0, 0, 0, 0]
var cd_light := 0.0
var cd_heavy := 0.0
var cd_special := 0.0
var cd_q := 0.0
var cd_ult := 0.0


func tick(dt: float) -> void:
	cd_light = maxf(0.0, cd_light - dt)
	cd_heavy = maxf(0.0, cd_heavy - dt)
	cd_special = maxf(0.0, cd_special - dt)
	cd_q = maxf(0.0, cd_q - dt)
	cd_ult = maxf(0.0, cd_ult - dt)


func light() -> void:
	pass


func heavy_start() -> void:
	pass


func heavy_hold(_dt: float) -> void:
	pass


func heavy_end() -> void:
	pass


func special() -> void:
	pass


func quick() -> void:
	pass


func ultimate() -> void:
	pass


func deactivate() -> void:
	heavy_end()


func wait(t: float) -> Signal:
	return get_tree().create_timer(t, false).timeout


static func flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


func nearest_targets(center: Vector3, radius: float, limit := 99) -> Array:
	var list: Array = []
	for t in Game.targets:
		if is_instance_valid(t) and not t.dead and t.aim_point().distance_to(center) <= radius:
			list.append(t)
	list.sort_custom(func(a, b): return a.aim_point().distance_squared_to(center) < b.aim_point().distance_squared_to(center))
	return list.slice(0, limit)
