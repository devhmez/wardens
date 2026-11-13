class_name Puppet
extends Node3D
# A character assembled from a body, an outfit and hair on one shared skeleton,
# animated with the Universal Animation Library. Models face +Z.

const DIR := "res://assets/chars/"

# body: head (and hands) shown under the outfit.  hide: outfit pieces removed.  tint: recolour.
const CHARS := {
	"warden_earth": {"body": "Superhero_Male_FullBody", "outfit": "Male_Ranger", "hide": ["Head_Hood"], "hair": ["Hair_Buzzed", "Hair_Beard"], "mask": 1,
		"hair_color": Color(0.38, 0.25, 0.15)},
	"warden_fire": {"body": "Superhero_Male_FullBody", "outfit": "Male_Ranger", "hide": ["Head_Hood", "Acc_Pauldron"], "hair": ["Hair_SimpleParted"], "mask": 1,
		"tint": Color(1.0, 0.13, 0.08), "tint_amount": 0.85, "hair_color": Color(0.1, 0.08, 0.08)},
	"warden_water": {"body": "Superhero_Female_FullBody", "outfit": "Female_Peasant", "hide": [], "hair": ["Hair_Long"], "mask": 2,
		"tint": Color(0.16, 0.45, 1.0), "tint_amount": 0.85, "hair_color": Color(0.24, 0.14, 0.08)},
	"warden_air": {"body": "Superhero_Female_FullBody", "outfit": "Female_Ranger", "hide": [], "hair": [], "mask": 1,
		"tint": Color(0.8, 1.0, 0.96), "tint_amount": 0.9, "hair_color": Color(0.5, 0.5, 0.5)},
	"ashen_grunt": {"outfit": "Male_Ranger", "hide": ["Acc_Pauldron"], "hollow": Color(0.75, 0.4, 1.0), "tint": Color(0.5, 0.42, 0.7), "tint_amount": 0.9, "dark": 0.42},
	"ashen_caster": {"outfit": "Female_Ranger", "hide": [], "hollow": Color(1.0, 0.4, 0.8), "tint": Color(0.7, 0.3, 0.9), "tint_amount": 0.9, "dark": 0.5},
	"ashen_brute": {"outfit": "Male_Ranger", "hide": [], "hollow": Color(1.0, 0.5, 0.2), "tint": Color(0.75, 0.25, 0.2), "tint_amount": 0.85, "dark": 0.4},
	"ashen_king": {"outfit": "Male_Ranger", "hide": [], "hollow": Color(1.0, 0.15, 0.3), "tint": Color(0.9, 0.7, 0.3), "tint_amount": 0.6, "dark": 0.3, "crown": true},
}

# action -> [clip, speed, start offset (s into the clip), mode, cut, next]
#   mode: "auto" = upper body only while moving, "full" = whole body, "upper" = always upper body only
#   cut:  seconds after which moving cancels the rest of the clip (0 = never)
#   next: action played automatically when this one ends
# Offsets and speeds were set from contact sheets of each clip so the key pose lands when the effect fires.
const ACTIONS := {
	"punchR": ["Punch_Cross", 1.8, 0.11, "auto", 0.22, ""],          # arm extended ~0.06 s after the call
	"punchL": ["Punch_Jab", 1.8, 0.08, "auto", 0.22, ""],
	"lift": ["Sword_Regular_A", 1.6, 0.05, "auto", 0.0, ""],          # crouch, then rip upward as the rock rises
	"push": ["Shield_OneShot", 1.6, 0.08, "auto", 0.3, ""],           # palm thrust at ~0.07 s
	"stomp": ["OverhandThrow", 1.6, 0.2, "full", 0.45, ""],           # overhead slam lands at ~0.16 s
	"slam_down": ["NinjaJump_Land", 1.3, 0.1, "full", 0.4, ""],
	"leap": ["NinjaJump_Start", 1.5, 0.05, "full", 0.0, "leap_hold"],
	"leap_hold": ["NinjaJump_Idle", 1.0, 0.0, "full", 0.0, ""],
	"sweepR": ["Sword_Regular_A", 1.5, 0.05, "auto", 0.25, ""],       # slash passes at ~0.12 s
	"sweepL": ["Sword_Regular_B", 1.6, 0.1, "auto", 0.25, ""],
	"raise": ["Spell_Simple_Enter", 1.2, 0.0, "auto", 0.0, "shoot"],  # arm up, then release
	"shoot": ["Spell_Simple_Shoot", 1.0, 0.0, "auto", 0.3, ""],
	"channel": ["Spell_Simple_Idle", 1.0, 0.0, "auto", 0.0, ""],
	"burst": ["Sword_Block", 1.6, 0.05, "full", 0.4, ""],             # arms thrown wide, braced
	"summon": ["Sword_Block", 0.85, 0.05, "full", 0.0, ""],           # the same pose held for a long wind-up
	"shove": ["Push", 1.0, 0.0, "full", 0.0, "", 0.55],               # two-handed push, held briefly
	"spin": ["Sword_Regular_C", 1.6, 0.1, "full", 0.55, ""],          # leaping spin, airborne ~0.1-0.25 s
	"dash_strike": ["Sword_Dash", 1.6, 0.2, "full", 0.4, ""],         # low lunge held through the dash
	"hit": ["Hit_Chest", 1.0, 0.0, "upper", 0.0, ""],
	"knockdown": ["Hit_Knockback", 1.1, 0.0, "full", 0.0, "getup"],
	"getup": ["LayToIdle", 1.3, 0.0, "full", 0.0, ""],
	"roll": ["Roll", 2.6, 0.12, "full", 0.32, ""],
	"windup": ["Zombie_Scratch", 1.25, 0.0, "full", 0.0, ""],         # claw swipe connects at ~0.48 s
	"strike": ["Melee_Hook", 1.4, 0.1, "auto", 0.0, ""],
	"slam_up": ["Sword_Attack", 0.66, 0.0, "full", 0.0, ""],          # slow overhead, lands at ~0.9 s
	"cast": ["Spell_Simple_Enter", 0.9, 0.0, "auto", 0.0, "cast_hold"],
	"cast_hold": ["Spell_Simple_Idle", 1.0, 0.0, "auto", 0.0, ""],
	"brace": ["Sword_Block", 0.8, 0.0, "full", 0.0, ""],
	"charge": ["Sword_Dash", 0.8, 0.3, "full", 0.0, ""],
}
const UPPER := ["spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]

static var _lib: AnimationLibrary
static var _scenes := {}

var mats: Array = []
var move := 0.0
var grounded := true
var gliding := false
var stance := 0.0
var spin := 0.0
var bob_scale := 1.0
var action := ""
var down := 0.0:
	set(v):
		down = v
		if tree == null:
			return
		if v > 0.01 and not _dead:
			_dead = true
			tree.set("parameters/state/transition_request", "dead")
		elif v <= 0.01 and _dead:
			_dead = false
			tree.set("parameters/state/transition_request", "alive")

var model: Node3D
var skel: Skeleton3D
var tree: AnimationTree
var _act: AnimationNodeAnimation
var _air: AnimationNodeAnimation
var _shot: AnimationNodeOneShot
var _dead := false
var _flash := 0.0
var _flash_on := false
var _blend := 0.0
var _airb := 0.0
var _next := ""
var _cut := 0.0
var _act_t := 0.0
var _dur := 0.0
var _life := 0.0


static func _scene(sname: String) -> PackedScene:
	if not _scenes.has(sname):
		_scenes[sname] = load(DIR + sname + (".glb" if sname.begins_with("UAL") else ".gltf"))
	return _scenes[sname]


static func library() -> AnimationLibrary:
	if _lib == null:
		_lib = AnimationLibrary.new()
		for f in ["UAL1", "UAL2"]:
			var n: Node = _scene(f).instantiate()
			var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
			for a in ap.get_animation_list():
				if not _lib.has_animation(a):
					_lib.add_animation(a, ap.get_animation(a))
			n.free()
	return _lib


func setup(cname: String, _outline := 0.0) -> void:
	var c: Dictionary = CHARS[cname]
	var has_body: bool = c.has("body")
	model = _scene(c["body"] if has_body else c["outfit"]).instantiate()
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	if has_body:
		for mi in skel.find_children("*", "MeshInstance3D", true, false):
			var is_skin: bool = mi.name.to_lower().begins_with("superhero")
			if is_skin:
				_convert(mi, {"mask_mode": c.get("mask", 1)})
			elif mi.name.begins_with("Eyebrow") or mi.name.begins_with("Hair"):
				_convert(mi, {"albedo": c.get("hair_color", Color(0.3, 0.2, 0.12))})
			else:
				_convert(mi, {})
		_graft(c["outfit"], c)
	else:
		for mi in skel.find_children("*", "MeshInstance3D", true, false):
			if _hidden(mi.name, c):
				mi.queue_free()
			else:
				_convert(mi, _outfit_opts(c))
	for h in c.get("hair", []):
		_graft(h, {"dark_color": c.get("hair_color", Color(0.3, 0.2, 0.12))})
	if c.has("hollow"):
		_hollow(c)
	_build_tree()


func _hidden(mesh_name: String, c: Dictionary) -> bool:
	for h in c.get("hide", []):
		if mesh_name.contains(h):
			return true
	return false


func _outfit_opts(c: Dictionary) -> Dictionary:
	var o := {}
	if c.has("tint"):
		o["tint"] = c["tint"]
		o["tint_amount"] = c.get("tint_amount", 0.5)
	if c.has("dark"):
		var d: float = c["dark"]
		o["albedo"] = Color(d, d, d)
	if c.has("dark_color"):
		o["albedo"] = c["dark_color"]
	if c.has("tex"):
		o["tex_albedo"] = load(DIR + c["tex"] + ".png")
	return o


func _graft(scene_name: String, c: Dictionary) -> void:
	# Move another model's skinned meshes onto this character's skeleton.
	var other: Node = _scene(scene_name).instantiate()
	for mi in other.find_children("*", "MeshInstance3D", true, false):
		if _hidden(mi.name, c):
			continue
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		var opts := _outfit_opts(c)
		# skin-coloured pieces of an outfit (hands, neck) keep their own texture and colour
		_convert(mi, opts)
	other.free()


func _convert(mi: MeshInstance3D, opts: Dictionary) -> void:
	for s in mi.mesh.get_surface_count():
		var src = mi.mesh.surface_get_material(s)
		var m := ShaderMaterial.new()
		m.shader = FX.shader("character")
		m.set_shader_parameter("noise_tex", FX.noise_tex())
		var is_skin := false
		if src is BaseMaterial3D:
			is_skin = src.resource_name.contains("Regular") or src.resource_name.contains("Superhero")
			m.set_shader_parameter("has_albedo", src.albedo_texture != null)
			m.set_shader_parameter("tex_albedo", src.albedo_texture)
			m.set_shader_parameter("albedo", src.albedo_color)
			m.set_shader_parameter("roughness", src.roughness)
			m.set_shader_parameter("metallic", src.metallic)
			if src.normal_enabled and src.normal_texture != null:
				m.set_shader_parameter("has_normal", true)
				m.set_shader_parameter("tex_normal", src.normal_texture)
			if src.roughness_texture != null:
				m.set_shader_parameter("has_orm", true)
				m.set_shader_parameter("tex_orm", src.roughness_texture)
				m.set_shader_parameter("roughness", 1.0)
				m.set_shader_parameter("metallic", 1.0 if src.metallic_texture != null else 0.0)
			if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				m.set_shader_parameter("alpha_cut", 0.5)
		for k in opts:
			if is_skin and (k == "tint" or k == "tint_amount" or k == "tex_albedo") and not opts.has("albedo"):
				continue
			m.set_shader_parameter(k, opts[k])
		mi.set_surface_override_material(s, m)
		mats.append(m)


func _hollow(c: Dictionary) -> void:
	# The Ashen are empty cloaks: a void inside the hood with two burning eyes.
	var head := skel.find_bone("Head")
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skel.add_child(att)
	var inv: Basis = skel.get_bone_global_rest(head).basis.inverse()
	var void_ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.105
	sm.height = 0.23
	void_ball.mesh = sm
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.01, 0.005, 0.02)
	vm.roughness = 1.0
	void_ball.material_override = vm
	att.add_child(void_ball)
	void_ball.position = inv * Vector3(0, 0.08, 0.0)
	void_ball.basis = inv
	var col: Color = c["hollow"]
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.017
		em.height = 0.022
		eye.mesh = em
		eye.material_override = FX.glow_mat(col, 4.5)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(eye)
		eye.position = inv * Vector3(sx * 0.036, 0.085, 0.092)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.5
	l.omni_range = 1.6
	att.add_child(l)
	l.position = inv * Vector3(0, 0.08, 0.25)
	if c.get("crown", false):
		l.light_energy = 2.5
		l.omni_range = 5.0
		var crown := FX.prop("crystal")
		att.add_child(crown)
		crown.basis = inv.scaled(Vector3.ONE * 0.11)
		crown.position = inv * Vector3(0, 0.2, -0.01)


func _anim(aname: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = aname
	return n


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 1.4
	loco.add_blend_point(_anim("Idle"), 0.0, -1, "idle")
	loco.add_blend_point(_anim("Jog_Fwd"), 0.6, -1, "jog")
	loco.add_blend_point(_anim("Sprint"), 1.1, -1, "sprint")
	loco.sync = true
	bt.add_node("loco", loco)
	_air = _anim("Jump")
	bt.add_node("air", _air)
	bt.add_node("airblend", AnimationNodeBlend2.new())
	bt.connect_node("airblend", 0, "loco")
	bt.connect_node("airblend", 1, "air")
	_act = _anim("Punch_Jab")
	bt.add_node("act", _act)
	bt.add_node("act_ts", AnimationNodeTimeScale.new())
	bt.connect_node("act_ts", 0, "act")
	_shot = AnimationNodeOneShot.new()
	_shot.fadein_time = 0.07
	_shot.fadeout_time = 0.2
	for b in UPPER:
		_shot.set_filter_path(NodePath("Armature/Skeleton3D:" + b), true)
	for b in skel.get_bone_count():
		var bn := skel.get_bone_name(b)
		if bn.begins_with("index") or bn.begins_with("middle") or bn.begins_with("pinky") or bn.begins_with("ring") or bn.begins_with("thumb"):
			_shot.set_filter_path(NodePath("Armature/Skeleton3D:" + bn), true)
	bt.add_node("shot", _shot)
	bt.connect_node("shot", 0, "airblend")
	bt.connect_node("shot", 1, "act_ts")
	var st := AnimationNodeTransition.new()
	st.xfade_time = 0.2
	st.add_input("alive")
	st.add_input("dead")
	bt.add_node("state", st)
	bt.add_node("die", _anim("Death01"))
	bt.connect_node("state", 0, "shot")
	bt.connect_node("state", 1, "die")
	bt.connect_node("output", 0, "state")
	tree = AnimationTree.new()
	tree.add_animation_library("", library())
	tree.tree_root = bt
	model.add_child(tree)
	tree.root_node = NodePath("..")
	tree.active = true
	tree.set("parameters/state/transition_request", "alive")


# ------------------------------------------------------------------ control
func play(a: String) -> void:
	if tree == null or _dead or not ACTIONS.has(a):
		return
	var busy: bool = tree.get("parameters/shot/active")
	if busy and (a == "strike" or a == "slam_down") and (action == "windup" or action == "slam_up"):
		return
	if busy and a == "hit" and action != "hit" and action != "channel":
		return
	if busy and a == "hit" and (action == "knockdown" or action == "getup"):
		return
	var e: Array = ACTIONS[a]
	var clip: Animation = library().get_animation(e[0])
	var offset: float = e[2]
	action = a
	_next = e[5]
	_cut = e[4]
	_act_t = 0.0
	_life = e[6] if e.size() > 6 else 0.0
	_dur = (clip.length - offset) / e[1] if clip.loop_mode == Animation.LOOP_NONE else 1e9
	_act.animation = e[0]
	# start part-way into the clip so the wind-up is skipped
	var custom := offset > 0.0 and clip.loop_mode == Animation.LOOP_NONE
	_act.use_custom_timeline = custom
	if custom:
		_act.stretch_time_scale = false
		_act.start_offset = offset
		_act.timeline_length = clip.length - offset
	var upper: bool = e[3] == "upper" or (e[3] == "auto" and (move > 0.25 or not grounded))
	_shot.filter_enabled = upper
	tree.set("parameters/act_ts/scale", e[1])
	tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func stop(a := "") -> void:
	if tree == null:
		return
	if a == "" or action == a:
		tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		action = ""
		_next = ""


func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	if tree:
		tree.active = on


func set_paused(on: bool) -> void:
	set_process(not on)
	if tree:
		tree.active = not on


func flash(amount := 1.0) -> void:
	_flash = amount


func set_dissolve(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("dissolve", v)


func set_frost(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("frost", v)


func hand(side: String) -> Vector3:
	var b := skel.find_bone("hand_l" if side == "L" else "hand_r")
	return skel.global_transform * skel.get_bone_global_pose(b).origin


func _process(dt: float) -> void:
	if tree == null:
		return
	var k := 1.0 - exp(-dt * 12.0)
	_blend = lerpf(_blend, clampf(move, 0.0, 1.3) * 1.1, k)
	_airb = lerpf(_airb, 0.0 if grounded else 1.0, 1.0 - exp(-dt * 14.0))
	tree.set("parameters/loco/blend_position", _blend)
	tree.set("parameters/airblend/blend_amount", _airb)
	if action != "":
		_act_t += dt
		# the tree needs a frame to register a new request, so only trust "inactive" after a moment
		if _next != "" and _act_t >= _dur - 0.07:
			play(_next)
		elif _act_t > 0.12 and not tree.get("parameters/shot/active"):
			action = ""
		elif _life > 0.0 and _act_t > _life:
			stop()
		elif _cut > 0.0 and _act_t > _cut and move > 0.3 and grounded:
			stop()
	model.rotation.y = spin
	if _flash > 0.0 or _flash_on:
		_flash = maxf(0.0, _flash - dt * 6.0)
		for m in mats:
			m.set_shader_parameter("flash", _flash)
		_flash_on = _flash > 0.0
