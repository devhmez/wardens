extends Node
# Self-test: run with `godot --path . -- --shots`. Plays through every move and saves screenshots to _shots/.

var pl
var cam
var dir := ""
var fps: Array = []
var _max_dt := 0.0
var _slow := 0
var _frames := 0


func _process(dt: float) -> void:
	var real := dt / maxf(Engine.time_scale, 0.001)
	_max_dt = maxf(_max_dt, real)
	_frames += 1
	if real > 0.03:
		_slow += 1


func _ready() -> void:
	dir = ProjectSettings.globalize_path("res://_shots")
	DirAccess.make_dir_recursive_absolute(dir)
	pl = Game.player
	cam = Game.cam
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if "--moves" in OS.get_cmdline_user_args():
		_moves()
	elif "--lineup" in OS.get_cmdline_user_args():
		_lineup()
	elif "--bench" in OS.get_cmdline_user_args():
		_bench()
	elif "--story" in OS.get_cmdline_user_args():
		_story()
	else:
		_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w := 1500
	img.resize(w, int(w * float(img.get_height()) / img.get_width()), Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/%s.png" % [dir, shot_name])
	fps.append(Engine.get_frames_per_second())
	var rid := get_viewport().get_viewport_rid()
	print("shot ", shot_name, " fps=", Engine.get_frames_per_second(), " gpu_ms=", snappedf(RenderingServer.viewport_get_measured_render_time_gpu(rid), 0.1),
		" cpu_ms=", snappedf(RenderingServer.viewport_get_measured_render_time_cpu(rid), 0.1),
		" worst_frame_ms=", int(_max_dt * 1000.0), " slow_frames=", _slow, "/", _frames)
	_max_dt = 0.0
	_slow = 0
	_frames = 0


func look(at: Vector3, pitch := -0.2) -> void:
	var d: Vector3 = at - pl.global_position
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = pitch
	cam.snap()


func _enemy(kind: String, pos: Vector3) -> Enemy:
	var e: Enemy = Game.missions.spawn(kind, pos, true)
	e.aggro = 0.0
	e.alerted = false
	return e


func _run() -> void:
	var world = Game.world
	Game.hud.title_mode = true
	cam.orbit = true
	cam.orbit_center = pl.global_position
	await wait(2.5)
	await shot("00_title")
	Game.hud.title_mode = false
	cam.orbit = false
	Game.input_enabled = false
	Game.missions.hud = Game.hud
	Game.missions.world = world
	Game.missions.pl = pl
	Game.hud.set_objective("First Light", "Break the training totems   2 / 6\nBend with every Warden   1 / 4")

	# --- shrine: one arena per element
	var sh: Vector3 = world.ground(World.SHRINE.x, World.SHRINE.y, 1.0)
	pl.global_position = sh + Vector3(-4, 0, 0)
	var front := sh + Vector3(7, 0, 0)
	look(front)
	await wait(0.6)
	await shot("01_shrine_idle")
	var names := ["earth", "fire", "water", "air"]
	for i in 4:
		pl.set_element(i)
		pl.chi = 100.0
		var foes: Array = []
		for k in 3:
			foes.append(_enemy("grunt", front + Vector3(k * 1.2, 0, (k - 1) * 3.0)))
		await wait(0.5)
		look(front, -0.16)
		pl.bender.light()
		await wait(0.33)
		await shot("1%d_%s_light_a" % [i, names[i]])
		pl.bender.cd_light = 0.0
		pl.bender.light()
		await wait(0.16)
		await shot("1%d_%s_light_b" % [i, names[i]])
		await wait(0.6)
		pl.chi = 100.0
		pl.bender.heavy_start()
		if i == 1:
			for f in 40:
				pl.bender.heavy_hold(1.0 / 60.0)
				await get_tree().physics_frame
			await shot("1%d_%s_heavy" % [i, names[i]])
			pl.bender.heavy_end()
		else:
			await wait(0.55 if i != 3 else 1.6)
			await shot("1%d_%s_heavy" % [i, names[i]])
		await wait(0.9)
		pl.chi = 100.0
		pl.bender.cd_special = 0.0
		look(front, -0.16)
		pl.bender.special()
		await wait(0.42)
		await shot("1%d_%s_special" % [i, names[i]])
		await wait(2.0 if i != 3 else 3.2)
		pl.chi = 100.0
		look(front, -0.16)
		pl.bender.quick()
		await wait([1.15, 0.2, 0.3, 0.6][i])
		await shot("1%d_%s_quick" % [i, names[i]])
		await wait(1.6)
		pl.global_position = sh + Vector3(-4, 0, 0)
		pl.chi = 100.0
		look(front, -0.2)
		pl.bender.ultimate()
		await wait([1.05, 1.2, 0.9, 0.8][i])
		await shot("1%d_%s_ult" % [i, names[i]])
		await wait(2.2)
		for e in foes:
			if is_instance_valid(e) and not e.dead:
				e.die()
		await wait(1.6)

	# --- running across the meadow toward the village
	pl.set_element(0)
	world.apply_mood(World.MOODS["day"])
	pl.global_position = world.ground(-20.0, 50.0, 1.0)
	look(world.ground(30.0, 40.0), -0.12)
	pl.auto_move = Vector2(0, -1)
	await wait(0.9)
	await shot("20_run_meadow")
	pl.auto_move = Vector2.ZERO

	# --- village at sunset with a fight
	world.apply_mood(World.MOODS["sunset"])
	pl.global_position = world.ground(World.VILLAGE.x - 6.0, World.VILLAGE.y + 2.0, 1.0)
	var vfront: Vector3 = world.ground(World.VILLAGE.x + 6.0, World.VILLAGE.y - 2.0, 1.0)
	look(vfront, -0.14)
	_enemy("brute", vfront)
	_enemy("grunt", vfront + Vector3(2, 0, 4))
	_enemy("caster", vfront + Vector3(3, 0, -4))
	pl.set_element(2)
	await wait(1.0)
	pl.bender.light()
	await wait(0.2)
	await shot("21_village_sunset")
	await wait(0.5)
	pl.global_position = world.dock_pos + Vector3(0, 1.0, 0)
	look(world.ground(World.LAKE.x, World.LAKE.y), -0.18)
	await wait(0.6)
	await shot("22_lake")
	for e in Game.targets.duplicate():
		if e is Enemy:
			e.die()

	# --- fort at dusk with the boss
	world.apply_mood(World.MOODS["dusk"])
	var fc: Vector3 = world.ground(World.FORT.x, World.FORT.y, 1.0)
	pl.global_position = fc + Vector3(0, 0, 13)
	look(fc, -0.1)
	var c := Breakable.new()
	c.setup("crystal")
	Game.main.add_child(c)
	c.global_position = world.ground(World.FORT.x - 7.0, World.FORT.y - 2.0, -0.1)
	var boss := _enemy("king", fc)
	Game.hud.boss = boss
	Game.hud.boss_name = "VARRIK,  THE HOLLOW KING"
	Game.hud.set_objective("The Hollow Gate", "Defeat Varrik, the Hollow King")
	pl.set_element(1)
	await wait(1.2)
	pl.bender.light()
	await wait(0.25)
	await shot("30_fort_boss")
	Game.hud.banner("VARRIK", "The Hollow King")
	await wait(1.0)
	await shot("31_banner")
	# gate view from outside
	pl.global_position = world.ground(World.FORT.x, World.FORT.y + 40.0, 1.0)
	look(fc, -0.05)
	await wait(0.6)
	await shot("32_gate")
	print("FPS samples: ", fps)
	get_tree().quit()


# ------------------------------------------------------------------ full story run-through
func _wait_for(cond: Callable, timeout: float, label: String) -> bool:
	var t := 0.0
	while not cond.call():
		await wait(0.2)
		t += 0.2
		Game.hud._skip = true
		if t > timeout:
			print("STORY TIMEOUT: ", label)
			return false
	print("STORY OK: ", label)
	return true


func _kill_all() -> void:
	for e in Game.targets.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_hit(9999.0, Vector3.ZERO, "earth")


func _story() -> void:
	var world = Game.world
	var ms = Game.missions
	await wait(1.5)
	Game.main._start(0)
	await _wait_for(func(): return Game.targets.size() >= 6, 25.0, "m1 totems spawned")
	look(world.ground(World.SHRINE.x + 6.0, World.SHRINE.y), -0.25)
	await wait(0.5)
	await shot("40_m1_totems")
	for i in 4:
		pl.set_element(i)
		pl.bender.light()
		await wait(0.6)
	_kill_all()
	await _wait_for(func(): return ms.index == 1, 30.0, "m1 complete")
	await wait(1.0)
	await shot("41_m2_banner")
	pl.global_position = world.ground(World.VILLAGE.x - 10.0, World.VILLAGE.y, 1.0)
	look(world.ground(World.VILLAGE.x, World.VILLAGE.y), -0.15)
	await _wait_for(func(): return ms._alive() >= 4, 15.0, "m2 wave 1 spawned")
	Game.autopilot = false      # let enemies actually hit the player for a moment
	await wait(2.5)
	await shot("42_m2_wave")
	Game.autopilot = true
	print("player hp after 2.5s of wave 1: ", pl.hp)
	pl.hp = 100.0
	var t := 0.0
	while ms.index < 2 and t < 60.0:
		_kill_all()
		Game.hud._skip = true
		await wait(0.4)
		t += 0.4
	print("STORY OK: m2 complete" if ms.index == 2 else "STORY TIMEOUT: m2")
	pl.global_position = world.ground(World.FORT.x, World.FORT.y + 30.0, 1.0)
	look(world.ground(World.FORT.x, World.FORT.y), -0.1)
	await wait(1.5)
	await shot("43_m3_fort")
	t = 0.0
	while Game.hud.boss == null and t < 30.0:
		_kill_all()
		await wait(0.4)
		t += 0.4
	print("STORY OK: boss spawned" if Game.hud.boss != null else "STORY TIMEOUT: boss")
	pl.global_position = world.ground(World.FORT.x, World.FORT.y + 14.0, 1.0)
	look(world.ground(World.FORT.x, World.FORT.y), -0.08)
	await wait(2.5)
	await shot("44_m3_boss")
	var boss = Game.hud.boss
	boss.take_hit(boss.hp * 0.4, Vector3.ZERO, "fire")
	await wait(1.0)
	print("summoned grunts alive: ", ms._alive() - 1)
	_kill_all()
	await _wait_for(func(): return ms.index == 3, 30.0, "m3 complete")
	await wait(1.5)
	await shot("45_finale")
	print("save index: ", Missions.load_index())
	get_tree().quit()


# ------------------------------------------------------------------ performance probe
func _measure(label: String) -> void:
	await wait(1.2)
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	await wait(2.0)
	var dt := (Time.get_ticks_usec() - t0) / 1000000.0
	print("BENCH %-28s %5.1f fps" % [label, (Engine.get_frames_drawn() - f0) / dt])


func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var world = Game.world
	var env: Environment = world.env
	Game.hud.title_mode = false
	if "--fort" in OS.get_cmdline_user_args():
		world.apply_mood(World.MOODS["dusk"])
		var fc: Vector3 = world.ground(World.FORT.x, World.FORT.y, 1.0)
		pl.global_position = fc + Vector3(0, 0, 13)
		look(fc, -0.1)
		_enemy("king", fc)
		await wait(3.0)
		await shot("90_fort_check")
		get_tree().quit()
		return
	world.apply_mood(World.MOODS["day"])
	pl.global_position = world.ground(-20.0, 50.0, 1.0)
	look(world.ground(30.0, 40.0), -0.12)
	await wait(2.0)
	await _measure("default settings")
	env.sdfgi_enabled = true
	await _measure("+ bounced lighting (F10)")
	if "--quick" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	env.sdfgi_enabled = false
	await _measure("- sdfgi")
	env.volumetric_fog_enabled = false
	await _measure("- volumetric fog")
	env.ssao_enabled = false
	await _measure("- ssao")
	var grass: Array = world.find_children("*", "MultiMeshInstance3D", true, false)
	for g in grass:
		g.visible = false
	await _measure("- grass")
	env.sky.process_mode = Sky.PROCESS_MODE_QUALITY
	await _measure("- realtime sky")
	env.glow_enabled = false
	await _measure("- glow")
	world.sun.shadow_enabled = false
	await _measure("- sun shadows")
	get_viewport().scaling_3d_scale = 0.5
	await _measure("- scale 0.5")
	get_tree().quit()


# ------------------------------------------------------------------ asset preview
func _lineup() -> void:
	var world = Game.world
	Game.hud.visible = false
	world.apply_mood(World.MOODS["day"])
	var sh: Vector3 = world.ground(World.SHRINE.x, World.SHRINE.y, 0.3)
	pl.global_position = sh + Vector3(0, 0, 40)
	var names := ["warden_earth", "warden_fire", "warden_water", "warden_air", "ashen_grunt", "ashen_caster", "ashen_brute", "ashen_king"]
	var acts := ["", "punchR", "sweepR", "lift", "windup", "cast", "", ""]
	for i in names.size():
		var pu := Puppet.new()
		Game.main.add_child(pu)
		pu.setup(names[i])
		pu.global_position = sh + Vector3((i - 3.5) * 1.25, 0, 0)
		if acts[i] != "":
			_later(pu, acts[i])
	cam.orbit = true
	cam.orbit_center = sh + Vector3(0, -1.0, 0)
	cam.orbit_radius = 6.0
	cam.orbit_height = 1.3
	cam._t = PI * 0.5 / 0.12
	await wait(2.0)
	await shot("80_lineup_front")
	cam.orbit_radius = 3.2
	cam.orbit_center = sh + Vector3(-1.2, -0.75, 0)
	await wait(0.3)
	await shot("81_lineup_close_wardens")
	cam.orbit_center = sh + Vector3(2.6, -0.75, 0)
	await wait(0.3)
	await shot("82_lineup_close_ashen")
	get_tree().quit()


func _later(pu: Puppet, act: String, delay := 1.75) -> void:
	await wait(delay)
	if is_instance_valid(pu):
		pu.play(act)


# ------------------------------------------------------------------ move sheets
# For every move, replays it once per sample time and photographs the character from the side,
# then tiles the crops into one sheet per Warden (rows = moves, columns = moments).
const MOVE_TIMES := [0.07, 0.17, 0.3, 0.5, 0.85]
var _side_cam: Camera3D


func _real_wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame


func _crop(center: Vector3) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var vis := get_viewport().get_visible_rect().size
	var k := img.get_width() / vis.x
	var c := _side_cam.unproject_position(center) * k
	var w := int(img.get_width() * 0.36)
	var h := int(w * 0.8)
	var r := Rect2i(int(c.x - w * 0.4), int(c.y - h * 0.55), w, h)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var out := img.get_region(r)
	out.resize(340, 272, Image.INTERPOLATE_BILINEAR)
	return out


func _moves() -> void:
	var world = Game.world
	Game.hud.visible = false
	Game.input_enabled = false
	Game.missions.hud = Game.hud
	Game.missions.world = world
	Game.missions.pl = pl
	world.apply_mood(World.MOODS["day"])
	var sh: Vector3 = world.ground(World.SHRINE.x, World.SHRINE.y, 0.3)
	var home := sh + Vector3(-3, 0.3, 0)
	var front := sh + Vector3(5.5, 0, 0)
	_side_cam = Camera3D.new()
	_side_cam.fov = 50.0
	Game.main.add_child(_side_cam)
	_side_cam.look_at_from_position(home + Vector3(2.6, 1.7, 7.5), home + Vector3(2.6, 1.0, 0))
	_side_cam.make_current()
	await wait(1.5)
	var names := ["earth", "fire", "water", "air"]
	for el in 4:
		var sheet := Image.create(340 * MOVE_TIMES.size(), 272 * 5, false, Image.FORMAT_RGB8)
		for mv in 5:
			for ti in MOVE_TIMES.size():
				for e in Game.targets.duplicate():
					if e is Enemy:
						e.queue_free()
						Game.unregister(e)
				_enemy("grunt", front)
				_enemy("grunt", front + Vector3(1.5, 0, 1.6))
				pl.global_position = home
				pl.velocity = Vector3.ZERO
				pl.set_element(el)
				pl.chi = 100.0
				var b = pl.bender
				b.cd_light = 0.0
				b.cd_heavy = 0.0
				b.cd_special = 0.0
				b.cd_q = 0.0
				b.cd_ult = 0.0
				look(front, -0.12)
				await wait(0.45)
				Engine.time_scale = 1.0
				match mv:
					0:
						b.light()
					1:
						b.heavy_start()
					2:
						b.special()
					3:
						b.quick()
					4:
						b.ultimate()
				var t0 := Time.get_ticks_msec()
				while (Time.get_ticks_msec() - t0) / 1000.0 < MOVE_TIMES[ti]:
					if mv == 1 and el == 1:
						b.heavy_hold(1.0 / 60.0)
					await get_tree().process_frame
				var img: Image = await _crop(pl.global_position + Vector3(0, 1.0, 0))
				sheet.blit_rect(img, Rect2i(0, 0, 340, 272), Vector2i(ti * 340, mv * 272))
				if mv == 1 and el == 1:
					b.heavy_end()
				await _real_wait(0.9 if mv < 4 else 2.2)
		sheet.save_png("%s/moves_%s.png" % [dir, names[el]])
		print("saved moves_", names[el])
	# moving: punch / whip / stone shot while running, then dash roll and jump
	var ms := Image.create(340 * 5, 272 * 5, false, Image.FORMAT_RGB8)
	var run_rows := [[1, "light"], [2, "light"], [0, "light"], [0, "roll"], [0, "jump"]]
	for r in run_rows.size():
		for ti in 5:
			pl.global_position = home + Vector3(-2.5, 0, 0)
			pl.velocity = Vector3.ZERO
			pl.set_element(run_rows[r][0])
			pl.bender.cd_light = 0.0
			look(front, -0.12)
			pl.auto_move = Vector2(0, -1)
			await wait(0.35)
			match run_rows[r][1]:
				"light":
					pl.bender.light()
				"roll":
					pl.dash_dir = Vector3(1, 0, 0)
					pl.dash_speed = 22.0
					pl.dash_t = 0.2
					pl.puppet.play("roll")
				"jump":
					pl.velocity.y = 11.2
					pl.coyote = 0.0
			await _real_wait(MOVE_TIMES[ti])
			var img3: Image = await _crop(pl.global_position + Vector3(0, 1.0, 0))
			ms.blit_rect(img3, Rect2i(0, 0, 340, 272), Vector2i(ti * 340, r * 272))
			pl.auto_move = Vector2.ZERO
			await _real_wait(0.7)
	ms.save_png("%s/moves_moving.png" % dir)
	# enemies: attack, cast, slam, knockdown, death
	var acts := [["grunt", "windup", [0.15, 0.35, 0.5, 0.7, 1.0]], ["caster", "cast", [0.2, 0.5, 0.65, 0.8, 1.0]],
		["brute", "slam_up", [0.3, 0.6, 0.9, 1.1, 1.5]], ["grunt", "knockdown", [0.1, 0.4, 0.8, 1.3, 1.9]], ["grunt", "die", [0.2, 0.6, 1.0, 1.4, 1.8]]]
	var es := Image.create(340 * 5, 272 * 5, false, Image.FORMAT_RGB8)
	pl.global_position = home + Vector3(-30, 0, 0)
	for r in acts.size():
		for ti in 5:
			for e in Game.targets.duplicate():
				if e is Enemy:
					e.queue_free()
					Game.unregister(e)
			var en := _enemy(acts[r][0], home + Vector3(2.0, 0, 0))
			en.yaw = PI * 0.5
			en.set_physics_process(false)
			en.puppet.rotation.y = PI * 0.5
			await wait(0.5)
			if acts[r][1] == "die":
				en.die()
			else:
				en.puppet.play(acts[r][1])
				if acts[r][1] == "cast":
					_later(en.puppet, "shoot", 0.6)
			await _real_wait(acts[r][2][ti])
			var img2: Image = await _crop(en.global_position + Vector3(0.6, 1.0, 0))
			es.blit_rect(img2, Rect2i(0, 0, 340, 272), Vector2i(ti * 340, r * 272))
			await _real_wait(0.3)
	es.save_png("%s/moves_enemies.png" % dir)
	get_tree().quit()
