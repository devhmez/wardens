class_name FX
# Materials, models and visual effects factory.

static var _shaders := {}
static var _noise: NoiseTexture2D
static var _soft: GradientTexture2D
static var _pmats := {}
static var _scenes := {}
static var _toon_cache := {}

const GLOW_MATS := {"eyeglow": 5.0, "lampglow": 3.0, "corrupt": 3.2, "crystal_earth": 2.4, "crystal_fire": 2.8,
	"crystal_water": 2.4, "crystal_air": 2.0, "ice": 0.35}
const _CLOTH := {"roughness": 0.92, "bump": 0.003, "detail_scale": 26.0, "mottling": 0.14}
const _STONE := {"roughness": 0.9, "bump": 0.007, "detail_scale": 2.2, "mottling": 0.4, "tex": "japanese_stone_wall", "tex_scale": 0.33, "tex_gain": 1.9}
const _ROCK := {"roughness": 0.92, "bump": 0.012, "detail_scale": 2.2, "mottling": 0.4, "tex": "rock_face_03", "tex_scale": 0.28, "tex_gain": 2.3}
const _WOOD := {"roughness": 0.86, "bump": 0.007, "detail_scale": 4.0, "mottling": 0.35, "tex": "weathered_brown_planks", "tex_scale": 0.55, "tex_gain": 2.4}
const _LEAF := {"roughness": 0.7, "bump": 0.05, "detail_scale": 3.0, "mottling": 0.45, "backlight": 0.45}
const _GLASS := {"roughness": 0.08, "bump": 0.0, "mottling": 0.0}
const MAT_OPTS := {
	"skin": {"roughness": 0.55, "bump": 0.0015, "detail_scale": 18.0, "mottling": 0.06},
	"cloth1": _CLOTH, "cloth2": _CLOTH, "banner": _CLOTH,
	"trim": {"roughness": 0.7, "bump": 0.002, "detail_scale": 20.0, "mottling": 0.1},
	"hair": {"roughness": 0.42, "bump": 0.004, "detail_scale": 30.0, "mottling": 0.2},
	"boot": {"roughness": 0.6, "bump": 0.003, "detail_scale": 14.0, "mottling": 0.15},
	"eye": _GLASS, "white": _GLASS, "eyeglow": _GLASS, "corrupt": _GLASS,
	"crystal_earth": _GLASS, "crystal_fire": _GLASS, "crystal_water": _GLASS, "crystal_air": _GLASS,
	"mask": {"roughness": 0.3, "bump": 0.002, "detail_scale": 8.0, "mottling": 0.12},
	"stone": _STONE, "stonedark": _STONE, "rock": _ROCK,
	"bark": _WOOD, "wood": _WOOD, "wood2": _WOOD, "log": _WOOD,
	"leafa": _LEAF, "leafb": _LEAF,
	"gold": {"roughness": 0.28, "metallic": 1.0, "bump": 0.002, "mottling": 0.1},
	"iron": {"roughness": 0.45, "metallic": 0.9, "bump": 0.004, "mottling": 0.2},
	"ice": {"roughness": 0.06, "bump": 0.01, "detail_scale": 5.0, "mottling": 0.1},
	"plaster": {"roughness": 0.95, "bump": 0.005, "detail_scale": 5.0, "mottling": 0.15, "tex": "white_rough_plaster", "tex_scale": 0.4, "tex_gain": 1.25},
	"roof": {"roughness": 0.8, "bump": 0.01, "detail_scale": 3.0, "mottling": 0.3, "tex": "roof_09", "tex_scale": 0.45, "tex_gain": 2.2},
	"roofdark": {"roughness": 0.8, "bump": 0.01, "detail_scale": 3.0, "mottling": 0.3, "tex": "roof_09", "tex_scale": 0.45, "tex_gain": 2.2},
	"straw": {"roughness": 0.9, "bump": 0.02, "detail_scale": 10.0, "mottling": 0.3},
}
static var _tex := {}
static var _pink := {}
static var _cell: NoiseTexture2D
static var _normal: NoiseTexture2D


static func shader(sname: String) -> Shader:
	if not _shaders.has(sname):
		_shaders[sname] = load("res://shaders/%s.gdshader" % sname)
	return _shaders[sname]


static func noise_tex() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = n
	return _noise


static func cell_tex() -> NoiseTexture2D:
	if _cell == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.045
		n.fractal_octaves = 2
		_cell = NoiseTexture2D.new()
		_cell.width = 256
		_cell.height = 256
		_cell.seamless = true
		_cell.noise = n
	return _cell


static func normal_tex() -> NoiseTexture2D:
	if _normal == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_octaves = 4
		_normal = NoiseTexture2D.new()
		_normal.width = 512
		_normal.height = 512
		_normal.seamless = true
		_normal.as_normal_map = true
		_normal.bump_strength = 6.0
		_normal.noise = n
	return _normal


static func soft_tex() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.width = 64
		_soft.height = 64
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
	return _soft


# ------------------------------------------------------------------ materials
static func toon(color: Color, opts := {}) -> ShaderMaterial:
	# Physically based surface material (the name is kept from the first, cel-shaded version).
	var m := ShaderMaterial.new()
	m.shader = shader("surface")
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("albedo", color)
	for k in opts:
		if k == "tex":
			m.set_shader_parameter("use_tex", true)
			m.set_shader_parameter("tex_albedo", tex(opts[k] + "_diff"))
		elif k != "outline":
			m.set_shader_parameter(k, opts[k])
	return m


static func tex(tname: String) -> Texture2D:
	if not _tex.has(tname):
		_tex[tname] = load("res://assets/tex/%s.jpg" % tname)
	return _tex[tname]


static func nature(nname: String, pink := false) -> Node3D:
	# A model from the nature kit, with foliage set up to look right from both sides.
	var key := nname + ("|pink" if pink else "")
	if not _scenes.has(key):
		var ps: PackedScene = load("res://assets/nature/%s.gltf" % nname)
		_scenes[key] = ps
		var probe: Node = ps.instantiate()
		for mi in probe.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if not (m is BaseMaterial3D):
					continue
				var leafy: bool = m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and not m.resource_name.begins_with("Bark")
				if leafy:
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					m.alpha_scissor_threshold = 0.4
					m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
					m.backlight_enabled = true
					m.backlight = Color(0.32, 0.42, 0.14)
					m.roughness = 0.75
				else:
					m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					m.roughness = 0.92
		probe.free()
	var n: Node3D = _scenes[key].instantiate()
	if pink:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D and m.backlight_enabled:
					if not _pink.has(m):
						var d: BaseMaterial3D = m.duplicate()
						d.albedo_color = Color(2.7, 0.95, 1.9)
						d.backlight = Color(0.6, 0.25, 0.35)
						_pink[m] = d
					mi.set_surface_override_material(s, _pink[m])
	return n


static func height_of(n: Node3D) -> float:
	var top := 0.01
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = mi.get_aabb()
		top = maxf(top, (mi.transform * bb).end.y)
	return top


static func flow(color_a: Color, color_b: Color, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("flow")
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("color_a", color_a)
	m.set_shader_parameter("color_b", color_b)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


static func glow_mat(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	return m


static func model(mname: String) -> Node3D:
	if not _scenes.has(mname):
		_scenes[mname] = load("res://assets/models/%s.glb" % mname)
	return _scenes[mname].instantiate()


static func toonify(root: Node, outline := 0.0, unique := false) -> Array:
	# Swap every imported material for the cel shader, keeping the Blender colours.
	var mats: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_toonify_mesh(mi, outline, unique, mats)
	if root is MeshInstance3D:
		_toonify_mesh(root, outline, unique, mats)
	return mats


static func _toonify_mesh(mi: MeshInstance3D, outline: float, unique: bool, mats: Array) -> void:
	for s in mi.mesh.get_surface_count():
		var src = mi.mesh.surface_get_material(s)
		var mname := "mat"
		var col := Color(0.8, 0.8, 0.8)
		if src is BaseMaterial3D:
			col = src.albedo_color
			mname = src.resource_name.get_slice(".", 0)
		var key := "%s|%s|%s" % [mname, col.to_html(), outline]
		var m: ShaderMaterial
		if not unique and _toon_cache.has(key):
			m = _toon_cache[key]
		else:
			var opts: Dictionary = MAT_OPTS.get(mname, {}).duplicate()
			if GLOW_MATS.has(mname):
				opts["emission"] = col
				opts["emission_energy"] = GLOW_MATS[mname]
			m = toon(col, opts)
			if not unique:
				_toon_cache[key] = m
		mi.set_surface_override_material(s, m)
		mats.append(m)


static func prop(mname: String, outline := 0.0) -> Node3D:
	var n := model(mname)
	toonify(n, outline)
	return n


# ------------------------------------------------------------------ particles
static func pmat(additive: bool) -> StandardMaterial3D:
	var key := "add" if additive else "mix"
	if not _pmats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = soft_tex()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_receive_shadows = true
		_pmats[key] = m
	return _pmats[key]


static func flame_mat(upright: bool, energy: float) -> ShaderMaterial:
	var key := "flame|%s|%.2f" % [upright, energy]
	if not _pmats.has(key):
		var m := ShaderMaterial.new()
		m.shader = shader("flame")
		m.set_shader_parameter("noise_tex", noise_tex())
		m.set_shader_parameter("upright", upright)
		m.set_shader_parameter("energy", energy)
		_pmats[key] = m
	return _pmats[key]


static func _curve(vals: Array) -> CurveTexture:
	var c := Curve.new()
	var mx := 1.0
	for v in vals:
		mx = maxf(mx, v)
	c.max_value = mx
	for i in vals.size():
		c.add_point(Vector2(float(i) / maxf(1.0, vals.size() - 1.0), vals[i]))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cc := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	return t


static func particles(c: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = c.get("amount", 24)
	p.lifetime = c.get("life", 0.6)
	p.one_shot = c.get("one_shot", false)
	p.explosiveness = c.get("explosive", 0.0)
	p.randomness = 0.4
	p.local_coords = c.get("local", false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = c.get("aabb", 10.0)
	p.visibility_aabb = AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	var m := ParticleProcessMaterial.new()
	m.direction = c.get("dir", Vector3.UP)
	m.spread = c.get("spread", 180.0)
	m.flatness = c.get("flat", 0.0)
	m.initial_velocity_min = c.get("vmin", 1.0)
	m.initial_velocity_max = c.get("vmax", 2.0)
	m.gravity = c.get("gravity", Vector3.ZERO)
	m.damping_min = c.get("damping", 0.0)
	m.damping_max = c.get("damping", 0.0)
	m.scale_min = c.get("smin", 0.6)
	m.scale_max = c.get("smax", 1.0)
	m.scale_curve = _curve(c.get("scurve", [1.0, 0.0]))
	m.color_ramp = _ramp(c.get("colors", [Color.WHITE, Color(1, 1, 1, 0)]))
	m.angle_min = 0.0
	m.angle_max = 360.0
	if c.has("ring"):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_axis = Vector3.UP
		m.emission_ring_radius = c["ring"]
		m.emission_ring_inner_radius = c["ring"] * 0.85
		m.emission_ring_height = c.get("ring_h", 0.2)
	elif c.has("box"):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = c["box"]
	elif c.get("radius", 0.0) > 0.0:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = c["radius"]
	if c.has("radial"):
		m.radial_accel_min = c["radial"]
		m.radial_accel_max = c["radial"]
	if c.has("tangent"):
		m.tangential_accel_min = c["tangent"]
		m.tangential_accel_max = c["tangent"]
	if c.get("turb", 0.0) > 0.0:
		m.turbulence_enabled = true
		m.turbulence_noise_strength = c["turb"]
		m.turbulence_noise_scale = 2.0
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2.ONE * c.get("size", 1.0)
	if c.get("flame", false):
		q.material = flame_mat(c.get("upright", false), c.get("energy", 1.25))
	else:
		q.material = pmat(c.get("add", false))
	p.draw_pass_1 = q
	return p


static func burst(pos: Vector3, c: Dictionary) -> GPUParticles3D:
	c["one_shot"] = true
	if not c.has("explosive"):
		c["explosive"] = 0.92
	var p := particles(c)
	Game.main.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, p.lifetime + 0.8)
	return p


static func _free_later(n: Node, t: float) -> void:
	Game.get_tree().create_timer(t, false).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())


static func release(p: GPUParticles3D) -> void:
	# Let a trail emitter finish after its owner is gone.
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var xf := p.global_transform
	p.get_parent().remove_child(p)
	Game.main.add_child(p)
	p.global_transform = xf
	p.emitting = false
	_free_later(p, p.lifetime + 0.3)


# ------------------------------------------------------------------ presets
static func dust(pos: Vector3, s := 1.0, amount := 14) -> void:
	burst(pos, {"amount": amount, "life": 0.9, "vmin": 1.0 * s, "vmax": 3.5 * s, "spread": 80.0, "damping": 3.0,
		"size": 1.5 * s, "scurve": [0.5, 1.0, 1.3], "gravity": Vector3(0, 0.6, 0), "radius": 0.4 * s,
		"colors": [Color(0.72, 0.64, 0.52, 0.85), Color(0.75, 0.68, 0.58, 0.4), Color(0.8, 0.75, 0.65, 0.0)]})


static func sparks(pos: Vector3, col: Color, amount := 16, speed := 9.0) -> void:
	burst(pos, {"amount": amount, "life": 0.45, "vmin": speed * 0.4, "vmax": speed, "spread": 180.0, "damping": 4.0,
		"size": 0.22, "gravity": Vector3(0, -9, 0), "add": true,
		"colors": [Color(col.r * 3.0, col.g * 3.0, col.b * 3.0, 1.0), Color(col.r, col.g, col.b, 0.0)]})


const FADE := [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)]


static func embers(pos: Vector3, s := 1.0, amount := 14) -> void:
	# glowing sparks that drift up and wink out
	burst(pos, {"amount": amount, "life": 1.3, "vmin": 1.5 * s, "vmax": 6.0 * s, "dir": Vector3.UP, "spread": 70.0, "damping": 1.5,
		"size": 0.09, "smin": 0.5, "smax": 1.5, "scurve": [1.0, 0.6, 0.0], "gravity": Vector3(0, 1.2, 0), "add": true, "turb": 3.0,
		"radius": 0.4 * s, "explosive": 0.8,
		"colors": [Color(4.0, 2.6, 0.8, 1.0), Color(3.0, 1.0, 0.15, 1.0), Color(1.2, 0.15, 0.0, 0.0)]})


static func fire_burst(pos: Vector3, s := 1.0, amount := 26) -> void:
	burst(pos, {"amount": amount, "life": 0.6, "vmin": 1.0 * s, "vmax": 6.5 * s, "spread": 180.0, "damping": 5.0,
		"size": 1.7 * s, "scurve": [0.6, 1.25, 0.9], "gravity": Vector3(0, 5, 0), "flame": true, "radius": 0.3 * s, "colors": FADE})
	burst(pos, {"amount": int(amount * 0.4), "life": 1.2, "vmin": 0.5, "vmax": 2.0 * s, "spread": 180.0, "damping": 2.0,
		"size": 1.8 * s, "scurve": [0.5, 1.2], "gravity": Vector3(0, 2.5, 0), "radius": 0.4 * s,
		"colors": [Color(0.06, 0.05, 0.05, 0.0), Color(0.07, 0.06, 0.06, 0.6), Color(0.12, 0.12, 0.12, 0.0)]})
	embers(pos, s, int(amount * 0.5))


# ------------------------------------------------------------------ broken ground
static var _cracks := {}


static func _crack_maps(kind: String) -> Array:
	# Draws a fissure pattern once and returns [albedo, normal] textures for decals.
	if _cracks.has(kind):
		return _cracks[kind]
	var n := 320
	var h := PackedFloat32Array()
	h.resize(n * n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 if kind == "radial" else 37
	var walkers: Array = []     # [x, y, heading, width, steps_left, home_heading]
	if kind == "radial":
		var k := 8
		for i in k:
			var a := i * TAU / k + rng.randf_range(-0.3, 0.3)
			walkers.append([n * 0.5, n * 0.5, a, rng.randf_range(4.0, 7.0), int(n * 0.3 * rng.randf_range(0.75, 1.0)), a])
		# shattered centre
		for y in range(int(n * 0.38), int(n * 0.62)):
			for x in range(int(n * 0.38), int(n * 0.62)):
				var d := Vector2(x - n * 0.5, y - n * 0.5).length() / (n * 0.1)
				if d < 1.0:
					h[y * n + x] = (1.0 - d * d) * 0.7
	else:
		walkers.append([n * 0.5, n * 0.03, PI * 0.5, 8.0, int(n * 0.62), PI * 0.5])
	while not walkers.is_empty():
		var w: Array = walkers.pop_back()
		var total: int = w[4]
		for step in total:
			var k2 := float(step) / total
			var width: float = lerpf(w[3], 0.9, k2)
			w[2] = lerpf(w[2] + rng.randf_range(-0.42, 0.42), w[5], 0.12)
			w[0] += cos(w[2]) * 1.5
			w[1] += sin(w[2]) * 1.5
			var r := int(ceil(width))
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var px := int(w[0]) + dx
					var py := int(w[1]) + dy
					if px < 2 or py < 2 or px >= n - 2 or py >= n - 2:
						continue
					var dd := Vector2(dx, dy).length() / width
					if dd < 1.0:
						var i2 := py * n + px
						h[i2] = maxf(h[i2], 1.0 - dd * dd)
			if width > 2.0 and rng.randf() < (0.035 if kind == "radial" else 0.07):
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var ba: float = w[2] + side * rng.randf_range(0.5, 1.1)
				walkers.append([w[0], w[1], ba, width * 0.6, int((total - step) * rng.randf_range(0.35, 0.7)), ba])
	var alb := PackedByteArray()
	alb.resize(n * n * 4)
	var nor := PackedByteArray()
	nor.resize(n * n * 4)
	for y in n:
		for x in n:
			var i := y * n + x
			var v := h[i]
			var hx := h[y * n + mini(x + 1, n - 1)] - h[y * n + maxi(x - 1, 0)]
			var hy := h[mini(y + 1, n - 1) * n + x] - h[maxi(y - 1, 0) * n + x]
			var nv := Vector3(hx * 3.0, hy * 3.0, 1.0).normalized()
			alb[i * 4] = 10
			alb[i * 4 + 1] = 8
			alb[i * 4 + 2] = 7
			alb[i * 4 + 3] = int(clampf(smoothstep(0.02, 0.45, v), 0.0, 1.0) * 255.0)
			nor[i * 4] = int((nv.x * 0.5 + 0.5) * 255.0)
			nor[i * 4 + 1] = int((nv.y * 0.5 + 0.5) * 255.0)
			nor[i * 4 + 2] = int((nv.z * 0.5 + 0.5) * 255.0)
			nor[i * 4 + 3] = 255
	var ia := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, alb)
	ia.generate_mipmaps()
	var inn := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, nor)
	inn.generate_mipmaps()
	_cracks[kind] = [ImageTexture.create_from_image(ia), ImageTexture.create_from_image(inn)]
	return _cracks[kind]


static func crack(pos: Vector3, size: float, kind := "radial", yaw := -1000.0, life := 10.0, length := 0.0) -> void:
	# Fissures stamped into the ground (and anything else marked as ground) that fade after a while.
	var maps := _crack_maps(kind)
	var d := Decal.new()
	d.texture_albedo = maps[0]
	d.texture_normal = maps[1]
	d.size = Vector3(size, 3.5, length if length > 0.0 else size)
	d.cull_mask = 2
	d.normal_fade = 0.35
	d.upper_fade = 0.5
	d.lower_fade = 0.5
	d.albedo_mix = 0.0
	Game.main.add_child(d)
	d.global_position = pos
	d.rotation.y = randf() * TAU if yaw < -900.0 else yaw
	var tw := d.create_tween()
	tw.tween_property(d, "albedo_mix", 1.0, 0.07)
	tw.tween_interval(life)
	tw.tween_property(d, "modulate:a", 0.0, 2.0)
	tw.tween_callback(d.queue_free)


static func rubble(pos: Vector3, radius: float, count: int, life := 7.0) -> void:
	# Slabs of ground heaved up around an impact, tilted outward.
	for i in count:
		var ang := i * TAU / count + randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0, sin(ang))
		var spot: Vector3 = Game.floor_at(pos + out * radius * randf_range(0.75, 1.15), 4.0)
		var n := prop("rock_%d" % (randi() % 4))
		Game.main.add_child(n)
		var sc := radius * randf_range(0.3, 0.55)
		n.global_basis = Basis(Vector3.UP.cross(out).normalized(), randf_range(0.35, 0.8)) * Basis(Vector3.UP, randf() * TAU)
		n.scale = Vector3(sc, sc * 0.42, sc)
		n.global_position = spot + Vector3(0, -sc * 0.5, 0)
		var tw := n.create_tween()
		tw.tween_property(n, "global_position", spot + Vector3(0, sc * 0.05, 0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(life + randf())
		tw.tween_property(n, "global_position", spot + Vector3(0, -sc * 0.7, 0), 0.8).set_ease(Tween.EASE_IN)
		tw.tween_callback(n.queue_free)


static func splash(pos: Vector3, s := 1.0, amount := 22) -> void:
	burst(pos, {"amount": amount, "life": 0.7, "vmin": 2.0 * s, "vmax": 7.0 * s, "spread": 75.0, "damping": 1.0,
		"size": 0.5 * s, "scurve": [1.0, 0.6, 0.0], "gravity": Vector3(0, -16, 0), "radius": 0.3 * s,
		"colors": [Color(0.85, 0.97, 1.0, 1.0), Color(0.45, 0.8, 1.0, 0.8), Color(0.3, 0.7, 1.0, 0.0)]})
	burst(pos, {"amount": int(amount * 0.5), "life": 0.5, "vmin": 0.5, "vmax": 2.5 * s, "spread": 180.0, "damping": 3.0,
		"size": 1.3 * s, "scurve": [0.6, 1.2], "radius": 0.4 * s,
		"colors": [Color(0.8, 0.95, 1.0, 0.7), Color(0.7, 0.9, 1.0, 0.0)]})


static func ice_burst(pos: Vector3, s := 1.0) -> void:
	burst(pos, {"amount": 14, "life": 0.5, "vmin": 2.0, "vmax": 7.0 * s, "spread": 180.0, "damping": 3.0,
		"size": 0.3 * s, "gravity": Vector3(0, -10, 0), "add": true,
		"colors": [Color(1.6, 2.2, 2.6, 1.0), Color(0.6, 0.9, 1.2, 0.0)]})
	burst(pos, {"amount": 8, "life": 0.6, "vmin": 0.3, "vmax": 1.5, "spread": 180.0, "damping": 2.0,
		"size": 1.4 * s, "scurve": [0.5, 1.2], "colors": [Color(0.85, 0.95, 1.0, 0.6), Color(0.9, 0.97, 1.0, 0.0)]})


static func air_puff(pos: Vector3, s := 1.0, amount := 14) -> void:
	burst(pos, {"amount": amount, "life": 0.5, "vmin": 3.0 * s, "vmax": 8.0 * s, "spread": 180.0, "damping": 8.0,
		"size": 1.4 * s, "scurve": [0.5, 1.3], "radius": 0.2,
		"colors": [Color(1, 1, 1, 0.75), Color(0.9, 1.0, 0.98, 0.3), Color(1, 1, 1, 0.0)]})


static func wisps(pos: Vector3, col: Color, s := 1.0, amount := 20) -> void:
	burst(pos, {"amount": amount, "life": 1.0, "vmin": 0.5, "vmax": 3.0 * s, "spread": 180.0, "damping": 2.0,
		"size": 0.8 * s, "scurve": [1.0, 0.0], "gravity": Vector3(0, 3.5, 0), "radius": 0.6 * s, "add": true, "turb": 2.0,
		"colors": [Color(col.r * 2.5, col.g * 2.5, col.b * 2.5, 1.0), Color(col.r, col.g, col.b, 0.0)]})


static func ring(pos: Vector3, col: Color, r0: float, r1: float, dur := 0.4, thickness := 0.2, fill := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = shader("ring")
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("thickness", thickness)
	m.set_shader_parameter("fill", fill)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.main.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.12, 0)
	mi.scale = Vector3(r0, 1, r0)
	var fade := func(v: float): m.set_shader_parameter("fade", v)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(r1, 1, r1), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(fade, 1.0, 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


static func flash(pos: Vector3, col: Color, energy := 6.0, rng := 9.0, dur := 0.25) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	Game.main.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


static func debris(pos: Vector3, n := 6, speed := 7.0, size := 0.3) -> void:
	for i in n:
		var b := RigidBody3D.new()
		b.collision_layer = Game.L_DEBRIS
		b.collision_mask = Game.L_WORLD
		var mi := prop("rock_%d" % (randi() % 4))
		var s := size * randf_range(0.5, 1.2)
		mi.scale = Vector3.ONE * s
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = s * 0.45
		cs.shape = sh
		b.add_child(cs)
		Game.main.add_child(b)
		b.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))
		b.linear_velocity = Vector3(randf_range(-1, 1), randf_range(0.5, 1.4), randf_range(-1, 1)) * speed
		b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tw := b.create_tween()
		tw.tween_interval(randf_range(1.2, 2.0))
		tw.tween_property(mi, "scale", Vector3.ZERO, 0.4)
		tw.tween_callback(b.queue_free)


static func number(pos: Vector3, text: String, col: Color, big := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64 if big else 44
	l.outline_size = 14
	l.modulate = col
	l.outline_modulate = Color(0.05, 0.03, 0.08, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.render_priority = 5
	Game.main.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.6), randf_range(-0.4, 0.4))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.5, 0), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


static func prewarm(at: Vector3) -> void:
	# Draw every effect once, hidden under the ground, so nothing stutters the first time it is used.
	var p := at + Vector3(0, -5, 0)
	dust(p)
	sparks(p, Color.WHITE)
	fire_burst(p)
	splash(p)
	ice_burst(p)
	air_puff(p)
	wisps(p, Color.WHITE)
	ring(p, Color.WHITE, 1.0, 2.0, 0.3)
	debris(p, 1)
	number(p, "0", Color(1, 1, 1, 0.0))
	crack(p, 1.0, "radial", 0.0, 0.2)
	crack(p, 1.0, "line", 0.0, 0.2)
	embers(p)
	for m in ["rock_0", "pillar", "spike", "ice_shard", "wave", "totem", "crystal", "ashen_grunt", "ashen_caster", "ashen_brute", "ashen_king"]:
		var n := prop(m)
		Game.main.add_child(n)
		n.global_position = p
		_free_later(n, 1.0)
	var mats := [flow(Color.WHITE, Color.WHITE), glow_mat(Color.WHITE), toon(Color.WHITE, {"outline": 0.01})]
	for m2 in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		mi.material_override = m2
		Game.main.add_child(mi)
		mi.global_position = p
		_free_later(mi, 1.0)
	var anchor := Node3D.new()
	Game.main.add_child(anchor)
	anchor.global_position = p
	Trail.attach(anchor, 0.3, 0.3, Color.WHITE, Color.WHITE, true)
	Trail.attach(anchor, 0.3, 0.3, Color.WHITE, Color.WHITE, false)
	anchor.create_tween().tween_property(anchor, "global_position", p + Vector3(1, 0, 0), 0.5)
	_free_later(anchor, 1.0)
