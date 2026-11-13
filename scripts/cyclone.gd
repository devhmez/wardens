class_name Cyclone
extends Node3D
# A whirlwind that drags enemies in, lifts them and finally flings them away.

var drift := Vector3.ZERO
var life := 4.4
var _t := 0.0
var _tick := 0.0
var _funnels: Array = []
var _dust: GPUParticles3D


func _ready() -> void:
	for i in 2:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.1 - i * 1.2
		cm.bottom_radius = 0.7 - i * 0.3
		cm.height = 8.0 - i * 1.5
		cm.cap_top = false
		cm.cap_bottom = false
		cm.radial_segments = 28
		cm.rings = 8
		mi.mesh = cm
		mi.position = Vector3(0, cm.height * 0.5, 0)
		mi.material_override = FX.flow(Color(0.75, 0.98, 0.94, 0.5 + i * 0.2), Color(1, 1, 1, 0.95), {
			"scroll": Vector2(0.9 + i * 0.5, -0.25), "tiling": Vector2(1.5, 3.2), "cut": 0.46 - i * 0.05, "soft": 0.06,
			"fade_top": 1.0, "fade_bottom": 1.0, "energy": 1.15, "v_scale": 2.0, "skew": 1.4})
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_funnels.append(mi)
	_dust = FX.particles({"amount": 60, "life": 1.1, "ring": 2.6, "ring_h": 0.5, "dir": Vector3.UP, "spread": 25.0,
		"vmin": 2.0, "vmax": 6.0, "tangent": 16.0, "radial": -6.0, "size": 1.3, "scurve": [0.5, 1.1, 0.3],
		"colors": [Color(0.85, 0.82, 0.7, 0.0), Color(0.9, 0.9, 0.82, 0.6), Color(1, 1, 1, 0.0)], "local": true, "aabb": 12.0})
	add_child(_dust)
	scale = Vector3(0.2, 0.1, 0.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.sfx("air_burst", null, -4.0, 0.7)
	Game.loop("tornado_loop", true, -7.0)


func _physics_process(dt: float) -> void:
	_t += dt
	var p := global_position + drift * dt
	p.y = lerpf(p.y, maxf(Game.world.height_at(p.x, p.z), 0.0), 0.2)
	global_position = p
	for i in _funnels.size():
		_funnels[i].rotation.y += dt * (5.0 + i * 3.0)
		_funnels[i].position.x = sin(_t * 3.0 + i) * 0.15
	_tick -= dt
	var do_dmg := _tick <= 0.0
	if do_dmg:
		_tick = 0.5
	var ending := _t >= life
	for t in Game.targets.duplicate():
		if not is_instance_valid(t) or t.dead:
			continue
		var rel: Vector3 = t.global_position - p
		var f := Vector3(rel.x, 0, rel.z)
		var d := f.length()
		if d > 8.5:
			continue
		if do_dmg and d < 5.0:
			t.take_hit(4.5, Vector3.ZERO, "air")
		if not t.has_method("push"):
			continue
		var out := f.normalized() if d > 0.05 else Vector3.RIGHT
		if ending:
			t.push(out * 13.0 + Vector3.UP * 6.0)
			continue
		var tang := out.cross(Vector3.UP)
		var force := -out * 34.0 * clampf(d / 3.0, 0.0, 1.0) + tang * 20.0
		if d < 3.6 and rel.y < 3.4:
			force.y = 46.0
		t.push(force * dt)
		t.stun_t = maxf(t.stun_t, 0.25)
	if ending:
		FX.air_puff(p + Vector3(0, 2, 0), 2.6, 26)
		Game.loop("tornado_loop", false)
		FX.release(_dust)
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.6, 0.05, 1.6), 0.3)
		tw.tween_callback(queue_free)
