class_name HUD
extends Control
# All 2D interface, drawn by hand: bars, element wheel, objectives, dialog, title and pause screens.

const EL_NAMES := ["Earth", "Fire", "Water", "Air"]

var font: SystemFont
var font_title: SystemFont
var title_mode := false
var has_save := false
var paused := false
var fade := 0.0
var mission := ""
var objective := ""
var hint := ""
var marker = null
var boss = null
var boss_name := ""
var _banner := ""
var _banner_sub := ""
var _banner_t := 99.0
var _banner_dur := 3.5
var _speaker := ""
var _line := ""
var _dialog_t := 0.0
var _dialog_dur := 0.0
var _skip := false
var _toast := ""
var _toast_t := 0.0
var _chi_pulse := 0.0
var _t := 0.0
var _el_pop := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Segoe UI", "Arial"])
	font.font_weight = 700
	font_title = SystemFont.new()
	font_title.font_names = PackedStringArray(["Avenir Next Condensed", "Avenir Next", "Impact", "Arial"])
	font_title.font_weight = 800


func bind(pl) -> void:
	pl.chi_denied.connect(func():
		_chi_pulse = 1.0
		toast("Not enough chi"))
	pl.element_changed.connect(func(_i): _el_pop = 1.0)


# ------------------------------------------------------------------ API
func banner(title: String, sub := "", dur := 3.8) -> void:
	_banner = title
	_banner_sub = sub
	_banner_t = 0.0
	_banner_dur = dur
	Game.sfx("gong", null, -4.0, 1.0, 0.0)


func toast(text: String) -> void:
	_toast = text
	_toast_t = 1.6


func set_objective(m: String, text: String) -> void:
	if text != objective and text != "":
		Game.sfx("tick", null, -14.0, 1.0, 0.0)
	mission = m
	objective = text


func say(speaker: String, line: String) -> void:
	_speaker = speaker
	_line = line
	_dialog_t = 0.0
	_dialog_dur = 2.2 + line.length() * 0.055
	_skip = false
	Game.sfx("tick", null, -10.0, 0.7, 0.0)
	while _dialog_t < _dialog_dur and not _skip:
		await get_tree().process_frame
	_line = ""
	await get_tree().create_timer(0.25).timeout


func fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "fade", a, dur)
	await tw.finished


func _unhandled_input(e: InputEvent) -> void:
	if _line != "" and e.is_action_pressed("interact") and _dialog_t > 0.3:
		_skip = true


func _process(dt: float) -> void:
	_t += dt
	_banner_t += dt
	if not get_tree().paused:
		_dialog_t += dt
	_toast_t = maxf(0.0, _toast_t - dt)
	_chi_pulse = maxf(0.0, _chi_pulse - dt * 2.5)
	_el_pop = maxf(0.0, _el_pop - dt * 3.0)
	queue_redraw()


# ------------------------------------------------------------------ drawing helpers
func _text(pos: Vector2, s: String, px: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6, f: Font = null) -> void:
	if f == null:
		f = font
	if outline > 0:
		draw_string_outline(f, pos, s, align, width, px, outline, Color(0.04, 0.03, 0.08, col.a * 0.85))
	draw_string(f, pos, s, align, width, px, col)


func _bar(r: Rect2, frac: float, col: Color, back := Color(0.05, 0.04, 0.1, 0.7)) -> void:
	draw_rect(r.grow(3.0), Color(0.03, 0.02, 0.06, 0.85))
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y * 0.4)), Color(1, 1, 1, 0.18))


func _icon(el: int, c: Vector2, r: float, col: Color) -> void:
	match el:
		0:
			var pts := PackedVector2Array()
			for i in 6:
				var a := i * TAU / 6.0 + 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * r * (0.9 if i % 2 == 0 else 0.72))
			draw_colored_polygon(pts, col)
		1:
			var pts2 := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.42, -r * 0.2), c + Vector2(r * 0.68, r * 0.35),
				c + Vector2(r * 0.4, r * 0.82), c + Vector2(0, r * 0.95), c + Vector2(-r * 0.4, r * 0.82),
				c + Vector2(-r * 0.68, r * 0.35), c + Vector2(-r * 0.3, -r * 0.05), c + Vector2(-r * 0.25, -r * 0.5)])
			draw_colored_polygon(pts2, col)
		2:
			var pts3 := PackedVector2Array([c + Vector2(0, -r)])
			for i in 13:
				var a2 := -0.35 + i * (PI + 0.7) / 12.0
				pts3.append(c + Vector2(0, r * 0.28) + Vector2(cos(a2), sin(a2)) * r * 0.66)
			draw_colored_polygon(pts3, col)
		3:
			for i in 3:
				draw_arc(c + Vector2(-r * 0.1, (i - 1) * r * 0.5), r * (0.65 - i * 0.08), -1.9 + i * 0.3, 1.2 + i * 0.25, 14, col, r * 0.17, true)


# ------------------------------------------------------------------ main draw
func _draw() -> void:
	var s := size
	if title_mode:
		_draw_title(s)
	elif Game.player != null:
		_draw_game(s)
	if paused:
		_draw_pause(s)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.04, fade))


func _draw_title(s: Vector2) -> void:
	var steps := 60
	for i in steps:
		var k := float(i) / steps
		var hb := s.y * 0.45 / steps
		draw_rect(Rect2(0, s.y * 0.55 + i * hb, s.x, hb), Color(0.02, 0.02, 0.08, k * 0.8))
		var ht := s.y * 0.3 / steps
		draw_rect(Rect2(0, i * ht, s.x, ht), Color(0.02, 0.02, 0.08, (1.0 - k) * 0.45))
	var cx := s.x * 0.5
	_text(Vector2(0, s.y * 0.3), "W A R D E N S", 150, Color(1.0, 0.96, 0.86), HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, font_title)
	_text(Vector2(0, s.y * 0.3 + 52), "THE  FOUR  CURRENTS", 30, Color(0.96, 0.8, 0.45), HORIZONTAL_ALIGNMENT_CENTER, s.x, 8)
	for i in 4:
		var c := Vector2(cx + (i - 1.5) * 84.0, s.y * 0.3 + 120.0)
		var col: Color = Game.EL_COLORS[Player.ELEMENTS[i]]
		draw_circle(c, 28.0, Color(0.04, 0.03, 0.09, 0.8))
		draw_arc(c, 28.0, 0, TAU, 40, col, 3.0, true)
		_icon(i, c, 15.0, col)
	var blink := 0.55 + 0.45 * sin(_t * 3.0)
	var start := "Press  ENTER  to continue the journey" if has_save else "Press  ENTER  to begin"
	_text(Vector2(0, s.y * 0.8), start, 32, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, s.x, 8)
	if has_save:
		_text(Vector2(0, s.y * 0.8 + 40), "N  -  start a new journey", 20, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER, s.x, 6)
	_text(Vector2(0, s.y - 34), "%s move   -   Mouse aim   -   LMB / RMB / %s / Q bend   -   R ultimate   -   1 2 3 4 change Warden   -   F11 fullscreen" % [Game.move_keys(), Game.key_label("special")],
		18, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, s.x, 5)


func _draw_game(s: Vector2) -> void:
	var pl = Game.player
	var el: int = pl.el
	var el_name: String = Player.ELEMENTS[el]
	var col: Color = Game.EL_COLORS[el_name]
	var cam: Camera3D = Game.cam.cam
	# damage vignette
	if pl.hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.85, 0.05, 0.12, pl.hurt_flash * 0.28))
	if pl.hp < 30.0 and not pl.dead:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.7, 0.0, 0.1, 0.07 + 0.05 * sin(_t * 5.0)))

	# enemy health bars
	for t in Game.targets:
		if not is_instance_valid(t) or t.dead or not t.show_bar or t == boss or t.hp >= t.max_hp:
			continue
		var wp: Vector3 = t.aim_point() + Vector3(0, 1.1 * t.hit_radius / 0.75 + 0.3, 0)
		if cam.is_position_behind(wp) or cam.global_position.distance_to(wp) > 45.0:
			continue
		var sp := cam.unproject_position(wp)
		var w := 70.0 if t.max_hp < 100.0 else 110.0
		_bar(Rect2(sp.x - w * 0.5, sp.y, w, 7.0), t.hp / t.max_hp, Color(0.8, 0.4, 1.0))

	# reticle
	if not pl.dead and Game.input_enabled:
		var c := s * 0.5
		var a: Dictionary = pl.aim()
		if a["target"] != null and not cam.is_position_behind(a["point"]):
			var tp := cam.unproject_position(a["point"])
			var rr := 26.0 + 3.0 * sin(_t * 8.0)
			for i in 4:
				var ang := i * PI * 0.5 + _t * 1.2
				draw_arc(tp, rr, ang, ang + 0.9, 8, Color(col.r, col.g, col.b, 0.95), 3.5, true)
			draw_circle(tp, 3.0, Color(1, 1, 1, 0.9))
		draw_arc(c, 9.0, 0, TAU, 24, Color(1, 1, 1, 0.55), 2.0, true)
		draw_circle(c, 2.0, Color(1, 1, 1, 0.8))

	# objective marker
	if marker != null:
		var mp: Vector3 = marker
		var d: float = pl.global_position.distance_to(mp)
		var sp2 := cam.unproject_position(mp + Vector3(0, 3, 0))
		if cam.is_position_behind(mp):
			sp2 = Vector2(s.x - sp2.x, s.y * 1.5)
		sp2 = sp2.clamp(Vector2(60, 90), s - Vector2(60, 220))
		var mcol := Color(1.0, 0.85, 0.4, 0.95)
		var pts := PackedVector2Array([sp2 + Vector2(0, -16), sp2 + Vector2(12, 0), sp2 + Vector2(0, 16), sp2 + Vector2(-12, 0)])
		draw_colored_polygon(pts, mcol)
		_text(sp2 + Vector2(-60, 40), "%d m" % int(d), 20, mcol, HORIZONTAL_ALIGNMENT_CENTER, 120.0)

	# top-left: mission + objective
	if mission != "":
		_text(Vector2(40, 54), mission.to_upper(), 20, Color(0.98, 0.8, 0.42))
		draw_rect(Rect2(40, 62, 46, 3), Color(0.98, 0.8, 0.42, 0.9))
	if objective != "":
		draw_multiline_string_outline(font, Vector2(40, 96), objective, HORIZONTAL_ALIGNMENT_LEFT, 560.0, 24, -1, 6, Color(0.04, 0.03, 0.08, 0.85))
		draw_multiline_string(font, Vector2(40, 96), objective, HORIZONTAL_ALIGNMENT_LEFT, 560.0, 24, -1, Color(1, 1, 1, 0.96))

	# boss bar
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var bw := minf(720.0, s.x * 0.5)
		_text(Vector2(s.x * 0.5 - bw * 0.5, 50), boss_name, 24, Color(1.0, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER, bw)
		_bar(Rect2(s.x * 0.5 - bw * 0.5, 62, bw, 16), boss.hp / boss.max_hp, Color(0.95, 0.2, 0.35))

	# bottom-left: warden, health, chi
	var bl := Vector2(44, s.y - 96)
	draw_circle(bl + Vector2(40, 0), 44.0, Color(0.04, 0.03, 0.09, 0.85))
	draw_arc(bl + Vector2(40, 0), 44.0, 0, TAU, 48, col, 4.0, true)
	_icon(el, bl + Vector2(40, 0), 24.0, col)
	_text(bl + Vector2(100, -22), Player.WARDENS[el_name], 30, Color(1, 1, 1))
	_text(bl + Vector2(100 + font.get_string_size(Player.WARDENS[el_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 12, -22),
		EL_NAMES[el] + " Warden", 18, Color(col.r, col.g, col.b, 0.95))
	var hp_col := Color(0.35, 0.85, 0.45) if pl.hp > 35.0 else Color(0.95, 0.3, 0.3)
	_bar(Rect2(bl.x + 100, bl.y - 8, 330, 18), pl.hp / pl.max_hp, hp_col)
	var chi_col := col.lerp(Color(1, 0.3, 0.3), _chi_pulse)
	_bar(Rect2(bl.x + 100, bl.y + 20, 270, 11), pl.chi / pl.max_chi, chi_col)
	_text(Vector2(bl.x + 380, bl.y + 31), "CHI", 13, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)

	# bottom-centre: element wheel
	for i in 4:
		var active: bool = i == el
		var c2 := Vector2(s.x * 0.5 + (i - 1.5) * 78.0, s.y - 78.0)
		var r := (31.0 + _el_pop * 7.0) if active else 22.0
		var ec: Color = Game.EL_COLORS[Player.ELEMENTS[i]]
		draw_circle(c2, r, Color(0.04, 0.03, 0.09, 0.85 if active else 0.6))
		draw_arc(c2, r, 0, TAU, 40, Color(ec.r, ec.g, ec.b, 1.0 if active else 0.45), 4.0 if active else 2.0, true)
		_icon(i, c2, r * 0.55, Color(ec.r, ec.g, ec.b, 1.0 if active else 0.55))
		_text(c2 + Vector2(-20, r + 22), str(i + 1), 16, Color(1, 1, 1, 0.9 if active else 0.5), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 4)

	# bottom-right: moves
	var b = pl.bender
	var keys := [Game.key_label("light"), Game.key_label("heavy"), Game.key_label("special"), Game.key_label("quick"), Game.key_label("ultimate")]
	var cds := [b.cd_light, b.cd_heavy, b.cd_special, b.cd_q, b.cd_ult]
	for i in 5:
		var y := s.y - 218.0 + i * 34.0
		var need: float = b.costs[i] if not (i == 1 and el == 1) else 6
		var usable: bool = cds[i] <= 0.05 and pl.chi >= need
		var a2 := 1.0 if usable else 0.4
		var label: String = b.moves[i]
		if cds[i] > 1.0:
			label += "  (%d)" % int(ceil(cds[i]))
		elif b.costs[i] > 0:
			label += "  %d" % b.costs[i] + ("/s" if (el == 1 and i == 1) else "")
		var kcol := Color(1.0, 0.85, 0.4) if i == 4 else col
		_text(Vector2(s.x - 440, y), label, 22, Color(1, 1, 1, a2), HORIZONTAL_ALIGNMENT_RIGHT, 320.0)
		var kr := Rect2(s.x - 108, y - 22, 68, 28)
		draw_rect(kr, Color(0.04, 0.03, 0.09, 0.8))
		draw_rect(kr, Color(kcol.r, kcol.g, kcol.b, a2), false, 2.0)
		_text(Vector2(kr.position.x, y - 1), keys[i], 17, Color(1, 1, 1, a2), HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 0)
	var extra := "SPACE jump   SHIFT dash"
	if el == 3:
		extra = "SPACE x2 jump - hold to glide   SHIFT dash"
	_text(Vector2(s.x - 640, s.y - 40), extra, 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 600.0, 4)

	# hint + toast
	if hint != "":
		_text(Vector2(0, s.y - 150), hint, 20, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if _toast_t > 0.0:
		_text(Vector2(0, s.y * 0.62), _toast, 24, Color(1.0, 0.5, 0.5, minf(1.0, _toast_t * 2.0)), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if pl.dead:
		_text(Vector2(0, s.y * 0.45), "The Wardens fall...", 54, Color(1, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, s.x, 12, font_title)
		_text(Vector2(0, s.y * 0.45 + 44), "returning to the last shrine", 22, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)

	# banner
	if _banner_t < _banner_dur:
		var k := minf(1.0, _banner_t / 0.5) * minf(1.0, (_banner_dur - _banner_t) / 0.8)
		var y2 := s.y * 0.3
		draw_rect(Rect2(0, y2 - 86, s.x, 150), Color(0.02, 0.02, 0.06, 0.45 * k))
		var lw := 300.0 * k
		draw_rect(Rect2(s.x * 0.5 - lw, y2 - 88, lw * 2.0, 3), Color(0.98, 0.8, 0.42, k))
		draw_rect(Rect2(s.x * 0.5 - lw, y2 + 62, lw * 2.0, 3), Color(0.98, 0.8, 0.42, k))
		_text(Vector2(0, y2 + 8), _banner, 84, Color(1.0, 0.97, 0.9, k), HORIZONTAL_ALIGNMENT_CENTER, s.x, 12, font_title)
		_text(Vector2(0, y2 + 46), _banner_sub, 24, Color(0.98, 0.8, 0.42, k), HORIZONTAL_ALIGNMENT_CENTER, s.x)

	# dialog
	if _line != "":
		var w2 := minf(980.0, s.x - 120.0)
		var r2 := Rect2(s.x * 0.5 - w2 * 0.5, s.y - 300, w2, 118)
		draw_rect(r2, Color(0.03, 0.02, 0.08, 0.82))
		draw_rect(Rect2(r2.position, Vector2(5, r2.size.y)), Color(0.98, 0.8, 0.42))
		_text(r2.position + Vector2(26, 34), _speaker, 20, Color(0.98, 0.8, 0.42), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		var shown := _line.substr(0, int(_dialog_t * 60.0))
		draw_multiline_string(font, r2.position + Vector2(26, 68), shown, HORIZONTAL_ALIGNMENT_LEFT, w2 - 52.0, 23, 3, Color(1, 1, 1, 0.96))
		_text(r2.position + Vector2(w2 - 130, r2.size.y - 12), "%s  skip" % Game.key_label("interact"), 14, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 110.0, 0)


func _draw_pause(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.07, 0.72))
	_text(Vector2(0, s.y * 0.26), "PAUSED", 96, Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_CENTER, s.x, 12, font_title)
	var lines := [
		"%s  -  move          Mouse  -  aim" % Game.move_keys(),
		"%s  -  light bend          %s  -  heavy bend          %s  -  special" % [Game.key_label("light"), Game.key_label("heavy"), Game.key_label("special")],
		"%s  -  quick move          %s  -  ultimate" % [Game.key_label("quick"), Game.key_label("ultimate")],
		"1  2  3  4  -  switch Warden  (TAB cycles)",
		"SPACE  -  jump          SHIFT  -  dash",
		"Sora (Air)  -  jump twice, hold SPACE to glide",
		"F11  -  fullscreen          F10  -  bounced lighting on / off (off is faster)",
		"",
		"ESC  -  resume          Cmd+Q  -  quit",
	]
	for i in lines.size():
		_text(Vector2(0, s.y * 0.26 + 80 + i * 38), lines[i], 22, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, s.x)
