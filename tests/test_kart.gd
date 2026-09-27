extends SceneTree
## Standalone deterministic checks for driving, checkpoint integrity and powers.
const Kart = preload("res://scripts/kart.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, explanation: String) -> void:
	if value:
		passed += 1
		print("PASS ",explanation)
	else:
		failed += 1
		push_error("FAIL "+explanation)

func pilot(game: Node, distance: float = 0.0) -> Dictionary:
	var sample: Dictionary = game.sample_road(distance)
	return {"id":0,"character":0,"invincible":0.0,"jump":0.0,"signature":0.0,"pos":sample.pos,"previous_pos":sample.pos,"heading":Vector2(sample.dir).angle(),"velocity":Vector2.ZERO,"speed":0.0,"steer":0.0,"lap":1,"next_gate":1,"gates":0,"rank":1,"item":0,"drift":0.0,"drifting":false,"boost":0.0,"shield":0.0,"stun":0.0,"hit_flash":0.0,"offroad":false,"wrongway":false,"progress":0.0,"finish_time":-1.0,"notice":"","notice_time":0.0,"recovery":0.0,"trail_timer":0.0,"max_speed":31.0,"bot_timer":3.0}

func cross(game: Node,r: Dictionary,index: int,forward: bool = true,lateral: float = 0.0) -> void:
	var gate: Dictionary = game.checkpoints[index]
	var dir: Vector2 = gate.dir
	var normal: Vector2 = Vector2(-dir.y,dir.x)
	r.previous_pos = Vector2(gate.pos)+normal*lateral+dir*(-1 if forward else 1)
	r.pos = Vector2(gate.pos)+normal*lateral+dir*(1 if forward else -1)
	game.check_gate(r)

func run() -> void:
	var game: Node = Kart.new()
	root.add_child(game)
	var host=Node.new()
	host.set_script(load("res://tests/kart_input_host.gd"))
	root.add_child(host)
	game.setup(host)
	game._build_track()
	expect(game.road.size()>100 and game.total_length>400,"smooth closed campus circuit with distance parameterization")
	var r: Dictionary = pilot(game)
	for i: int in range(60):
		game.step_racer(r,{"throttle":1.0,"steer":0.0},1.0/60.0)
	expect(r.speed>12 and Vector2(r.pos).distance_to(game.road[0])>5,"acceleration produces forward movement")
	var before_brake: float = r.speed
	for i: int in range(20):
		game.step_racer(r,{"throttle":-1.0,"steer":0.0},1.0/60.0)
	expect(r.speed<before_brake-5,"braking removes speed")
	r = pilot(game)
	r.speed = 20.0
	var old_heading: float = r.heading
	game.step_racer(r,{"throttle":1.0,"steer":1.0},0.1)
	expect(r.heading>old_heading,"steering turns the vehicle")
	r.drift = 1.0
	r.drifting = true
	game.step_racer(r,{"throttle":1.0,"steer":0.0,"drift":false},0.016)
	expect(r.boost>1 and r.drift==0,"releasing a charged drift awards miniturbo")
	r = pilot(game)
	cross(game,r,0)
	expect(r.lap==1 and r.gates==0,"crossing the finish without checkpoints never awards a lap")
	cross(game,r,1,false)
	expect(r.next_gate==1,"reverse crossing cannot advance checkpoints")
	cross(game,r,1,true,15.0)
	expect(r.next_gate==1,"crossing outside the finite road gate cannot count")
	cross(game,r,2)
	expect(r.next_gate==1,"skipping the next checkpoint cannot count")
	for gate: int in range(1,20):
		cross(game,r,gate)
	cross(game,r,0)
	expect(r.lap==2 and r.gates==20,"all 20 ordered checkpoints award exactly one lap")
	for lap_i: int in range(2):
		for gate: int in range(1,20):
			cross(game,r,gate)
		cross(game,r,0)
	expect(r.lap==4 and r.finish_time>=0,"three complete laps finish the race")
	r = pilot(game)
	r.shield = 3.0
	r.speed = 25.0
	game.hit_racer(r,1.5)
	expect(r.shield==0 and r.stun==0 and r.speed==25,"shield absorbs one attack without slowing")
	r.invincible=0.0
	game.hit_racer(r,1.5)
	expect(r.stun>=1.5 and r.speed<10,"unshielded impact stuns and slows")
	r.next_gate = 7
	r.gates = 6
	r.pos = Vector2(999,999)
	game.respawn_racer(r)
	expect(r.next_gate==7 and r.gates==6 and r.speed==0,"recovery preserves checkpoint progress and resets speed")
	var item_set: Dictionary = {}
	game.rng.seed = 481516
	for i: int in range(200):
		item_set[game.roll_item(5)] = true
		item_set[game.roll_item(1)] = true
	expect(item_set.size()==6 and not item_set.has(0),"random boxes can award six item categories including signatures")
	# Run real bot steering against all four geometries without graphics or clock waits.
	for track: int in range(4):
		game.track_id = track
		game._build_track()
		r = pilot(game,1.0)
		game.elapsed = 0.0
		for frame: int in range(15000):
			var control: Dictionary = game._bot_input(r,1.0/60.0)
			game.step_racer(r,control,1.0/60.0)
			game.elapsed += 1.0/60.0
			if r.finish_time>=0:
				break
		expect(r.finish_time>=0,"AI finishes all three legal laps on track "+str(track)+" ("+str(snappedf(game.elapsed,0.1))+" s)")
	# Real scene: split viewports, item pickup respawn, projectile and pause clock.
	game.start([0,3],[0,0],0,2)
	expect(game.views.size()==2 and game.views[0].world_3d==game.views[1].world_3d,"two cameras share the same racing world")
	var w: InputEventKey = InputEventKey.new()
	w.physical_keycode = KEY_J
	w.keycode = KEY_J
	w.pressed = true
	Input.parse_input_event(w)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_KP_1
	up.keycode = KEY_KP_1
	up.pressed = true
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	host.input.update()
	expect(game._human_input(0).throttle==1.0 and game._human_input(1).throttle==1.0,"both players can accelerate simultaneously using independent physical keys")
	var w_release: InputEventKey = w.duplicate()
	w_release.pressed = false
	Input.parse_input_event(w_release)
	Input.flush_buffered_events()
	host.input.update()
	expect(game._human_input(0).throttle==0.0 and game._human_input(1).throttle==1.0,"releasing player one's key leaves player two accelerating")
	var up_release: InputEventKey = up.duplicate()
	up_release.pressed = false
	Input.parse_input_event(up_release)
	var j: InputEventKey = InputEventKey.new()
	j.physical_keycode = KEY_U
	j.keycode = KEY_U
	j.pressed = true
	Input.parse_input_event(j)
	Input.flush_buffered_events()
	host.input.update()
	expect(game._human_input(0).item and not game._human_input(0).item,"holding item key triggers only its first press edge")
	var j_release: InputEventKey = j.duplicate()
	j_release.pressed = false
	Input.parse_input_event(j_release)
	Input.flush_buffered_events()
	host.input.update()
	game.phase = "race"
	game.racers[0].pos = game.boxes[0].pos
	game._update_items(0.016)
	expect(game.racers[0].item>0 and game.boxes[0].cooldown>5,"driving through an item box grants an item and starts respawn")
	r = game.racers[0]
	r.item = 1
	r.pos = Vector2.ZERO
	r.heading = 0.0
	game.racers[1].pos = Vector2(5,0)
	game.use_item(r)
	for frame: int in range(12):
		game._update_items(1.0/60.0)
	expect(game.racers[1].stun>0,"launched pulse hits another racer")
	game.paused = true
	var previous_time: float = game.elapsed
	game._physics_process(1.0)
	expect(game.elapsed==previous_time,"pause stops the entire race timer and simulation")
	game.stop()
	game.queue_free()
	host.queue_free()
	print("KART TESTS: ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
