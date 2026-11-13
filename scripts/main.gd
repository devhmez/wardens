extends Node3D
# Entry point: builds the world, the Wardens, the camera and the interface.

var world: World
var player: Player
var cam: CameraRig
var hud: HUD
var missions: Missions
var started := false


func _ready() -> void:
	Game.main = self
	world = World.new()
	Game.world = world
	add_child(world)
	cam = CameraRig.new()
	Game.cam = cam
	add_child(cam)
	player = Player.new()
	Game.player = player
	add_child(player)
	player.global_position = world.ground(World.SHRINE.x, World.SHRINE.y, 1.0)
	player.yaw = PI * 0.5
	cam.target = player
	cam.snap()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	Game.hud = hud
	layer.add_child(hud)
	hud.bind(player)
	missions = Missions.new()
	Game.missions = missions
	add_child(missions)
	FX.prewarm.call_deferred(player.global_position)
	if Game.autopilot:
		var ap := Node.new()
		ap.set_script(load("res://scripts/autopilot.gd"))
		add_child(ap)
		return
	hud.title_mode = true
	hud.has_save = Missions.load_index() > 0
	cam.orbit = true
	cam.orbit_center = player.global_position
	cam.orbit_radius = 15.0
	cam.orbit_height = 5.5
	Game.loop("music", true, -13.0)
	Game.loop("ambience", true, -16.0)


func _unhandled_input(e: InputEvent) -> void:
	if Game.autopilot:
		return
	if not started:
		if e.is_action_pressed("interact"):
			_start(maxi(Missions.load_index(), 0))
		elif e.is_action_pressed("new_game"):
			_start(0)
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _start(from: int) -> void:
	started = true
	Game.started = true
	Game.sfx("gong", null, -3.0, 1.0, 0.0)
	await hud.fade_to(1.0, 0.5)
	hud.title_mode = false
	cam.orbit = false
	missions.begin(from)
	if not Game.autopilot:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.input_enabled = true
	await hud.fade_to(0.0, 0.9)
