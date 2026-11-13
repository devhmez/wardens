class_name Breakable
extends StaticBody3D
# Static things that can be bent apart: training totems and corruption crystals.

signal broken(b)

var kind := "totem"
var hp := 30.0
var max_hp := 30.0
var dead := false
var hit_radius := 0.8
var show_bar := true
var height := 1.4
var model: Node3D
var mats: Array = []
var _flash := 0.0
var _wob := 0.0
var _light: OmniLight3D


func setup(k: String) -> void:
	kind = k
	collision_layer = Game.L_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	if k == "totem":
		hp = 30.0
		height = 1.4
		hit_radius = 0.85
		sh.radius = 0.36
		sh.height = 2.6
		model = FX.model("totem")
	else:
		hp = 95.0
		height = 1.5
		hit_radius = 1.4
		sh.radius = 1.0
		sh.height = 2.8
		model = FX.model("crystal")
		_light = OmniLight3D.new()
		_light.light_color = Color(0.7, 0.3, 1.0)
		_light.light_energy = 3.0
		_light.omni_range = 11.0
		_light.position = Vector3(0, 2.0, 0)
		add_child(_light)
		var fx := FX.particles({"amount": 18, "life": 1.6, "vmin": 0.3, "vmax": 1.2, "size": 0.5, "scurve": [1.0, 0.0], "add": true,
			"radius": 1.2, "gravity": Vector3(0, 1.5, 0), "colors": [Color(1.8, 0.7, 3.0, 1.0), Color(0.5, 0.1, 1.0, 0.0)]})
		fx.position = Vector3(0, 1.0, 0)
		add_child(fx)
	max_hp = hp
	cs.shape = sh
	cs.position = Vector3(0, sh.height * 0.5, 0)
	add_child(cs)
	add_child(model)
	mats = FX.toonify(model, 0.0, true)


func _ready() -> void:
	Game.register(self)


func aim_point() -> Vector3:
	return global_position + Vector3(0, height, 0)


func take_hit(amount: float, impulse: Vector3, element: String) -> void:
	if dead:
		return
	hp -= amount
	_flash = 1.0
	_wob = 1.0
	if amount >= 1.0:
		FX.number(aim_point() + Vector3(0, 0.8, 0), str(int(round(amount))), Game.EL_COLORS.get(element, Color.WHITE), amount >= 25.0)
	if amount >= 8.0:
		Game.sfx("hit", global_position, -5.0, 0.8)
		FX.sparks(aim_point(), Game.EL_COLORS.get(element, Color.WHITE), 8, 6.0)
	if hp <= 0.0:
		dead = true
		Game.unregister(self)
		collision_layer = 0
		broken.emit(self)
		if kind == "totem":
			FX.debris(aim_point(), 6, 7.0, 0.3)
			FX.dust(global_position + Vector3(0, 1, 0), 1.4, 16)
			Game.sfx("rock_hit", global_position, -2.0, 1.3)
		else:
			FX.wisps(aim_point(), Game.EL_COLORS["dark"], 2.0, 50)
			FX.sparks(aim_point(), Game.EL_COLORS["dark"], 40, 14.0)
			FX.flash(aim_point(), Color(0.8, 0.4, 1.0), 14.0, 20.0, 0.6)
			FX.ring(global_position, Color(0.8, 0.4, 1.0, 1.0), 1.0, 9.0, 0.5, 0.25)
			Game.sfx("shatter", global_position, 2.0)
			Game.shake(0.6, global_position)
			Game.hitstop(0.06)
		queue_free()


func _process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 6.0)
		for m in mats:
			m.set_shader_parameter("flash", _flash * 0.8)
	if _wob > 0.0:
		_wob = maxf(0.0, _wob - dt * 3.0)
		model.rotation.x = sin(_wob * 22.0) * 0.12 * _wob
		model.rotation.z = cos(_wob * 19.0) * 0.1 * _wob
	if _light:
		_light.light_energy = 3.0 + sin(Time.get_ticks_msec() * 0.004) * 0.8
