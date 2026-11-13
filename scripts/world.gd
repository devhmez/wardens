class_name World
extends Node3D
# The island of Aerath: terrain, sea, sky, vegetation and landmarks.

const SIZE := 340.0
const STEP := 1.5
const SHRINE := Vector2(-70, 60)
const VILLAGE := Vector2(30, 40)
const LAKE := Vector2(66, 58)
const FORT := Vector2(0, -85)
const FLATS := [
	[-70.0, 60.0, 20.0, 9.0, 16.0],
	[30.0, 40.0, 24.0, 2.8, 18.0],
	[0.0, -85.0, 27.0, 19.0, 24.0],
]
const PATH := [Vector2(-70, 60), Vector2(-46, 53), Vector2(-12, 50), Vector2(30, 40), Vector2(30, 8),
	Vector2(16, -28), Vector2(6, -55), Vector2(0, -85)]

const MOODS := {
	"dawn": {"top": Color(0.16, 0.34, 0.74), "horizon": Color(0.98, 0.76, 0.6), "bottom": Color(0.4, 0.44, 0.56),
		"sun": Color(1.0, 0.82, 0.66), "energy": 1.9, "elev": 22.0, "azim": 115.0, "ambient": Color(0.55, 0.58, 0.78),
		"amb_e": 1.5, "fog": Color(0.98, 0.8, 0.7), "fog_d": 0.0011, "vfog": 0.0028, "cover": 0.47,
		"cl": Color(1.0, 0.9, 0.82), "cs": Color(0.58, 0.5, 0.56)},
	"day": {"top": Color(0.09, 0.3, 0.76), "horizon": Color(0.62, 0.79, 0.94), "bottom": Color(0.36, 0.5, 0.62),
		"sun": Color(1.0, 0.96, 0.88), "energy": 3.0, "elev": 50.0, "azim": 140.0, "ambient": Color(0.6, 0.7, 0.88),
		"amb_e": 1.5, "fog": Color(0.72, 0.84, 0.96), "fog_d": 0.0008, "vfog": 0.0012, "cover": 0.5,
		"cl": Color(1, 1, 1), "cs": Color(0.55, 0.6, 0.7)},
	"sunset": {"top": Color(0.14, 0.2, 0.52), "horizon": Color(1.0, 0.56, 0.3), "bottom": Color(0.42, 0.3, 0.34),
		"sun": Color(1.0, 0.62, 0.36), "energy": 2.2, "elev": 12.0, "azim": 250.0, "ambient": Color(0.52, 0.45, 0.66),
		"amb_e": 1.6, "fog": Color(1.0, 0.62, 0.42), "fog_d": 0.0014, "vfog": 0.0034, "cover": 0.55,
		"cl": Color(1.0, 0.72, 0.5), "cs": Color(0.42, 0.3, 0.42)},
	"dusk": {"top": Color(0.06, 0.09, 0.28), "horizon": Color(0.38, 0.22, 0.4), "bottom": Color(0.1, 0.09, 0.18),
		"sun": Color(0.6, 0.68, 1.0), "energy": 2.6, "elev": 34.0, "azim": 20.0, "ambient": Color(0.34, 0.32, 0.56),
		"amb_e": 9.0, "fog": Color(0.26, 0.2, 0.42), "fog_d": 0.002, "vfog": 0.004, "cover": 0.6,
		"cl": Color(0.4, 0.36, 0.56), "cs": Color(0.1, 0.09, 0.2)},
}

var noise := FastNoiseLite.new()
var noise_d := FastNoiseLite.new()
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var mood := {}
var dock_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	noise.seed = 11
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 3
	noise_d.seed = 5
	noise_d.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_d.frequency = 0.045
	noise_d.fractal_octaves = 2
	_build_sky()
	_build_terrain()
	_build_water()
	_build_landmarks()
	_build_vegetation()
	_build_grass()
	apply_mood(MOODS["dawn"])


# ------------------------------------------------------------------ terrain maths
func height_at(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var h := 5.5 + n * 8.0 + noise_d.get_noise_2d(x, z) * 1.1
	h += 12.0 * smoothstep(20.0, -90.0, z) * smoothstep(120.0, 40.0, absf(x))
	h = maxf(h, 2.2 + n)
	var ld := Vector2(x - LAKE.x, z - LAKE.y).length()
	h = lerpf(h, -3.6, smoothstep(31.0, 11.0, ld))
	for f in FLATS:
		var fd := Vector2(x - f[0], z - f[1]).length()
		h = lerpf(h, f[3], smoothstep(f[2] + f[4], f[2], fd))
	var d := sqrt(x * x + z * z)
	h = lerpf(-7.0, h, smoothstep(152.0, 116.0, d + n * 14.0))
	return h


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.0
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()


func path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for i in PATH.size() - 1:
		var a: Vector2 = PATH[i]
		var b: Vector2 = PATH[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)


func _clear_of_sites(x: float, z: float, pad := 0.0) -> bool:
	var p := Vector2(x, z)
	if p.distance_to(SHRINE) < 15.0 + pad:
		return false
	if p.distance_to(VILLAGE) < 24.0 + pad:
		return false
	if p.distance_to(FORT) < 27.0 + pad:
		return false
	return true


# ------------------------------------------------------------------ sky + light
func _build_sky() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = FX.shader("sky")
	sky_mat.set_shader_parameter("noise_tex", FX.noise_tex())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.85
	# bounced light
	env.sdfgi_enabled = false      # F10 turns bounced lighting on; it costs about 9 fps on an M3 Air
	env.sdfgi_cascades = 3
	env.sdfgi_min_cell_size = 0.8
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 1.0
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssil_enabled = false
	# light shafts and haze
	env.volumetric_fog_enabled = true
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_ambient_inject = 0.4
	env.volumetric_fog_gi_inject = 0.6
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.6
	env.fog_sun_scatter = 0.08
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 1.6
	add_child(sun)


func apply_mood(m: Dictionary) -> void:
	mood = m
	sky_mat.set_shader_parameter("top_color", m["top"])
	sky_mat.set_shader_parameter("horizon_color", m["horizon"])
	sky_mat.set_shader_parameter("bottom_color", m["bottom"])
	sky_mat.set_shader_parameter("sun_color", m["sun"])
	sky_mat.set_shader_parameter("cloud_light", m["cl"])
	sky_mat.set_shader_parameter("cloud_shade", m["cs"])
	sky_mat.set_shader_parameter("cloud_cover", m["cover"])
	sun.light_color = m["sun"]
	sun.light_energy = m["energy"]
	sun.rotation = Vector3(deg_to_rad(-m["elev"]), deg_to_rad(m["azim"]), 0)
	env.ambient_light_energy = m["amb_e"]
	env.fog_light_color = m["fog"]
	env.fog_density = m["fog_d"]
	env.volumetric_fog_albedo = m["fog"]
	env.volumetric_fog_density = m["vfog"]


func set_mood(mname: String, dur := 4.0) -> void:
	var a: Dictionary = mood.duplicate()
	var b: Dictionary = MOODS[mname]
	var step := func(k: float):
		var m := {}
		for key in b:
			if b[key] is Color:
				m[key] = a[key].lerp(b[key], k)
			elif key == "azim":
				m[key] = rad_to_deg(lerp_angle(deg_to_rad(a[key]), deg_to_rad(b[key]), k))
			else:
				m[key] = lerpf(a[key], b[key], k)
		apply_mood(m)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)


# ------------------------------------------------------------------ terrain mesh
func _build_terrain() -> void:
	var n := int(SIZE / STEP) + 1
	var half := SIZE * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for iz in n:
		for ix in n:
			hs[iz * n + ix] = height_at(ix * STEP - half, iz * STEP - half)
	for iz in n:
		for ix in n:
			var x := ix * STEP - half
			var z := iz * STEP - half
			var hl := hs[iz * n + maxi(ix - 1, 0)]
			var hr := hs[iz * n + mini(ix + 1, n - 1)]
			var hu := hs[maxi(iz - 1, 0) * n + ix]
			var hd := hs[mini(iz + 1, n - 1) * n + ix]
			st.set_normal(Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized())
			var pth := smoothstep(4.2, 1.6, path_dist(x, z))
			var sc := smoothstep(44.0, 18.0, Vector2(x, z).distance_to(FORT))
			st.set_color(Color(pth, sc, 0.0, 1.0))
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, hs[iz * n + ix], z))
	for iz in n - 1:
		for ix in n - 1:
			var i := iz * n + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = FX.shader("terrain")
	m.set_shader_parameter("noise_tex", FX.noise_tex())
	for layer in [["grass", "leafy_grass"], ["rock", "rock_face_03"], ["sand", "coast_sand_01"], ["road", "brown_mud_dry"]]:
		m.set_shader_parameter(layer[0] + "_d", FX.tex(layer[1] + "_diff"))
		m.set_shader_parameter(layer[0] + "_n", FX.tex(layer[1] + "_nor"))
		m.set_shader_parameter(layer[0] + "_arm", FX.tex(layer[1] + "_arm"))
	mi.material_override = m
	mi.layers = 3
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	pm.subdivide_width = 140
	pm.subdivide_depth = 140
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = FX.shader("water")
	m.set_shader_parameter("noise_tex", FX.noise_tex())
	m.set_shader_parameter("normal_tex", FX.normal_tex())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ props
func place(mname: String, pos: Vector3, yaw := 0.0, s := 1.0, collide := "") -> Node3D:
	var n := FX.prop(mname)
	add_child(n)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	if collide == "mesh":
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			mi.create_trimesh_collision()
	return n


func plant(nname: String, pos: Vector3, height: float, yaw := 0.0, pink := false) -> Node3D:
	var n := FX.nature(nname, pink)
	add_child(n)
	var s := height / FX.height_of(n)
	n.scale = Vector3.ONE * s
	n.position = pos
	n.rotation.y = yaw
	return n


func cylinder(pos: Vector3, r: float, h: float) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Game.L_WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	b.add_child(cs)
	add_child(b)
	b.position = pos + Vector3(0, h * 0.5, 0)


func lamp(pos: Vector3, col := Color(1.0, 0.8, 0.5), energy := 2.5, rng := 9.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy * 2.2
	l.omni_range = rng
	l.omni_attenuation = 1.4
	add_child(l)
	l.position = pos


func _build_landmarks() -> void:
	# --- Dawn Shrine
	var sh := ground(SHRINE.x, SHRINE.y)
	var plat := place("shrine_platform", sh, 0.0, 1.0, "mesh")
	for pm in plat.find_children("*", "MeshInstance3D", true, false):
		pm.layers = 3
	var els := ["earth", "fire", "water", "air"]
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var p := sh + Vector3(cos(a) * 8.2, 0.25, sin(a) * 8.2)
		place("shrine_stone_" + els[i], p, -a, 1.0)
		cylinder(p, 0.7, 4.2)
		lamp(p + Vector3(0, 4.9, 0), Game.EL_COLORS[els[i]], 1.6, 7.0)
	place("arch", sh + Vector3(13.5, -0.3, -2.0), PI * 0.5 + 0.15, 1.0, "mesh")
	for i in 6:
		var a2 := i * TAU / 6.0 + 0.5
		var lp := sh + Vector3(cos(a2) * 11.6, -0.2, sin(a2) * 11.6)
		lp.y = height_at(lp.x, lp.z) - 0.05
		place("lantern", lp, a2)
		lamp(lp + Vector3(0, 2.3, 0), Color(1.0, 0.8, 0.5), 1.4, 6.0)
	for i in 9:
		var a3 := i * TAU / 9.0 + 0.2
		var r := 19.0 + _rng.randf() * 5.0
		var tp := ground(SHRINE.x + cos(a3) * r, SHRINE.y + sin(a3) * r, -0.15)
		if path_dist(tp.x, tp.z) < 4.5:
			continue
		plant("TwistedTree_%d" % (1 + i % 5), tp, _rng.randf_range(7.0, 9.5), _rng.randf() * TAU)
		cylinder(tp, 0.4, 3.0)

	# --- Mirren village
	var vc := ground(VILLAGE.x, VILLAGE.y)
	var huts := [[-13.0, -9.0, 0], [-15.0, 7.0, 1], [-4.0, 16.5, 2], [10.0, -14.0, 1], [-2.0, -17.0, 0], [16.0, 3.0, 2]]
	for hh in huts:
		var hp := ground(VILLAGE.x + hh[0], VILLAGE.y + hh[1], 0.05)
		var face := atan2(-hh[0], -hh[1])
		place("hut_%d" % hh[2], hp, face)
		cylinder(hp, 3.1 + hh[2] * 0.4, 5.0)
		lamp(hp + Vector3(sin(face) * 4.0, 2.2, cos(face) * 4.0), Color(1.0, 0.78, 0.45), 1.6, 7.0)
	for lp2 in [Vector2(6, 7), Vector2(-8, -6), Vector2(7, -8), Vector2(-5, 11)]:
		var l3 := ground(VILLAGE.x + lp2.x, VILLAGE.y + lp2.y, -0.05)
		place("lantern", l3, _rng.randf() * TAU)
		lamp(l3 + Vector3(0, 2.3, 0), Color(1.0, 0.8, 0.5), 1.6, 7.0)
	place("crates", ground(VILLAGE.x + 8, VILLAGE.y - 5), 0.7)
	place("crates", ground(VILLAGE.x - 9, VILLAGE.y + 12), 2.1)
	# dock: march from the village toward the lake until the shore
	var dirv := (LAKE - VILLAGE).normalized()
	var q := VILLAGE
	for i in 80:
		q += dirv * 0.5
		if height_at(q.x, q.y) < 0.35:
			break
	dock_pos = Vector3(q.x, 0.55, q.y)
	var dock := place("dock", dock_pos, atan2(dirv.x, dirv.y) + PI, 1.0, "mesh")
	dock.rotation.y = atan2(-dirv.x, -dirv.y)

	# --- The Hollow Gate (fort)
	var fc := ground(FORT.x, FORT.y)
	for i in 20:
		var a4 := i * TAU / 20.0
		# leave the southern gate open
		if absf(angle_difference(a4, PI * 0.5)) < 0.36:
			continue
		var pp := fc + Vector3(cos(a4) * 23.0, 0, sin(a4) * 23.0)
		pp.y = height_at(pp.x, pp.z)
		place("palisade", pp, -a4 + PI * 0.5, 1.0)
		var bb := StaticBody3D.new()
		bb.collision_layer = Game.L_WORLD
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(8.0, 6.0, 1.0)
		cs.shape = bs
		bb.add_child(cs)
		add_child(bb)
		bb.position = pp + Vector3(0, 2.5, 0)
		bb.rotation.y = -a4 + PI * 0.5
	for sx in [-1.0, 1.0]:
		var tp2 := ground(FORT.x + sx * 8.5, FORT.y + 23.5)
		place("tower", tp2, 0.0)
		cylinder(tp2, 2.2, 8.0)
		lamp(tp2 + Vector3(0, 7.3, 0), Color(0.8, 0.4, 1.0), 2.6, 12.0)
		place("banner", ground(FORT.x + sx * 5.0, FORT.y + 26.0), PI * 0.5 * sx + PI * 0.5)
	for i in 5:
		var a5 := i * TAU / 5.0 + 0.9
		place("banner", fc + Vector3(cos(a5) * 20.0, 0, sin(a5) * 20.0), -a5 + PI)
	lamp(fc + Vector3(0, 5, 0), Color(0.7, 0.35, 1.0), 2.0, 22.0)


func _build_vegetation() -> void:
	var fort_v := Vector2(FORT.x, FORT.y)
	var placed := 0
	var tries := 0
	while placed < 180 and tries < 4000:
		tries += 1
		var x := _rng.randf_range(-140, 140)
		var z := _rng.randf_range(-140, 140)
		var h := height_at(x, z)
		if h < 2.2 or normal_at(x, z).y < 0.86 or path_dist(x, z) < 5.0 or not _clear_of_sites(x, z, 3.0):
			continue
		# cluster trees with noise so there are groves and open meadows
		if noise_d.get_noise_2d(x * 0.25 + 300.0, z * 0.25) < -0.05:
			continue
		var near_fort := Vector2(x, z).distance_to(fort_v) < 55.0
		var kind := "CommonTree_%d" % _rng.randi_range(1, 5)
		var th := _rng.randf_range(7.0, 11.0)
		if near_fort:
			kind = ("DeadTree_%d" if _rng.randf() < 0.6 else "TwistedTree_%d") % _rng.randi_range(1, 5)
			th = _rng.randf_range(6.0, 9.0)
		elif (z < -20.0 or h > 14.0) and _rng.randf() < 0.8:
			kind = "Pine_%d" % _rng.randi_range(1, 5)
			th = _rng.randf_range(9.0, 14.0)
		elif _rng.randf() < 0.05:
			kind = "TwistedTree_%d" % _rng.randi_range(1, 5)
		plant(kind, Vector3(x, h - 0.15, z), th, _rng.randf() * TAU)
		cylinder(Vector3(x, h, z), 0.4, 3.0)
		placed += 1
	# rocks
	placed = 0
	tries = 0
	while placed < 55 and tries < 3000:
		tries += 1
		var x2 := _rng.randf_range(-140, 140)
		var z2 := _rng.randf_range(-140, 140)
		var h2 := height_at(x2, z2)
		if h2 < 0.6 or path_dist(x2, z2) < 4.5 or not _clear_of_sites(x2, z2, 1.0):
			continue
		var rk := plant("Rock_Medium_%d" % _rng.randi_range(1, 3), Vector3(x2, h2 - 0.25, z2), _rng.randf_range(1.2, 3.6), _rng.randf() * TAU)
		for mi in rk.find_children("*", "MeshInstance3D", true, false):
			mi.create_trimesh_collision()
		placed += 1
	# undergrowth: bushes, ferns, flowers, mushrooms (no collision)
	var kinds := [["Bush_Common", 1.3, 3], ["Bush_Common_Flowers", 1.3, 2], ["Fern_1", 0.75, 4], ["Plant_1", 0.6, 3], ["Plant_7", 0.7, 3],
		["Plant_1_Big", 1.0, 2], ["Flower_3_Group", 0.45, 4], ["Flower_4_Group", 0.45, 4], ["Clover_1", 0.25, 2], ["Mushroom_Common", 0.3, 1]]
	var bag: Array = []
	for k in kinds:
		for i in k[2]:
			bag.append(k)
	placed = 0
	tries = 0
	while placed < 420 and tries < 6000:
		tries += 1
		var x3 := _rng.randf_range(-140, 140)
		var z3 := _rng.randf_range(-140, 140)
		var h3 := height_at(x3, z3)
		if h3 < 2.1 or normal_at(x3, z3).y < 0.86 or path_dist(x3, z3) < 3.0 or not _clear_of_sites(x3, z3, 0.0):
			continue
		if Vector2(x3, z3).distance_to(fort_v) < 45.0:
			continue
		var k2: Array = bag[_rng.randi() % bag.size()]
		var n := plant(k2[0], Vector3(x3, h3 - 0.04, z3), k2[1] * _rng.randf_range(0.8, 1.35), _rng.randf() * TAU)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if k2[1] < 1.2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.visibility_range_end = 75.0
		placed += 1
	# pebbles along the road
	for i in 90:
		var seg := _rng.randi_range(0, PATH.size() - 2)
		var pp: Vector2 = PATH[seg].lerp(PATH[seg + 1], _rng.randf())
		var off := Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
		if off.length() < 2.2:
			continue
		pp += off
		var pk := "Pebble_Round_%d" % _rng.randi_range(1, 5) if _rng.randf() < 0.5 else "Pebble_Square_%d" % _rng.randi_range(1, 6)
		var pn := plant(pk, Vector3(pp.x, height_at(pp.x, pp.y) - 0.03, pp.y), _rng.randf_range(0.12, 0.3), _rng.randf() * TAU)
		for mi in pn.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 60.0


func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for b in 6:
		var a := rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.34, 0.34), 0, rng.randf_range(-0.34, 0.34))
		var right := Vector3(cos(a), 0, sin(a)) * 0.026
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var hh := rng.randf_range(0.22, 0.6)
		var pts: Array = []
		for sgm in 3:
			var t := sgm / 2.0
			var w := 1.0 - t * 0.85
			var c := off + lean * t * t + Vector3(0, hh * t, 0)
			pts.append([c - right * w, c + right * w, t])
		for sgm in 2:
			var p0: Array = pts[sgm]
			var p1: Array = pts[sgm + 1]
			for v in [[p0[0], p0[2]], [p0[1], p0[2]], [p1[0], p1[2]], [p0[1], p0[2]], [p1[1], p1[2]], [p1[0], p1[2]]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0.5, v[1]))
				st.add_vertex(v[0])
	return st.commit()


func _build_grass() -> void:
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = FX.shader("grass")
	grass_mat.set_shader_parameter("noise_tex", FX.noise_tex())
	var blade := _blade_mesh()
	var chunk := 28.0
	var per := 1050
	var cz := -140.0
	while cz < 140.0:
		var cx := -140.0
		while cx < 140.0:
			var xfs: Array = []
			var center := Vector3(cx + chunk * 0.5, 0, cz + chunk * 0.5)
			center.y = height_at(center.x, center.z)
			for i in per:
				var x := cx + _rng.randf() * chunk
				var z := cz + _rng.randf() * chunk
				var h := height_at(x, z)
				if h < 2.0:
					continue
				if path_dist(x, z) < 2.6:
					continue
				var p2 := Vector2(x, z)
				if p2.distance_to(SHRINE) < 11.6:
					continue
				if p2.distance_to(FORT) < 30.0 and _rng.randf() < 0.85:
					continue
				var nrm := normal_at(x, z)
				if nrm.y < 0.84:
					continue
				var s := _rng.randf_range(0.75, 1.25)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s))
				xfs.append(Transform3D(b, Vector3(x, h - 0.03, z) - center))
			if xfs.is_empty():
				cx += chunk
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = blade
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = grass_mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 66.0
			mmi.visibility_range_end_margin = 8.0
			add_child(mmi)
			mmi.position = center
			cx += chunk
		cz += chunk


func _process(_dt: float) -> void:
	if Game.player and grass_mat:
		grass_mat.set_shader_parameter("player_pos", Game.player.global_position)
