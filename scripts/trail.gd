class_name Trail
extends MeshInstance3D
# Camera-facing ribbon that follows a node (whips, slashes, projectile streaks).

var target: Node3D
var width := 0.5
var life := 0.3
var color_a := Color(1, 1, 1, 1)
var color_b := Color(1, 1, 1, 0)
var additive := false
var emitting := true
var _pts: Array = []


static func attach(to: Node3D, w: float, l: float, ca: Color, cb: Color, add := false) -> Trail:
	var t := Trail.new()
	t.target = to
	t.width = w
	t.life = l
	t.color_a = ca
	t.color_b = cb
	t.additive = add
	Game.main.add_child(t)
	return t


func _ready() -> void:
	mesh = ImmediateMesh.new()
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material_override = m


func _process(dt: float) -> void:
	if emitting and is_instance_valid(target) and target.is_inside_tree():
		_pts.push_front([target.global_position, 0.0])
	else:
		emitting = false
	var keep: Array = []
	for p in _pts:
		p[1] += dt
		if p[1] < life:
			keep.append(p)
	_pts = keep
	var im: ImmediateMesh = mesh
	im.clear_surfaces()
	if _pts.size() < 2:
		if not emitting:
			queue_free()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _pts.size()
	for i in n:
		var p: Vector3 = _pts[i][0]
		var t: float = _pts[i][1] / life
		var a: Vector3 = _pts[maxi(i - 1, 0)][0]
		var b: Vector3 = _pts[mini(i + 1, n - 1)][0]
		var dir := b - a
		var side := dir.cross(cp - p)
		side = side.normalized() if side.length() > 0.0001 else Vector3.UP
		var w := width * 0.5 * (1.0 - t * 0.8) * minf(1.0, float(i + 1) / 2.0)
		var c := color_a.lerp(color_b, t)
		im.surface_set_color(c)
		im.surface_add_vertex(p + side * w)
		im.surface_set_color(c)
		im.surface_add_vertex(p - side * w)
	im.surface_end()
