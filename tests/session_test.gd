extends SceneTree
## Optional native, real-time functional session. Run without --headless (~95 seconds).
## Forces 720p / standard quality (0), with a NO_FOCUS window moved off-screen.
## Bots replace human inputs. This is not a foreground play or thermal benchmark.
## FPS samples are 1 / process delta after the first 500 ms of each segment,
## not Engine.get_frames_per_second(), GPU timings, or input-latency measurements.
## Window focus/visibility, quality, fighters and concurrent system load can differ
## from capture_v2.gd. Record them; do not attribute FPS differences to one cause.
const App=preload("res://scripts/main.gd")
const Profile=preload("res://scripts/save_manager.gd")
var app
var checks=0
var failures=0
var started=0
var samples={}
func _initialize():call_deferred("run")
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("SESSION FAIL: "+label)
	else:print("SESSION PASS: "+label)
func segment(label:String,seconds:float):
	var begin=Time.get_ticks_msec()
	var measurements=[]
	while Time.get_ticks_msec()-begin<seconds*1000:
		await process_frame
		if Time.get_ticks_msec()-begin>500:
			# Render/process cadence is measured separately from 60 Hz simulation.
			measurements.append(1.0/maxf(.001,root.get_process_delta_time()))
	measurements.sort()
	if not measurements.is_empty():
		samples[label]={"frames":measurements.size(),"median":snappedf(measurements[measurements.size()/2],.01),"p05":snappedf(measurements[measurements.size()/20],.01)}
		print("SESSION FPS ",label," ",JSON.stringify(samples[label]))
func fight(ids:Array):
	app.mode="attract"
	app.chosen=ids
	app.start_match()
	app.intro_frames=0
func run():
	started=Time.get_ticks_msec()
	print("SESSION native started ",Time.get_datetime_string_from_system())
	app=App.new()
	app.profile=Profile.new("user://session_test_"+str(OS.get_process_id())+".json")
	root.add_child(app)
	app.profile.data.settings.quality=0
	app.profile.data.settings.resolution=0
	app.profile.data.settings.fullscreen=false
	app.apply_settings()
	# Keep this scripted native validation away from the user's desktop and input.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	app.set_process_input(false)
	app.elapsed_frames=1000
	app.command_capture="session-no-focus-pause"
	fight([13,15])
	await segment("fight_bear_kelvin",15.0)
	check(app.combat.tick_count>400 and app.screen=="fight","Bots avançam combate nativo")
	var baseline_memory=OS.get_static_memory_usage()
	var baseline_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	app.set_screen("pause")
	var fight_clock=app.combat.time_frames
	var fight_tick=app.combat.tick_count
	await segment("fight_paused",2.0)
	check(app.combat.time_frames==fight_clock and app.combat.tick_count==fight_tick,"Pausa de luta congela relógio e simulação")
	app.pause_index=0
	app.tick_pause([{"attack_pressed":true},{}])
	await segment("fight_resumed",10.0)
	check(app.screen=="fight" and app.combat.tick_count!=fight_tick,"Retomar devolve simulação ao combate")
	app.mode="versus"
	app.set_screen("result")
	app.screen_time=1
	app.match_winner=0
	app.result_index=0
	app.tick_result([{"attack_pressed":true},{}])
	check(app.screen=="fight" and app.wins==[0,0] and app.chosen==[13,15],"Revanche recria a mesma partida sem vitórias herdadas")
	app.mode="attract"
	app.intro_frames=0
	await segment("fight_rematch",10.0)
	app.begin_mode("versus")
	app.cursors=[10,12]
	app.tick_select([{"attack_pressed":true},{"attack_pressed":true}])
	check(app.screen=="stage" and app.chosen==[10,12],"Troca de seleção registra os novos lutadores")
	app.set_screen("menu")
	await segment("menu_between_modes",2.0)
	app.chosen=[13,10]
	app.skins=[0,0]
	app.kart_players=2
	app.kart_mode="quick"
	app.stage_cursor=0
	app.tick_kart_stage([{"attack_pressed":true},{}])
	app.kart.phase="race"
	for racer in app.kart.racers:racer.human=false
	await segment("kart_vertical",22.0)
	check(app.kart.views.size()==2 and app.kart.racers.size()==8 and app.kart.elapsed>20,"Kart mantém oito pilotos e duas câmeras durante corrida")
	app.kart.toggle_pause()
	var race_clock=app.kart.elapsed
	var race_position=app.kart.racers[0].pos
	await segment("kart_paused",2.0)
	check(app.kart.elapsed==race_clock and app.kart.racers[0].pos==race_position,"Pausa do kart congela relógio e posição")
	app.kart.toggle_pause()
	await segment("kart_resumed",3.0)
	check(app.kart.elapsed>race_clock and app.kart.racers[0].pos!=race_position,"Retomar kart restaura corrida")
	app.kart.horizontal_split=true
	app.kart.restart()
	app.kart.phase="race"
	for racer in app.kart.racers:racer.human=false
	await segment("kart_horizontal_restart",15.0)
	check(app.kart.views.size()==2 and app.kart.horizontal_split and app.kart.elapsed>14,"Reinício reconstrói dois viewports horizontais")
	app._exit_kart()
	await segment("menu_after_kart",2.0)
	check(not app.kart.active and app.kart.layer==null and app.kart.racers.is_empty() and app.kart.cameras.is_empty(),"Sair do kart libera mundo, câmeras e pilotos")
	fight([10,12])
	await segment("fight_after_kart",10.0)
	check(app.screen=="fight" and app.combat.tick_count>400 and app.combat.fighters[0].id==10,"Combate continua após alternar kart e menus")
	print("SESSION memory static start=",baseline_memory," end=",OS.get_static_memory_usage()," nodes start=",baseline_nodes," end=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," orphans=",Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	app.set_physics_process(false)
	await app.sound.shutdown()
	app.queue_free()
	await process_frame
	await process_frame
	print("SESSION complete duration_seconds=",snappedf((Time.get_ticks_msec()-started)/1000.0,.01)," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
