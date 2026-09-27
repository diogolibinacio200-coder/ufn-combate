extends RefCounted
## Fixed 60 Hz simulation: no wall clocks, rendering or hardware input here.
const Fighter = preload("res://scripts/fighter.gd")
const MoveDB = preload("res://scripts/move_db.gd")
const GROUND := 590.0
const EMPTY := {"left":false,"right":false,"up":false,"down":false,"attack":false,"heavy":false,"kick":false,"tag":false,"power":false,"block":false,"attack_pressed":false,"power_pressed":false,"block_pressed":false,"up_pressed":false,"heavy_pressed":false,"kick_pressed":false,"tag_pressed":false}
var move_db = MoveDB.new()
var fighters: Array = []
var projectiles: Array = []
var events: Array = []
var hitstop := 0
var winner := -1
var time_frames := 99 * 60
var tick_count := 0
var training := false
var training_options := {"infinite_health":true,"infinite_meter":true,"guard":"none","dummy":"idle"}
var round_duration := 99
var _serial := 0
var cinematic: Dictionary = {"active":false,"frame":0,"duration":270,"attacker":0,"defender":1,"character":0,"name":"","origin_a":0.0,"origin_d":0.0,"damage_total":0.0,"pulse":0}
var _trade_contacts := false
var team_mode := false
var teams: Array = []
var team_active := [0,0]
var tag_cooldowns := [0,0]
var difficulty := 1
var initial_ids: Array = [[0,3],[1,4]]

func setup(ids: Array = [0,1], is_training: bool = false, reserve_ids: Array = []) -> void:
	training = is_training
	team_mode = reserve_ids.size() == 2
	initial_ids = [[int(ids[0]),int(reserve_ids[0]) if team_mode else int(ids[0])],[int(ids[1]),int(reserve_ids[1]) if team_mode else int(ids[1])]]
	round_duration = 150 if team_mode else 99
	reset_round()

func reset_round() -> void:
	teams = [[],[]]
	team_active = [0,0]
	tag_cooldowns = [0,0]
	for player in 2:
		for id in initial_ids[player]:
			var f=Fighter.create(id,player)
			if id>=MoveDB.PLAYABLE:
				f.max_hp *= ([1.10,1.15,1.25,1.30] if id==14 else [1.15,1.25,1.30,1.40])[clampi(difficulty,0,3)]
				f.hp=f.max_hp
			teams[player].append(f)
	fighters = [teams[0][0],teams[1][0]]
	projectiles.clear()
	events.clear()
	hitstop = 0
	winner = -1
	time_frames = round_duration * 60
	tick_count = 0
	_serial = 0
	cinematic.active = false
	cinematic.frame = 0
	_trade_contacts = false

func reserve(player: int) -> Dictionary:
	return teams[player][1-team_active[player]]

func team_health(player: int) -> float:
	if not team_mode: return fighters[player].hp
	return teams[player][0].hp + teams[player][1].hp

func tag(player: int, forced: bool = false) -> bool:
	if not team_mode or cinematic.active: return false
	var old: Dictionary = fighters[player]
	var next: Dictionary = reserve(player)
	if next.hp <= 0: return false
	if not forced and (tag_cooldowns[player] > 0 or not _free(old) or not Fighter.grounded(old)): return false
	next.x = old.x
	next.bear_x=next.x+old.face*90
	next.bear_stun=0
	next.y = GROUND
	next.face = old.face
	next.state = "idle"
	next.anim = "idle"
	next.move = {}
	next.stun = 0
	next.frame = 0
	next.vel = Vector2.ZERO
	next.buffer_time = 0
	next.invuln = 40 if forced else 18
	old.buffer_time = 0
	old.motion.clear()
	# A tag retires the outgoing fighter's devices, keeping meter attribution and
	# cinematic ownership attached to the active fighter.
	projectiles = projectiles.filter(func(p): return p.owner != player)
	team_active[player] = 1-team_active[player]
	fighters[player] = next
	tag_cooldowns[player] = 300
	_event("tag",player,"TROCA • " + move_db.character(next.id).name)
	return true

func _event(type: String, p: int, text: String = "", extras: Dictionary = {}) -> void:
	var f: Dictionary = fighters[clampi(p,0,1)]
	var ev := {"type":type,"player":p,"x":f.x,"y":f.y - 110.0,"text":text}
	ev.merge(extras,true)
	events.append(ev)

func _meter(f: Dictionary, amount: float) -> void:
	var before: float = f.meter
	f.meter = clampf(f.meter + amount,0.0,100.0)
	if before < 100.0 and f.meter >= 100.0:
		_event("super_ready",f.player,"ULTIMATE PRONTA")

func tick(raw_inputs: Array) -> void:
	events.clear()
	if fighters.size() < 2 or winner >= 0:
		return
	if cinematic.active:
		_tick_cinematic()
		return
	var inputs: Array = []
	for i in 2:
		var value: Dictionary = EMPTY.duplicate()
		if i < raw_inputs.size():
			value.merge(raw_inputs[i],true)
		inputs.append(value)
		_capture(fighters[i],value)
	if hitstop > 0:
		hitstop -= 1
		return
	tick_count += 1
	for i in 2:
		tag_cooldowns[i] = maxi(0,tag_cooldowns[i]-1)
	if not training:
		time_frames = maxi(0,time_frames - 1)
	for i in 2:
		_update_fighter(fighters[i],fighters[1-i],inputs[i])
	_pushboxes()
	for i in 2:
		var f: Dictionary = fighters[i]
		if f.state != "attack" and f.state != "throw" and f.state != "thrown":
			f.face = 1 if fighters[1-i].x >= f.x else -1
	var contacts: Array = []
	for i in 2:
		var f: Dictionary = fighters[i]
		if f.state == "attack" and not f.move.is_empty():
			_process_move(f,fighters[1-i],contacts)
	_resolve_contacts(contacts,inputs)
	if cinematic.active: return
	_update_projectiles(inputs)
	for i in 2:
		var f: Dictionary = fighters[i]
		if training:
			if training_options.get("infinite_meter",true):
				f.meter = 100.0
			if training_options.get("infinite_health",true) and (f.hp <= 0 or (f.stun == 0 and f.state in ["idle","walk","crouch","block","crouch_block"] and f.combo_timer == 0)):
				f.hp = f.max_hp
	_check_round_end()

func _check_round_end() -> void:
	if training: return
	for i in 2:
		if fighters[i].hp <= 0 and team_mode and reserve(i).hp > 0: tag(i,true)
	var a = team_health(0)/team_max_health(0)
	var b = team_health(1)/team_max_health(1)
	if a <= 0 or b <= 0 or time_frames == 0:
		winner = 2 if is_equal_approx(a,b) else (0 if a > b else 1)
		_event("ko",winner if winner < 2 else 0,"TEMPO ESGOTADO" if time_frames == 0 else "K.O.")
		for i in 2:
			fighters[i].state = "victory" if winner == i else "ko"
			fighters[i].anim = fighters[i].state
			fighters[i].frame = 0

func _resolve_contacts(contacts: Array, inputs: Array) -> void:
	# Same-frame throws tech; a same-frame strike defeats a throw. Resolving
	# captures only after collecting contacts removes player-index priority.
	if contacts.size() == 2 and contacts[0].move.kind == "throw" and contacts[1].move.kind == "throw":
		for f in fighters:
			f.state = "idle"
			f.move = {}
			f.invuln = 12
			f.vel.x = -f.face * 7.0
		_event("throw_break",0,"AGARRÕES ANULADOS")
		hitstop = 8
		return
	var strikes: Array = contacts.filter(func(c: Dictionary) -> bool: return c.move.kind != "throw")
	_trade_contacts = strikes.size() == 2 and fighters[0].invuln == 0 and fighters[1].invuln == 0
	for contact in contacts:
		var a: Dictionary = fighters[contact.owner]
		var d: Dictionary = fighters[1-contact.owner]
		if contact.move.kind == "throw":
			if strikes.is_empty(): _begin_throw(a,d)
		else:
			_apply_hit(a,d,contact.move,inputs[1-contact.owner],false)
	_trade_contacts = false

func _begin_throw(a: Dictionary, d: Dictionary) -> void:
	if a.move.family == "super":
		_start_cinematic(a,d,a.move)
		return
	a.state = "throw"
	a.throw_target = d.player
	d.state = "thrown"
	d.thrown_by = a.player
	d.throw_timer = 11
	d.move = {}
	_event("throw_start",a.player,"AGARRÃO")

func _start_cinematic(a: Dictionary, d: Dictionary, m: Dictionary) -> void:
	if a.combo_timer <= 0 or d.state not in ["hitstun","guardbreak"]:
		a.combo = 0
		a.combo_damage = 0.0
	var damage: float = roundf(m.damage * maxf(0.32,1.0-a.combo*0.12))
	cinematic = {"active":true,"frame":0,"duration":210,"attacker":a.player,"defender":d.player,"character":a.id,"name":m.name,"origin_a":a.x,"origin_d":d.x,"damage_total":damage,"damage_applied":0.0,"pulse":0,"base_combo":a.combo}
	a.state = "super"
	d.state = "super_victim"
	a.anim = "super"
	d.anim = "super_victim"
	a.vel = Vector2.ZERO
	d.vel = Vector2.ZERO
	a.y = GROUND
	d.y = GROUND
	a.stun = 0
	d.stun = 0
	a.buffer_time = 0
	d.buffer_time = 0
	a.frame = 0
	d.frame = 0
	a.hit_confirm = true
	d.move = {}
	hitstop = 0
	projectiles.clear()
	_meter(a,6.0)
	_meter(d,4.0)
	_event("cinematic_start",a.player,m.name,{"target":d.player,"duration":210})

func _tick_cinematic() -> void:
	tick_count += 1
	cinematic.frame += 1
	var a: Dictionary = fighters[cinematic.attacker]
	var d: Dictionary = fighters[cinematic.defender]
	a.frame = cinematic.frame
	d.frame = cinematic.frame
	var timelines = [[28,60,83,113,144,187],[20,42,65,93,124,180],[24,51,82,106,137,180],[33,59,85,113,141,184],[25,52,80,110,140,185],[26,54,79,105,137,180],[28,54,78,102,135,180],[22,49,80,115,143,180],[29,57,85,113,141,180],[26,53,78,112,139,180]]
	var strike_frames: Array = timelines[int(cinematic.character)%timelines.size()]
	if strike_frames.has(int(cinematic.frame)):
		var index: int = strike_frames.find(int(cinematic.frame))
		# Five quick strikes and a stronger finisher preserve the exact budget.
		var damage: float = floorf(cinematic.damage_total * 0.12) if index < 5 else cinematic.damage_total-cinematic.damage_applied
		cinematic.damage_applied += damage
		cinematic.pulse = index+1
		d.hp = maxf(0.0,d.hp-damage)
		d.damage_received += damage
		d.last_damage = damage
		a.damage_dealt += damage
		a.combo += 1
		a.combo_damage += damage
		a.max_combo = maxi(a.max_combo,a.combo)
		_event("super_hit",a.player,cinematic.name,{"target":d.player,"damage":damage,"pulse":index+1,"final":index==5,"x":d.x,"y":d.y-115.0})
		_event("hit",a.player,cinematic.name,{"target":d.player,"damage":damage,"combo":a.combo,"x":d.x,"y":d.y-115.0})
		_event("combo",a.player,"%d ACERTOS" % a.combo,{"damage":a.combo_damage})
	if cinematic.frame >= cinematic.duration:
		cinematic.active = false
		a.state = "idle"
		a.anim = "idle"
		a.move = {}
		a.frame = 0
		a.combo_timer = 55
		a.cancel_count = 3
		d.state = "knockdown"
		d.anim = "knockdown"
		d.frame = 0
		d.stun = 32
		d.invuln = 35
		d.wakeup_used = false
		d.vel = Vector2(a.face*8.0,-4.0)
		_event("cinematic_end",a.player,cinematic.name,{"target":d.player})
		if training and training_options.get("infinite_health",true):
			d.hp = 1000.0
		_check_round_end()

func _capture(f: Dictionary, inp: Dictionary) -> void:
	var last: Dictionary = f.last_input
	f.last_input = inp.duplicate()
	for dir in ["down","left","right"]:
		if inp[dir] and not last.get(dir,false):
			if dir != "down" and _free(f) and Fighter.grounded(f) and f.motion.any(func(m): return m.dir == dir and tick_count-int(m.tick) <= 14):
				f.dash_time = 11
				f.dash_dir = 1 if dir == "right" else -1
				_event("dash",f.player,"AVANÇO" if f.dash_dir == f.face else "RECUO")
			f.motion.append({"dir":dir,"tick":tick_count})
	f.motion = f.motion.filter(func(m): return tick_count-int(m.tick) <= 18)
	if inp.block_pressed:
		f.guard_age = 0
		var forward: bool = inp.right if f.face == 1 else inp.left
		if forward: f.parry_age = 0
	if inp.attack_pressed or inp.heavy_pressed or inp.kick_pressed or inp.power_pressed or inp.up_pressed or inp.block_pressed:
		f.buffer = inp.duplicate()
		f.buffer_time = 8
		var tokens: Array = []
		for token in ["up","down","left","right","attack","heavy","kick","power","block","tag"]:
			if inp[token]: tokens.append(token)
		f.history.push_front({"frame":tick_count,"input":" + ".join(tokens)})
		if f.history.size() > 10: f.history.pop_back()

func _motion(f: Dictionary, second: String) -> bool:
	var found_down = false
	for entry in f.motion:
		if found_down and entry.dir == second: return true
		if entry.dir == "down": found_down = true
	return false

func _update_fighter(f: Dictionary, other: Dictionary, inp: Dictionary) -> void:
	f.frame += 1
	f.guard_age += 1
	f.parry_age += 1
	f.invuln = maxi(0,f.invuln - 1)
	f.guard_delay = maxi(0,f.guard_delay - 1)
	f.overclock = maxi(0,f.overclock - 1)
	f.transform = maxi(0,f.transform-1)
	f.dash_time = maxi(0,f.dash_time-1)
	f.prepared = maxi(0,f.prepared-1)
	f.feint_time = maxi(0,f.feint_time-1)
	f.control_immunity=maxi(0,f.control_immunity-1)
	f.embalo_time=maxi(0,f.embalo_time-1)
	if f.embalo_time==0:f.embalo=0
	if f.id==13:_update_bear(f,other)
	if f.id == 1 and f.combo_timer == 0 and f.stun == 0: f.rage = maxf(0.0,f.rage-0.035)
	f.status_time = maxi(0,f.status_time - 1)
	if f.status_time == 0: f.status = ""
	f.combo_timer = maxi(0,f.combo_timer - 1)
	if f.combo_timer == 0:
		f.combo = 0
		f.combo_damage = 0.0
		f.cancel_count = 0
	if f.guard_delay == 0 and not inp.block and f.state not in ["blockstun","guardbreak"]:
		f.guard = minf(100.0,f.guard + 0.27)
	if f.state == "thrown":
		_update_throw(f,other,inp)
		return
	if f.state == "throw":
		f.anim = "throw"
		return
	if f.stun > 0:
		_wakeup_input(f,inp)
		f.stun -= 1
		f.buffer_time = maxi(0,f.buffer_time - 1)
		_physics(f)
		if f.stun == 0:
			if f.state in ["knockdown","guardbreak"]:
				f.state = "wakeup"
				f.stun = 10
				f.invuln = 12
				f.frame = 0
			elif f.y >= GROUND:
				f.state = "idle"
				f.juggle = 0
			else:
				f.state = "jump"
		f.anim = f.state
		return
	if f.state == "attack" and not f.move.is_empty():
		if f.frame > f.move.startup + f.move.active + f.move.recovery:
			if f.move.kind == "drink":
				f.embalo=mini(3,f.embalo+1)
				f.embalo_time=480
				_event("buff",f.player,"EMBALO %d / 3"%f.embalo)
			if f.move.kind == "reload":
				f.ammo = 6
				_event("buff",f.player,"MUNIÇÃO RECARREGADA")
			f.state = "idle" if f.y >= GROUND else "jump"
			f.move = {}
			f.frame = 0
	if f.buffer_time > 0:
		if _command(f,other,f.buffer):
			f.buffer_time = 0
		f.buffer_time = maxi(0,f.buffer_time - 1)
	if _free(f):
		var grounded: bool = Fighter.grounded(f)
		if grounded and inp.block:
			f.state = "crouch_block" if inp.down else "block"
			f.vel.x = 0
		elif grounded and inp.down:
			f.state = "crouch"
			f.vel.x = 0
		else:
			var dir := int(inp.right) - int(inp.left)
			f.vel.x = dir * move_db.SPEEDS[f.id] * (0.63 if f.status == "slow" else (0.0 if f.status == "root" else 1.0))
			if f.dash_time > 0 and grounded and f.status != "root": f.vel.x = f.dash_dir*move_db.SPEEDS[f.id]*2.2
			f.state = ("walk" if dir != 0 else "idle") if grounded else "jump"
			if grounded and dir != 0: _event("move",f.player)
	elif f.state == "attack" and not f.move.is_empty():
		var m: Dictionary = f.move
		f.vel.x = m.speed * f.face if f.frame >= m.startup and f.frame < m.startup + m.active and m.kind in ["dash","slide","strike","uppercut","reload"] else f.vel.x * 0.8
	_physics(f)
	f.anim = f.state

func _free(f: Dictionary) -> bool:
	return f.state in ["idle","walk","crouch","block","crouch_block","jump","wakeup"] and f.stun == 0

func _wakeup_input(f: Dictionary, inp: Dictionary) -> void:
	if f.state != "knockdown" or f.frame < 6 or f.wakeup_used or not Fighter.grounded(f): return
	var direction := int(inp.right)-int(inp.left)
	var roll_edge: bool = inp.block_pressed or inp.get("left_pressed",false) or inp.get("right_pressed",false)
	if inp.block and direction != 0 and roll_edge and f.meter >= 20.0:
		f.meter -= 20.0
		f.roll_frames = 12
		f.roll_dir = direction
		f.invuln = maxi(f.invuln,12)
		f.stun = mini(f.stun,12)
		f.wakeup_used = true
		_event("wakeup_roll",f.player,"ROLAMENTO")
	elif inp.up_pressed or inp.attack_pressed:
		f.stun = mini(f.stun,8)
		f.wakeup_used = true
		_event("quick_rise",f.player,"RECUPERAÇÃO RÁPIDA")

func _command(f: Dictionary, other: Dictionary, inp: Dictionary) -> bool:
	var forward: bool = inp.right if f.face == 1 else inp.left
	var back: bool = inp.left if f.face == 1 else inp.right
	var attack_edge: bool = inp.attack_pressed
	var command: Dictionary = {}
	if inp.block:
		if not (inp.heavy_pressed or inp.kick_pressed or attack_edge):return false
		if not _free(f):
			_event("no_meter",f.player,"AGUARDE A RECUPERAÇÃO")
			return true
		if inp.heavy_pressed:command=move_db.super_move(f.id)
		elif inp.kick_pressed:
			if not tag(f.player):_event("no_meter",f.player,"TROCA INDISPONÍVEL")
			return true
		else:command=move_db.move("AGARRÃO","throw",105,6,3,28,86,0,{"family":"throw","guard_damage":0.0,"height":180.0,"body_pose":"grab","visual":"bear" if f.id==13 else "impact"})
	elif (attack_edge and _motion(f,"right" if f.face == 1 else "left")):
		command = move_db.specials(f.id)[0]
		f.buffer.special_slot = 0
		f.motion.clear()
	elif (attack_edge and _motion(f,"left" if f.face == 1 else "right")):
		command = move_db.specials(f.id)[1]
		f.buffer.special_slot = 1
		f.motion.clear()
	elif inp.heavy_pressed and _motion(f,"down"):
		command = move_db.specials(f.id)[2]
		f.buffer.special_slot = 2
		f.motion.clear()
	elif inp.get("special_slot",-1) >= 0:
		command = move_db.specials(f.id)[clampi(int(inp.special_slot),0,2)]
	elif f.prepared > 0 and (inp.kick_pressed or inp.heavy_pressed):
		command = move_db.move("VOLEIO PREPARADO" if not inp.down else "CHUTE RASTEIRO","projectile",110,10,1,29,65,0,{"speed":11.0,"level":"mid" if not inp.down else "low","visual":"football","body_pose":"kick"})
		f.prepared = 0
	elif f.feint_time > 0 and (attack_edge or inp.heavy_pressed) and f.id == 6:
		command = move_db.move("FINALIZAÇÃO DE QUADRA","projectile",89,8,1,26,64,0,{"speed":11.0,"visual":"handball","body_pose":"throw"})
		f.feint_time = 0
	elif inp.heavy_pressed:
		command = move_db.normals()[7 if inp.down else 6]
	elif inp.kick_pressed:
		command = move_db.normals()[5 if f.y < GROUND-2 else (3 if inp.down else 8)]
	elif attack_edge:
		var slot := 0
		if f.y < GROUND - 2: slot = 5 if forward or back else 4
		elif inp.down: slot = 3
		elif inp.up: slot = 7
		elif forward: slot = 1
		elif back: slot = 2
		command = move_db.normals()[slot]
	elif inp.up_pressed and _free(f) and Fighter.grounded(f) and not inp.block and f.status != "root":
		f.vel.y = Fighter.BASE.jump_velocity
		f.state = "jump"
		f.frame = 0
		_event("jump",f.player)
		return true
	if command.is_empty(): return false
	if f.meter < command.cost:
		_event("no_meter",f.player,"ENERGIA INSUFICIENTE")
		return true
	if not _free(f):
		if not (f.state == "attack" and f.hit_confirm and f.cancel_count < 3): return false
		if f.move.family == "normal":
			if not f.move.get("cancel",false): return false
			if command.family == "normal" and (command.name == f.move.name or f.cancel_count >= 2): return false
			if command.family not in ["normal","special","super"]: return false
		elif command.family != "super": return false
		f.cancel_count += 1
	if f.id == 2 and command.name == "DISPARO CERTEIRO" and f.ammo <= 0:
		_event("no_meter",f.player,"RECARREGUE • ↓ ↓ + FORTE")
		return true
	if f.id==13 and f.bear_stun>0:
		_event("no_meter",f.player,"URSO DESORGANIZADO")
		return true
	_start_move(f,command)
	return true

func _start_move(f: Dictionary, source: Dictionary) -> void:
	var m: Dictionary = source.duplicate(true)
	if f.id==13:
		m.name="URSO · "+m.name if m.family=="normal" else m.name
		m.visual="bear_return" if m.visual=="bear_return" else "bear"
		m.body_pose="projectile"
	if f.id==11 and f.embalo>0 and m.damage>0:
		m.damage*=1.0+f.embalo*.12
		f.embalo=0
	if m.family == "normal":
		if f.id == 0:
			m.damage *= 1.14
			m.startup += 1
		if f.id == 7: m.recovery = maxi(8,m.recovery-2)
		if f.id == 5 and m.body_pose in ["kick","sweep","airkick"]: m.damage *= 1.12
		if f.transform > 0:
			m.range += 30.0
			m.damage *= 1.2
			m.visual = "exosuit"
		if f.overclock > 0: m.damage *= 1.35
	if f.id == 1 and m.name == "PERDEU A PACIÊNCIA" and f.rage >= 55:
		m.damage *= 1.35
		m.visual = "rage_combo"
	if f.id == 2 and m.name == "DISPARO CERTEIRO": f.ammo -= 1
	if f.id == 8 and m.name == "VETOR DIRECIONAL" and f.last_input.up: m.vy = -5.0
	if m.kind == "jump_toss": f.vel.y = -10.0
	if m.chargeable and f.charge >= 28:
		m.damage *= 1.2
		m.startup += 4
		m.recovery += 5
	f.meter = maxf(0,f.meter - m.cost)
	f.state = "attack"
	f.anim = "attack"
	f.frame = 0
	f.move = m
	f.hit_targets = []
	f.hit_confirm = false
	f.invuln = maxi(f.invuln,m.invuln)
	f.vel.x *= 0.5
	f.dash_time = 0
	f.attacks += 1
	# Whiffing cannot generate unlimited energy.
	_event("attack",f.player,m.name,{"kind":m.kind,"visual":m.visual})
	if m.family == "super":
		f.supers += 1
		hitstop = maxi(hitstop,12)
		_event("super",f.player,m.name)

func _physics(f: Dictionary) -> void:
	if f.roll_frames > 0:
		f.vel.x = f.roll_dir*5.0
		f.roll_frames -= 1
	f.x = clampf(f.x + f.vel.x,90.0,1190.0)
	if f.y < GROUND or f.vel.y < 0:
		f.vel.y += Fighter.BASE.gravity * (1.0 + f.juggle * 0.17)
		f.y += f.vel.y
	if f.y >= GROUND:
		var landed: bool = f.vel.y > 0
		f.y = GROUND
		f.vel.y = 0
		if landed:
			_event("land",f.player)
			if f.state == "hitstun" and f.juggle > 0:
				f.state = "knockdown"
				f.stun = 24
				f.frame = 0
				f.wakeup_used = false
			elif f.state == "jump":
				f.state = "idle"
				f.frame = 0
	if f.state in ["hitstun","blockstun","knockdown","guardbreak","wakeup"]:
		f.vel.x *= 0.83

func _pushboxes() -> void:
	var a: Dictionary = fighters[0]
	var b: Dictionary = fighters[1]
	if a.state in ["throw","thrown"] or b.state in ["throw","thrown"]: return
	if not Fighter.pushbox(a).intersects(Fighter.pushbox(b)): return
	var distance: float = absf(a.x - b.x)
	if distance >= 66.0: return
	var direction := 1.0 if b.x >= a.x else -1.0
	var shift := (66.0 - distance) * 0.5
	a.x = clampf(a.x - shift * direction,90.0,1190.0)
	b.x = clampf(b.x + shift * direction,90.0,1190.0)
	# Correct the remainder when one fighter is pinned against the arena edge.
	if absf(a.x - b.x) < 66.0:
		if a.x <= 90.0 or a.x >= 1190.0: b.x = a.x + direction * 66.0
		else: a.x = b.x - direction * 66.0

func hitbox(f: Dictionary) -> Rect2:
	if f.move.is_empty(): return Rect2()
	var m: Dictionary = f.move
	var origin:float=f.bear_x if f.id==13 else f.x
	var x: float = origin + 15.0 if f.face == 1 else origin - m.range
	if m.kind == "burst": x = f.x - m.range
	return Rect2(x,f.y + m.offset_y - m.height * 0.5,m.range - 15.0 if m.kind != "burst" else m.range * 2.0,m.height)

func _process_move(f: Dictionary, other: Dictionary, contacts: Array) -> void:
	var m: Dictionary = f.move
	if f.frame < m.startup or f.frame >= m.startup + m.active: return
	if f.frame == m.startup:
		match m.kind:
			"projectile","jump_toss": _spawn(f,m,"projectile",f.x + f.face * 67.0,f.y - 112.0)
			"reload":
				f.move.reloading = true
			"prepare":
				f.prepared = m.duration
				_event("buff",f.player,m.name)
			"transform":
				f.transform = m.duration
				_event("buff",f.player,m.name)
			"cloud","loop","sentry","drone":
				for old in projectiles:
					if old.owner == f.player and old.kind == m.kind: old.dead = true
				_spawn(f,m,m.kind,f.x+f.face*(65.0 if m.kind in ["sentry","drone"] else m.range),GROUND-50.0)
			"allies":
				_spawn(f,m,"projectile",f.x+f.face*65.0,f.y-95.0)
				var second = m.duplicate(true)
				second.setup_time = 22
				_spawn(f,second,"projectile",f.x-f.face*25.0,f.y-115.0)
			"feint":
				f.x = clampf(f.x+f.face*m.range,90.0,1190.0)
				f.feint_time = m.duration
				f.invuln = 5
				_event("teleport",f.player,m.name)
			"trap":
				for old in projectiles:
					if old.owner == f.player and old.kind == "trap": old.dead = true
				_spawn(f,m,"trap",clampf(f.x + m.range * f.face,110.0,1170.0),GROUND - 22.0)
			"barrier":
				for old in projectiles:
					if old.owner == f.player and old.kind == "barrier": old.dead = true
				_spawn(f,m,"barrier",f.x + 100.0 * f.face,GROUND - 92.0)
			"teleport","evade":
				var old_x: float = f.x
				f.x = clampf(f.x + f.face * m.range,90.0,1190.0)
				f.invuln = 5
				_event("teleport",f.player,m.name,{"from_x":old_x})
			"crossup":
				f.x = clampf(other.x + other.face * 90.0,90.0,1190.0)
				f.face = 1 if other.x >= f.x else -1
				_event("teleport",f.player,m.name)
			"blink_strike":
				f.x = clampf(f.x + f.face * minf(90.0,maxf(0.0,absf(f.x-other.x)-110.0)),90.0,1190.0)
				_event("teleport",f.player,m.name)
			"buff":
				f.overclock = m.duration if f.rage >= 20 else 0
				f.rage = maxf(0.0,f.rage-35.0)
				_event("buff",f.player,m.name)
			"uppercut":
				if f.id!=13:f.vel.y = -6.8
			"throw":
				if absf((f.bear_x if f.id==13 else f.x)-other.x) <= m.range and Fighter.grounded(other) and other.invuln == 0 and other.stun == 0 and other.state not in ["throw","thrown"]:
					contacts.append({"owner":f.player,"move":m.duplicate(true)})
	if m.kind in ["projectile","trap","barrier","teleport","counter","buff","evade","throw","cloud","loop","sentry","drone","allies","reload","drink","transform","prepare","feint","jump_toss"]: return
	if f.hit_targets.has(other.player): return
	if hitbox(f).intersects(Fighter.hurtbox(other)):
		f.hit_targets.append(other.player)
		contacts.append({"owner":f.player,"move":m.duplicate(true)})

func _apply_hit(a: Dictionary, d: Dictionary, m: Dictionary, inp: Dictionary, projectile: bool) -> bool:
	if cinematic.active or d.invuln > 0 or d.state in ["thrown","throw","knockdown","wakeup"]: return false
	if d.state == "attack" and not d.move.is_empty() and d.move.kind == "counter" and d.frame >= d.move.startup and d.frame < d.move.startup+d.move.active:
		var counter_move: Dictionary = d.move.duplicate(true)
		if counter_move.family == "super":
			_start_cinematic(d,a,counter_move)
			return true
		d.move = {}
		d.state = "idle"
		d.invuln = 8
		if projectile:
			_meter(d,8)
			_event("counter",d.player,counter_move.name+" · ABSORB",{"target":a.player,"damage":0.0})
			return true
		a.state = "hitstun"
		a.stun = 29
		a.frame = 0
		a.hp = maxf(0.0,a.hp-counter_move.damage)
		a.vel.x = d.face * counter_move.push
		if counter_move.freeze > 0:
			a.status = "freeze"
			a.status_time = int(counter_move.freeze)
			a.stun += int(counter_move.freeze)
		d.damage_dealt += counter_move.damage
		a.damage_received += counter_move.damage
		_meter(d,13)
		d.last_counter = true
		hitstop = maxi(hitstop,10)
		_event("counter",d.player,counter_move.name,{"target":a.player,"damage":counter_move.damage})
		return true
	var can_guard: bool = d.state in ["idle","walk","crouch","block","crouch_block","blockstun"] and Fighter.grounded(d)
	var correct_level: bool = (inp.down and m.level != "high") or (not inp.down and m.level != "low")
	if can_guard and inp.block and correct_level:
		if d.parry_age <= 3 and not projectile:
			d.parry_age = 999
			d.guard_age = 999
			d.state = "idle"
			d.stun = 0
			d.parries += 1
			d.invuln = 7
			a.state = "hitstun"
			a.stun = 21
			a.frame = 0
			_meter(d,15)
			hitstop = maxi(hitstop,9)
			_event("parry",d.player,"APARO!",{"target":a.player})
			return true
		var perfect: bool = d.guard_age <= 5
		d.guard_age = 999
		d.last_perfect = perfect
		d.guard = maxf(0.0,d.guard - m.guard_damage * (0.18 if perfect else 1.0))
		d.guard_delay = 100
		if d.id == 1: d.rage = minf(100.0,d.rage+8.0)
		d.hp = maxf(1.0,d.hp - (0.0 if perfect else m.damage * m.chip))
		d.state = "blockstun"
		d.stun = 5 if perfect else m.blockstun
		d.frame = 0
		d.vel.x = a.face * (1.3 if perfect else 3.0)
		a.vel.x = -a.face * 1.4
		_meter(d,10.0 if perfect else 3.0)
		_meter(a,2.0)
		hitstop = maxi(hitstop,7 if perfect else 4)
		if perfect:
			d.perfect_blocks += 1
			_event("perfect_block",d.player,"DEFESA PERFEITA",{"target":a.player})
		else:
			_event("block",d.player,"DEFESA",{"target":a.player})
		if d.guard <= 0:
			d.state = "guardbreak"
			d.stun = 52
			d.guard = 22.0
			a.guard_breaks += 1
			hitstop = maxi(hitstop,15)
			_event("guard_break",d.player,"GUARDA QUEBRADA!",{"target":a.player})
		return true
	if m.family == "super" and a.id!=14 and not _trade_contacts:
		_start_cinematic(a,d,m)
		return true
	var counter: bool = d.state == "attack" and not d.move.is_empty() and d.frame < d.move.startup
	# A display timer may outlive hitstun; a recovered opponent starts a new combo.
	if a.combo_timer <= 0 or d.state not in ["hitstun","guardbreak"]:
		a.combo = 0
		a.combo_damage = 0.0
		a.cancel_count = 0
	var scaling := maxf(0.32,1.0 - a.combo * 0.12)
	var damage: float = roundf(m.damage * scaling * (1.08 if counter else 1.0))
	d.hp = maxf(0.0,d.hp - damage)
	if d.id == 1: d.rage = minf(100.0,d.rage+damage*0.24)
	if a.overclock > 0 and m.family == "normal": a.overclock = 0
	d.damage_received += damage
	a.damage_dealt += damage
	a.combo += 1
	a.combo_damage += damage
	a.max_combo = maxi(a.max_combo,a.combo)
	a.combo_timer = 100
	a.hit_confirm = true
	d.last_damage = damage
	d.last_counter = counter
	d.frame = 0
	d.state = "hitstun"
	d.stun = maxi(8,int(m.hitstun) - (a.combo-1)*2 + (7 if counter else 0))
	d.move = {}
	d.vel.x = a.face * (m.push + a.combo * 0.35)
	if m.pull > 0:
		d.vel.x = -a.face * m.pull
	if m.launch < 0 and d.juggle < 4:
		d.vel.y = m.launch * maxf(0.5,1.0-d.juggle*0.16)
		d.juggle += 1
	elif d.y < GROUND:
		d.juggle += 1
	if m.freeze > 0 and a.combo <= 3:
		d.stun += int(m.freeze)
		d.status = "freeze"
		d.status_time = int(m.freeze)
	if m.get("root",0) > 0 and d.control_immunity<=0:
		d.status = "root"
		d.status_time = int(m.root)
		d.stun = maxi(d.stun,int(m.root))
		d.control_immunity=int(m.root)+90
	if m.get("slow",0) > 0:
		d.status = "slow"
		d.status_time = int(m.slow)
	if a.combo >= 8 or d.juggle >= 5:
		d.state = "knockdown"
		d.stun = 32
		d.invuln = 35
		d.wakeup_used = false
		d.vel.y = 3.0
		d.vel.x = a.face * 11.0
	a.combo_timer = maxi(45,d.stun + 16)
	_meter(a,8.0 if counter else 6.0)
	_meter(d,4.0)
	hitstop = maxi(hitstop,7 if m.damage < 90 else 11)
	_event("hit",a.player,m.name,{"target":d.player,"x":d.x,"y":d.y-105,"damage":damage,"combo":a.combo})
	if counter: _event("counter",a.player,"CONTRA-ATAQUE!",{"target":d.player})
	if a.combo >= 2: _event("combo",a.player,"%d ACERTOS" % a.combo,{"damage":a.combo_damage})
	if m.kind == "super":
		hitstop = maxi(hitstop,27)
		_event("super_hit",a.player,m.name,{"target":d.player,"damage":damage})
	if m.kind == "echo":
		var echo: Dictionary = m.duplicate(true)
		echo.damage = 26.0
		echo.kind = "echo_hit"
		echo.freeze = 0
		_spawn(a,echo,"echo",d.x,d.y-105.0)
	if d.id==13:
		d.bear_stun=maxi(d.bear_stun,24)
		d.bear_x=move_toward(d.bear_x,d.x+d.face*80,55)
	return true

func _update_throw(d: Dictionary, a: Dictionary, inp: Dictionary) -> void:
	d.throw_timer -= 1
	d.x = (a.bear_x if a.id==13 else a.x) + a.face * 70.0
	d.y = GROUND
	if inp.block and inp.attack_pressed:
		d.state = "idle"
		a.state = "idle"
		d.invuln = 12
		a.invuln = 12
		d.vel.x = a.face * 7.0
		a.vel.x = -a.face * 7.0
		d.thrown_by = -1
		a.throw_target = -1
		hitstop = maxi(hitstop,8)
		_event("throw_break",d.player,"AGARRÃO ANULADO!")
		return
	if d.throw_timer <= 0:
		var damage: float = a.move.get("damage",105.0)
		d.hp = maxf(0.0,d.hp - damage)
		d.state = "knockdown"
		d.stun = 34
		d.wakeup_used = false
		d.vel = Vector2(a.face * 11.0,-5.0)
		d.thrown_by = -1
		a.state = "idle"
		a.throw_target = -1
		a.throws += 1
		a.damage_dealt += damage
		d.damage_received += damage
		a.move = {}
		_meter(a,9)
		_meter(d,5)
		hitstop = maxi(hitstop,12)
		_event("throw",a.player,"AGARRÃO",{"target":d.player,"damage":damage})

func _spawn(f: Dictionary, m: Dictionary, kind: String, x: float, y: float) -> void:
	_serial += 1
	projectiles.append({"uid":_serial,"x":x,"y":y,"owner":f.player,"kind":kind,"face":f.face,"vel":Vector2(m.speed*f.face if kind == "projectile" else 0,m.get("vy",0.0) if kind == "projectile" else 0),"life":m.duration,"age":0,"radius":m.range*0.5 if kind == "projectile" else (58.0 if kind == "trap" else 42.0),"move":m.duplicate(true),"dead":false,"color":move_db.character(f.id).color,"hp":(1 if m.visual=="firewall" else 2) if kind in ["barrier","sentry"] else 1,"hits":0,"next_hit":0,"visual":m.visual,"bounces":m.get("bounces",0)})
	_event("projectile",f.player,m.name,{"kind":kind,"x":x,"y":y})

func _update_projectiles(inputs: Array) -> void:
	for p in projectiles.duplicate():
		p.life -= 1
		p.age += 1
		if p.age > p.move.setup_time:
			p.vel.y += p.move.gravity
			p.x += p.vel.x
			p.y += p.vel.y
		if p.y >= GROUND-25 and p.kind == "projectile":
			if p.bounces > 0:
				p.y = GROUND-25
				p.vel.y = -absf(p.vel.y)*0.72
				p.bounces -= 1
			else: p.dead = true
		if p.kind=="projectile" and _hit_bear_projectile(p):p.dead=true
		if p.kind == "cloud":
			var target: Dictionary = fighters[1-p.owner]
			if absf(target.x-p.x) < 150 and Fighter.grounded(target):
				target.status = "slow"
				target.status_time = 8
		if p.kind in ["drone","sentry"] and (p.age == 25 if p.kind == "drone" else p.age % 55 == 0):
			var shot: Dictionary = p.move.duplicate(true)
			shot.kind = "projectile"
			shot.setup_time = 0
			shot.duration = 100
			shot.visual = "pulse"
			_spawn(fighters[p.owner],shot,"projectile",p.x,p.y-45.0)
			if p.kind == "drone": p.dead = true
		if p.visual=="packet" and p.age==18:p.vel.x*=1.65
		if p.kind in ["sentry","barrier"]:
			var foe: Dictionary = fighters[1-p.owner]
			if foe.state == "attack" and foe.move.damage>0 and foe.move.range>0 and foe.frame >= foe.move.startup and foe.frame < foe.move.startup+foe.move.active and hitbox(foe).has_point(Vector2(p.x,p.y)):
				p.dead = true
		if p.kind=="loop" and p.visual=="gas" and p.move.family=="super":
			p.radius=83
			p.x=[340.0,640.0,940.0][mini(2,int(maxi(0,p.age-p.move.setup_time)/p.move.pulse_interval))]
		if p.kind == "loop" and p.hits < 3 and p.age >= p.move.setup_time and (p.age-p.move.setup_time)%p.move.pulse_interval == 0:
			p.next_hit = 0
			p.hits += 1
			_event("special",p.owner,("ONDA GASOSA %d / 3" if p.visual=="gas" else "LOOP %d / 3") % p.hits,{"x":p.x,"y":p.y})
		if p.life <= 0 or p.x < 25 or p.x > 1255: p.dead = true
	for i in projectiles.size():
		var a: Dictionary = projectiles[i]
		if a.dead or a.kind not in ["projectile","barrier"]: continue
		for j in range(i+1,projectiles.size()):
			if a.dead: break
			var b: Dictionary = projectiles[j]
			if b.dead or b.owner == a.owner or b.kind not in ["projectile","barrier"]: continue
			if a.kind == "barrier" and b.kind == "barrier": continue
			if absf(a.x-b.x) < a.radius+b.radius and absf(a.y-b.y) < 100:
				if a.kind == "barrier": a.hp -= 1
				else: a.dead = true
				if b.kind == "barrier": b.hp -= 1
				else: b.dead = true
				if a.hp <= 0: a.dead = true
				if b.hp <= 0: b.dead = true
				_event("clash",a.owner,"COLISÃO",{"x":(a.x+b.x)*0.5,"y":a.y})
	for p in projectiles:
		if p.dead or p.kind in ["barrier","cloud","drone","sentry"]: continue
		if p.age < p.move.setup_time: continue
		if p.kind == "loop" and (p.hits <= 0 or p.hits > 3 or p.next_hit > 0): continue
		if p.kind == "trap" and p.age < 18: continue
		if p.kind=="loop" and p.visual=="gas" and (p.age-p.move.setup_time)%p.move.pulse_interval>10:continue
		if p.kind == "echo" and p.age < 12: continue
		var d: Dictionary = fighters[1-p.owner]
		var box := Rect2(p.x-p.radius,p.y-p.radius,p.radius*2,p.radius*2)
		if box.intersects(Fighter.hurtbox(d)):
			# Digital defense can return a projectile once; other counters absorb it.
			if d.state == "attack" and not d.move.is_empty() and d.move.get("reflect",false) and d.frame >= d.move.startup and d.frame < d.move.startup+d.move.active and p.kind == "projectile":
				p.owner = d.player
				p.vel.x *= -1
				p.face *= -1
				p.x += p.face * 85
				p.color = move_db.character(d.id).color
				_event("parry",d.player,"REFLEXO ADAPTATIVO")
			elif _apply_hit(fighters[p.owner],d,p.move,inputs[1-p.owner],true):
				if cinematic.active: return
				if p.kind == "loop": p.next_hit = 1
				else: p.dead = true
	projectiles = projectiles.filter(func(p: Dictionary) -> bool: return not p.dead)

func snapshot() -> Dictionary:
	return {"tick":tick_count,"time":time_frames,"winner":winner,"hitstop":hitstop,"fighters":fighters.duplicate(true),"projectiles":projectiles.duplicate(true),"cinematic":cinematic.duplicate(true)}

func team_max_health(player: int) -> float:
	return teams[player][0].max_hp+(teams[player][1].max_hp if team_mode else 0.0)

func _update_bear(f: Dictionary,other: Dictionary) -> void:
	f.bear_stun=maxi(0,f.bear_stun-1)
	if f.bear_stun==0:f.bear_posture=minf(100,f.bear_posture+.19)
	var target:float=f.x+f.face*85
	if f.state=="attack" and not f.move.is_empty() and f.bear_stun==0:
		target=f.x+f.face*(165 if f.move.visual!="bear_return" else 50)
	f.bear_x=clampf(move_toward(f.bear_x,target,6),110,1170)
	if f.hp<=0 or f.stun>0:
		f.bear_x=move_toward(f.bear_x,f.x+f.face*70,8)
		return
	if other.state=="attack" and not other.move.is_empty() and other.move.damage>0 and other.move.range>0 and other.frame>=other.move.startup and other.frame<other.move.startup+other.move.active:
		if f.bear_hit!=other.attacks and hitbox(other).intersects(Rect2(f.bear_x-43,GROUND-167,86,157)):
			f.bear_hit=other.attacks
			_bear_damage(f,other.move.damage)

func _bear_damage(f: Dictionary,damage: float) -> void:
	f.bear_posture=maxf(0,f.bear_posture-damage*.55)
	if f.bear_posture<=0:
		f.bear_stun=100
		f.bear_posture=35
		if f.state=="attack":f.state="idle";f.move={};f.buffer_time=0
		_event("buff",f.player,"URSO DESORGANIZADO")

func _hit_bear_projectile(p: Dictionary) -> bool:
	var f:Dictionary=fighters[1-p.owner]
	if f.id!=13 or f.bear_stun>0:return false
	if absf(p.x-f.bear_x)<p.radius+36 and p.y>GROUND-170:
		_bear_damage(f,p.move.damage)
		return true
	return false
