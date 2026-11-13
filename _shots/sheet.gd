extends SceneTree
# Contact sheets: each row is one animation clip sampled at 10 evenly spaced times.

const CLIPS := [
	["UAL1", "Punch_Jab"], ["UAL1", "Punch_Cross"], ["UAL2", "Melee_Hook"], ["UAL2", "Melee_Hook_Rec"], ["UAL2", "OverhandThrow"],
	["UAL1", "Spell_Simple_Enter"], ["UAL1", "Spell_Simple_Idle"], ["UAL1", "Spell_Simple_Shoot"], ["UAL1", "Spell_Simple_Exit"], ["UAL2", "Idle_Shield_Break"],
	["UAL1", "Sword_Attack"], ["UAL2", "Sword_Regular_A"], ["UAL2", "Sword_Regular_A_Rec"], ["UAL2", "Sword_Regular_B"], ["UAL2", "Sword_Regular_B_Rec"],
	["UAL2", "Sword_Regular_C"], ["UAL2", "Sword_Regular_Combo"], ["UAL2", "Sword_Heavy_Combo"], ["UAL2", "Sword_Dash"], ["UAL2", "Shield_Dash"],
	["UAL2", "Shield_OneShot"], ["UAL2", "Sword_Block"], ["UAL1", "Sword_Idle"], ["UAL2", "Zombie_Scratch"], ["UAL2", "Chest_Open"],
	["UAL1", "Roll"], ["UAL1", "Jump_Start"], ["UAL1", "Jump"], ["UAL1", "Jump_Land"], ["UAL2", "NinjaJump_Start"],
	["UAL2", "NinjaJump_Idle"], ["UAL2", "NinjaJump_Land"], ["UAL2", "Slide_Start"], ["UAL2", "Slide"], ["UAL2", "Slide_Exit"],
	["UAL1", "Hit_Chest"], ["UAL1", "Hit_Head"], ["UAL2", "Hit_Knockback"], ["UAL1", "Death01"], ["UAL1", "Push"],
	["UAL1", "PickUp_Table"], ["UAL1", "Interact"], ["UAL2", "Consume"], ["UAL1", "Crouch_Idle"], ["UAL2", "Idle_Shield"],
]
const ROWS := 5
const COLS := 10

var root3: Node3D
var cells: Array = []
var sheet := 0
var frame := 0
var scenes := {}


func _initialize() -> void:
	root3 = Node3D.new()
	get_root().add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.4
	root3.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ROWS * 2.25
	root3.add_child(cam)
	# three-quarter view from the character's front-right
	var dir := Vector3(sin(0.7), 0.18, cos(0.7)).normalized()
	var mid := Vector3(0, ROWS * 2.25 * 0.5 - 0.15, 0)
	cam.look_at_from_position(mid + dir * 40.0, mid)
	cam.make_current()
	_build()


func _build() -> void:
	for c in cells:
		c.queue_free()
	cells.clear()
	var view_right := Vector3(cos(0.7), 0, -sin(0.7))
	for r in ROWS:
		var i := sheet * ROWS + r
		if i >= CLIPS.size():
			break
		var lib: String = CLIPS[i][0]
		var clip: String = CLIPS[i][1]
		if not scenes.has(lib):
			scenes[lib] = load("res://assets/chars/%s.glb" % lib)
		var y := (ROWS - 1 - r) * 2.25
		var length := 1.0
		for cidx in COLS:
			var n: Node3D = scenes[lib].instantiate()
			root3.add_child(n)
			n.position = view_right * ((cidx - (COLS - 1) * 0.5) * 1.9 + 0.5) + Vector3(0, y, 0)
			var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
			length = ap.get_animation(clip).length
			var t := length * cidx / float(COLS - 1)
			ap.play(clip)
			ap.seek(minf(t, length - 0.001), true)
			ap.speed_scale = 0.0
			cells.append(n)
			var lt := Label3D.new()
			lt.text = "%.2f" % t
			lt.font_size = 40
			lt.pixel_size = 0.005
			lt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lt.no_depth_test = true
			lt.modulate = Color(0.75, 0.8, 0.9)
			root3.add_child(lt)
			lt.position = n.position + Vector3(0, 2.02, 0)
			cells.append(lt)
		var l := Label3D.new()
		l.text = "%s  (%.2fs)" % [clip, length]
		l.font_size = 64
		l.pixel_size = 0.005
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = Color(1.0, 0.85, 0.4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		root3.add_child(l)
		l.position = view_right * (-(COLS - 1) * 0.5 * 1.9 - 0.9) + Vector3(0, y + 0.25, 0)
		cells.append(l)
	frame = 0


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 12:
		var img := get_root().get_texture().get_image()
		img.resize(1700, int(1700.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://_shots/sheets/sheet_%02d.png" % sheet))
		sheet += 1
		if sheet * ROWS >= CLIPS.size():
			return true
		_build()
	return false
