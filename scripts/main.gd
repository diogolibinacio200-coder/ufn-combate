extends Node2D
## Flow coordinator. Combat, input, presentation and persistence are independent.
const Combat = preload("res://scripts/combat.gd")
const Inputs = preload("res://scripts/input_manager.gd")
const Profile = preload("res://scripts/save_manager.gd")
const Sound = preload("res://scripts/audio_manager.gd")
const Arena = preload("res://scripts/arena_view.gd")
const UI = preload("res://scripts/interface.gd")
const AI = preload("res://scripts/ai.gd")
const STAGES = ["PÁTIO DA UFN","ESPAÇO CONTAINER","RUA DE SANTA MARIA","ENTRADA DA UFN","QUADRA UNIVERSITÁRIA","LABORATÓRIO TECNOLÓGICO","CORREDOR UNIVERSITÁRIO","VILA BELGA"]
const STAGE_SUB = ["Convivência, vegetação e arquitetura franciscana","Encontro entre aulas, ideias e histórias","Santa Maria • coração do Rio Grande do Sul","O campus recebe mais um desafio","Esporte, torcida e espírito de equipe","Tecnologia e imaginação em movimento","Entre aulas e ideias · interpretação temática","Casas históricas e fachadas coloridas"]
const CATALOG = preload("res://scripts/move_db.gd")
const PLAYABLE = CATALOG.PLAYABLE
const MENU = ["ARCADE","TORRE UFN","VERSUS LOCAL","DUPLAS 2v2","KART UFN","TREINAMENTO","TUTORIAL","TORNEIO LOCAL","SOBREVIVÊNCIA","GALERIA","ESTATÍSTICAS","CONFIGURAÇÕES","CONTROLES","CRÉDITOS","SAIR"]
const KART_TRACKS = ["CIRCUITO DO CAMPUS","VOLTA DA VILA BELGA","CENTRO DE SANTA MARIA","DESAFIO UNIVERSITÁRIO"]
const Kart = preload("res://scripts/kart.gd")
const TRAIN_OPTIONS = ["ADVERSÁRIO DE TREINO", "VIDA INFINITA", "ENERGIA INFINITA", "GUARDA INFINITA", "HITBOXES", "ADVERSÁRIO", "RESET DE POSIÇÃO", "VOLTAR"]
const DIFFICULTIES = ["FÁCIL", "NORMAL", "DIFÍCIL", "EXTREMA"]
var input = Inputs.new()
var profile = Profile.new()
var sound = Sound.new()
var combat = Combat.new()
var arena = Arena.new()
var ui = UI.new()
var bots = [AI.new(1047), AI.new(2048)]
var screen = "boot"
var screen_time = 0.0
var clock_time = 0.0
var idle_frames = 0
var menu_index = 1
var mode = "versus"
var cursors = [0, 3]
var chosen = [0, 3]
var reserves = [3,0]
var skins = [0,0]
var reserve_skins = [0,0]
var selection_phase = 0
var kart = Kart.new()
var ready_players = [false, false]
var stage = 0
var stage_cursor = 0
var wins = [0, 0]
var round_number = 1
var result_index = 0
var pause_index = 0
var settings_index = 0
var help_page = 0
var previous_screen = "menu"
var controls_player = 0
var controls_kart=false
var controls_index = 0
var capturing_binding = false
var binding_capture_wait_release = false
var shutting_down = false
var controls_actions = ["up", "down", "left", "right", "attack", "heavy", "kick", "block"]
var toast = ""
var toast_timer = 0.0
var escape_pressed = false
var enter_pressed = false
var tab_pressed = false
var reset_pressed = false
var debug_pressed = false
var any_pressed = false
var debug_view = false
var match_winner = -1
var round_end_timer = 0
var intro_frames = 0
var notices: Array = []
var input_history = [[], []]
var tutorial = false
var tutorial_step = 0
var tutorial_hits = 0
var tutorial_move_start = 0.0
var tutorial_done = false
var train_options = {"dummy": 0, "health": true, "meter": true, "guard": false, "boxes": false}
var train_index = 0
var arcade_order: Array = []
var arcade_index = 0
var tournament_roster: Array = []
var tournament_winners: Array = []
var tournament_round = 0
var tournament_cursor = 0
var tutorial_last_step = -1
var ai_frame = 0
var command_capture = ""
var command_screen = ""
var command_quit = 0
var elapsed_frames = 0
var music_context = ""
var setup_kind = "versus"
var setup_index = 0
var local_cpu = false
var tournament_size = 4
var tournament_cpu: Array = []
var entry_cpu = false
var bracket_current: Array = []
var bracket_next: Array = []
var bracket_match = 0
var tournament_pair: Array = []
var survival_wave = 0
var survival_score = 0
var survival_health = 1000.0
var kart_mode = "quick"
var kart_players = 2
var gallery_index = 0
var gallery_tab = 0
var settings_page = 0
var settings_entries = ["GERAL","MÚSICA","EFEITOS","VOZES","TELA CHEIA","RESOLUÇÃO","QUALIDADE","TREMOR","FLASHES","PARTÍCULAS","LEGENDAS","TEXTO","DIFICULDADE","ACELERAÇÃO AUTO","DIVISÃO HORIZONTAL","CONTROLES","RESTAURAR","VOLTAR"]
var event_counts = {"perfect_blocks":0, "guard_breaks":0, "supers":0, "biggest_combo":0}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	profile.load_profile()
	Input.joy_connection_changed.connect(_controller_changed)
	input.load_bindings(profile.data.get("bindings", {}))
	add_child(sound)
	add_child(arena)
	add_child(ui)
	add_child(kart)
	kart.setup(self)
	kart.exit_requested.connect(_exit_kart)
	kart.race_finished.connect(_kart_finished)
	ui.app = self
	arena.z_index = 0
	ui.z_index = 10
	apply_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			command_capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--screen="):
			command_screen = arg.trim_prefix("--screen=")
		if arg.begins_with("--quit-after="):
			command_quit = int(arg.trim_prefix("--quit-after="))
		if arg == "--windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280,720))
	if not command_screen.is_empty():
		set_screen(command_screen)
		if command_screen in ["fight", "pause", "training_menu", "result"]:
			start_match()
			intro_frames = 0
			set_screen(command_screen)
			combat.fighters[0].meter = 76
			combat.fighters[1].meter = 43
			combat.fighters[0].x = 445
			combat.fighters[1].x = 835
		if command_screen == "result":
			match_winner = 0
		if command_screen == "select":
			ready_players = [false,false]
	if command_screen=="tower":
		mode="tower";chosen=[3,0];arcade_order=[0,1,2,4,5,6,10,13,14,15];arcade_index=8;chosen[1]=14;set_screen("tower")
	if command_screen=="kart":
		kart.start([10,13],[0,0],0,2)
	if command_screen=="bear":
		chosen=[13,15];start_match();intro_frames=0;combat.fighters[0].x=410;combat.fighters[1].x=790;combat.fighters[0].meter=100;stage=7
	play_music("menu")

func apply_settings() -> void:
	var s: Dictionary = profile.data.settings
	sound.voice_level=float(s.voice)*float(s.master)
	sound.set_levels(float(s.music)*float(s.master), float(s.sfx)*float(s.master))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not s.fullscreen:
		DisplayServer.window_set_size(Vector2i(1280,720) if int(s.resolution) == 0 else Vector2i(1920,1080))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.set("shake_strength", float(s.shake))
	arena.set("flash_strength", float(s.flashes))
	arena.particle_intensity=float(s.particles)
	ui.text_scale=1.0 if int(s.text_size)==0 else 1.08

func persist() -> void:
	profile.data.bindings = input.export_bindings()
	profile.save_profile()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "fight" and mode != "attract" and command_capture.is_empty():
		pause_index = 0
		set_screen("pause")

func _input(event: InputEvent) -> void:
	if shutting_down or screen == "kart": return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_navigation(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		any_pressed = true
		if capturing_binding:
			if event.physical_keycode != KEY_ESCAPE:
				if input.set_binding(controls_player, controls_actions[controls_index], event.physical_keycode,controls_kart):
					persist()
					show_toast("COMANDO SALVO")
				else: show_toast("TECLA RESERVADA AO SISTEMA")
			finish_binding_capture()
			return
		escape_pressed = event.physical_keycode == KEY_ESCAPE or escape_pressed
		if event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and screen in ["fight","pause"]:
			escape_pressed = true
			return
		enter_pressed = event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] or enter_pressed
		tab_pressed = event.physical_keycode == KEY_TAB or tab_pressed
		reset_pressed = event.physical_keycode == KEY_F2 or reset_pressed
		debug_pressed = event.physical_keycode == KEY_F3 or debug_pressed
		if event.physical_keycode == KEY_F2 and screen == "controls":
			input.use_laptop_profile()
			persist()
			show_toast("PERFIL SEM NUMÉRICO ATIVO")
		if event.physical_keycode == KEY_F11:
			profile.data.settings.fullscreen = not profile.data.settings.fullscreen
			apply_settings()
			persist()
	if event is InputEventJoypadButton and event.pressed:
		any_pressed = true
		if capturing_binding:
			if event.button_index != JOY_BUTTON_BACK:
				if input.set_gamepad_binding(controls_player,controls_actions[controls_index],event.button_index,event.device,controls_kart):
					persist()
					show_toast("CONTROLE ARCADE SALVO")
				else: show_toast("BOTÃO RESERVADO AO SISTEMA")
			finish_binding_capture()
			return
		if event.button_index == JOY_BUTTON_START:
			if screen in ["fight","pause"]:
				escape_pressed = true
			else:
				enter_pressed = true
		if event.button_index == JOY_BUTTON_BACK:
			escape_pressed = true

func finish_binding_capture() -> void:
	capturing_binding = false
	binding_capture_wait_release = true
	escape_pressed = false
	enter_pressed = false
	any_pressed = false
	get_viewport().set_input_as_handled()

func quit_game() -> void:
	if shutting_down: return
	shutting_down = true
	persist()
	await sound.shutdown()
	get_tree().quit()

func _process(delta: float) -> void:
	clock_time += delta
	screen_time += delta
	toast_timer = maxf(0.0, toast_timer-delta)
	for n in notices:
		n.age += delta
	notices = notices.filter(func(n): return n.age < 1.3)
	arena.visible = screen in ["boot", "menu", "select", "stage", "vs", "fight", "pause", "result", "ending", "training_menu", "tournament", "tournament_result"]
	arena.stage_id = stage
	arena.paused = screen in ["pause", "training_menu"]
	arena.combat = combat if screen in ["fight", "pause", "result", "training_menu"] else null
	arena.alternate = [false, chosen[0] == chosen[1]]
	if combat.fighters.size() == 2:
		for i in 2:
			combat.fighters[i].skin = skins[i] if not combat.team_mode or combat.team_active[i] == 0 else reserve_skins[i]
	arena.debug = debug_view or (mode == "training" and train_options.boxes)
	ui.queue_redraw()

func _physics_process(_delta: float) -> void:
	if shutting_down: return
	elapsed_frames += 1
	input.update()
	var p: Array = [input.sample(0), input.sample(1)]
	var active_input = any_pressed
	for commands in p:
		for key in commands:
			if key.ends_with("_pressed") and commands[key]:
				active_input = true
	if active_input:
		idle_frames = 0
	else:
		idle_frames += 1
	if screen == "boot" and (screen_time > 1.6 or active_input):
		set_screen("menu")
	elif screen == "menu":
		tick_menu(p)
	elif screen == "setup":
		tick_setup(p)
	elif screen == "tower":
		if confirm(p,0):set_screen("vs")
		elif escape_pressed:set_screen("menu")
	elif screen == "gallery":
		tick_gallery(p)
	elif screen == "select":
		tick_select(p)
	elif screen == "stage":
		tick_stage(p)
	elif screen == "kart_stage":
		tick_kart_stage(p)
	elif screen == "vs":
		if screen_time > 3.4 or confirm(p,0) or confirm(p,1):
			start_match()
	elif screen == "fight":
		tick_fight(p, active_input)
	elif screen == "pause":
		tick_pause(p)
	elif screen == "result":
		tick_result(p)
	elif screen == "settings":
		tick_settings(p)
	elif screen == "controls":
		tick_controls(p)
	elif screen == "help":
		tick_help(p)
	elif screen == "training_menu":
		tick_training_menu(p)
	elif screen == "tournament":
		tick_tournament(p)
	elif screen == "tournament_result":
		if confirm(p,0) or confirm(p,1):
			if bracket_current.size()==1:
				set_screen("menu")
			else:
				prepare_tournament_match()
	elif screen == "ending":
		if screen_time > 1 and (confirm(p,0) or escape_pressed):
			set_screen("menu")
	elif screen in ["stats", "credits"]:
		if confirm(p,0) or confirm(p,1) or escape_pressed:
			set_screen("menu")
	if debug_pressed and screen == "fight":
		debug_view = not debug_view
	escape_pressed = false
	enter_pressed = false
	tab_pressed = false
	reset_pressed = false
	debug_pressed = false
	any_pressed = false
	if not command_capture.is_empty() and elapsed_frames == 150:
		capture_frame.call_deferred()
	if command_quit > 0 and elapsed_frames > command_quit:
		quit_game()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var shot = get_viewport().get_texture().get_image()
	shot.save_png(command_capture)
	print("SCREENSHOT: " + command_capture)

func set_screen(next: String) -> void:
	screen = next
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if next in ["fight","kart","vs"] else Input.MOUSE_MODE_VISIBLE
	screen_time = 0.0
	idle_frames = 0
	match next:
		"menu": play_music("menu")
		"select", "stage", "tournament": play_music("selection")
		"vs": play_music("vs")
		"fight": play_music("arena")
		"result", "ending", "tournament_result": play_music("victory")

func play_music(context: String) -> void:
	if music_context != context or context == "arena":
		sound.music(context, stage)
		music_context = context

func show_toast(text: String) -> void:
	toast = text
	toast_timer = 2.0

func confirm(p: Array, player: int) -> bool:
	return bool(p[player].get("attack_pressed", false)) or (enter_pressed and player == 0)

func axis(p: Array, horizontal: bool = false, player: int = -1) -> int:
	var value = 0
	for i in range(2):
		if player >= 0 and i != player:
			continue
		value += int(p[i].get("right_pressed" if horizontal else "down_pressed", false))
		value -= int(p[i].get("left_pressed" if horizontal else "up_pressed", false))
	return clampi(value, -1, 1)

func navigate(index: int, direction: int, count: int) -> int:
	if direction != 0:
		sound.play("select")
	return posmod(index+direction, count)

func tick_menu(p: Array) -> void:
	menu_index=navigate(menu_index,axis(p),MENU.size())
	if not (confirm(p,0) or confirm(p,1)):return
	sound.play("confirm")
	match menu_index:
		0:begin_mode("arcade")
		1:open_setup("tower") if not profile.data.progress.tower.is_empty() else begin_mode("tower")
		2:open_setup("versus")
		3:begin_mode("teams")
		4:open_setup("kart")
		5:begin_mode("training")
		6:start_tutorial()
		7:open_setup("tournament")
		8:begin_mode("survival")
		9:gallery_index=0;gallery_tab=0;set_screen("gallery")
		10:set_screen("stats")
		11:settings_index=0;set_screen("settings")
		12:previous_screen="menu";controls_index=0;set_screen("controls")
		13:set_screen("credits")
		14:quit_game()

func begin_mode(next_mode: String) -> void:
	mode=next_mode
	tutorial=false
	selection_phase=0
	chosen[0]=clampi(chosen[0],0,PLAYABLE-1)
	chosen[1]=clampi(chosen[1],0,PLAYABLE-1)
	cursors=chosen.duplicate()
	ready_players=[false,solo_selection()]
	if mode=="survival":survival_wave=0;survival_score=0;survival_health=1000
	set_screen("select")

func solo_selection() -> bool:
	return mode in ["arcade","tower","training","survival"] or (mode=="kart" and kart_players==1)

func tick_select(p: Array) -> void:
	if escape_pressed:set_screen("menu");return
	for i in 2:
		if i==1 and solo_selection():continue
		if p[i].get("block_pressed",false):
			if ready_players[i]:ready_players[i]=false
			elif selection_phase>0:selection_phase=0;ready_players=[false,false];cursors=chosen.duplicate()
			else:set_screen("menu")
			return
		if ready_players[i]:continue
		var direction=axis(p,true,i)+axis(p,false,i)*7
		cursors[i]=navigate(cursors[i],direction,PLAYABLE)
		if cursors[i]==3 and p[i].get("heavy_pressed",false):
			if selection_phase==0:skins[i]=1-skins[i]
			else:reserve_skins[i]=1-reserve_skins[i]
			sound.play("select")
		if confirm(p,i):
			if selection_phase==1 and chosen[i]==cursors[i]:show_toast("ESCOLHA UM PARCEIRO DIFERENTE");continue
			if selection_phase==0:chosen[i]=cursors[i]
			else:reserves[i]=cursors[i]
			ready_players[i]=true
			sound.play("confirm")
	if not (ready_players[0] and ready_players[1]):return
	if mode=="teams" and selection_phase==0:
		selection_phase=1;cursors=reserves.duplicate();ready_players=[false,false];return
	if mode in ["arcade","tower"]:
		arcade_order=[]
		for i in PLAYABLE:
			if i!=chosen[0]:arcade_order.append(i)
		arcade_order.shuffle();arcade_order.resize(8);arcade_order.append_array([14,15]);arcade_index=0
		chosen[1]=arcade_order[0]
		if mode=="tower":save_tower();set_screen("tower");return
	if mode in ["training","survival"]:chosen[1]=(chosen[0]+1)%PLAYABLE
	stage_cursor=stage
	set_screen("kart_stage" if mode=="kart" else "stage")

func tick_kart_stage(p: Array) -> void:
	if escape_pressed:set_screen("setup");setup_kind="kart";return
	stage_cursor=navigate(stage_cursor,axis(p,true)+axis(p)*2,KART_TRACKS.size())
	if confirm(p,0) or confirm(p,1):
		set_screen("kart")
		kart.tutorial_mode=false
		kart.championship_points={}
		kart.race_mode=kart_mode
		kart.horizontal_split=profile.data.settings.split_horizontal
		kart.auto_accelerate=profile.data.settings.auto_accelerate
		kart.difficulty=int(profile.data.settings.difficulty)
		kart.start(chosen,skins,0 if kart_mode=="championship" else stage_cursor,kart_players)

func _exit_kart() -> void:
	persist()
	kart.stop()
	set_screen("menu")

func tick_stage(p: Array) -> void:
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		ready_players[0] = false
		ready_players[1] = solo_selection()
		set_screen("select")
		return
	var direction = axis(p,true)
	if axis(p) != 0: direction = axis(p)*4
	stage_cursor = navigate(stage_cursor,direction,STAGES.size()+1)
	stage = stage_cursor if stage_cursor < STAGES.size() else int(clock_time)%STAGES.size()
	if confirm(p,0) or confirm(p,1):
		if stage_cursor == STAGES.size(): stage = randi_range(0,STAGES.size()-1)
		sound.play("confirm")
		set_screen("vs")

func start_match() -> void:
	wins = [0,0]
	round_number = 1
	match_winner = -1
	combat.difficulty=int(profile.data.settings.difficulty)
	combat.setup(chosen,mode == "training",reserves if mode == "teams" else [])
	apply_fighter_skins()
	if mode=="survival":combat.fighters[0].hp=survival_health
	for key in event_counts: event_counts[key] = 0
	input_history = [[],[]]
	notices.clear()
	intro_frames = 200
	round_end_timer = 0
	set_screen("fight")
	if mode == "training":
		if tutorial:combat.setup(chosen,true,[3,1])
		intro_frames = 0
		reset_training()
	if mode == "attract": intro_frames = 65
	sound.play("round_one")

func start_round() -> void:
	combat.reset_round()
	apply_fighter_skins()
	intro_frames = 120
	round_end_timer = 0
	notices.clear()
	input_history = [[],[]]
	sound.play("final_round" if is_final_round() else "round_two")

func is_final_round() -> bool:
	var required_wins: int = 2
	return wins[0] == required_wins-1 and wins[1] == required_wins-1

func tick_fight(p: Array, active: bool) -> void:
	if mode == "attract" and active:
		mode = "versus"
		set_screen("menu")
		return
	if escape_pressed and mode != "attract":
		pause_index = 0
		set_screen("pause")
		return
	if mode == "training" and tab_pressed:
		train_index = 0
		set_screen("training_menu")
		return
	if mode == "training" and reset_pressed:
		reset_training()
	if tutorial and tutorial_step==9 and confirm(p,0):
		kart.tutorial_mode=true;kart.race_mode="quick";kart.horizontal_split=false;kart.auto_accelerate=false;kart.difficulty=0
		set_screen("kart");kart.start([chosen[0]],[],0,1);return
	if intro_frames > 0:
		intro_frames -= 1
		if (confirm(p,0) or confirm(p,1)) and intro_frames > 65:
			intro_frames = 65
		if intro_frames == 60: sound.play("fight")
		return
	if round_end_timer > 0:
		round_end_timer -= 1
		if round_end_timer == 0:
			resolve_round()
		return
	if mode in ["arcade","tower","survival"] or (mode=="versus" and local_cpu):p[1]=bots[1].think(combat,1,int(profile.data.settings.difficulty))
	if mode=="tournament":
		for i in 2:
			if tournament_cpu[tournament_pair[i]]:p[i]=bots[i].think(combat,i,int(profile.data.settings.difficulty))
	if mode == "attract":
		p[0] = bots[0].think(combat,0,3)
		p[1] = bots[1].think(combat,1,2)
	if mode == "training":
		sync_training_options()
		p[1] = dummy_input()
		if train_options.guard:
			combat.fighters[0].guard = 100.0
			combat.fighters[1].guard = 100.0
		combat.time_frames = 99*60
	for i in range(2): record_input(i,p[i])
	var tutorial_step_before_tick: int = tutorial_step
	combat.tick(p)
	consume_combat_events()
	if mode == "training":
		if tutorial and tutorial_step==tutorial_step_before_tick: tick_tutorial()
		if combat.winner >= 0 or (not combat.cinematic.active and not train_options.health and (combat.fighters[0].hp <= 0 or combat.fighters[1].hp <= 0)):
			show_toast("K.O. • TREINO REINICIADO")
			reset_training()
	elif combat.winner >= 0:
		round_end_timer = 155
		sound.play("ko")
		if combat.winner < 2:
			var winner: Dictionary = combat.fighters[combat.winner]
			if winner.hp >= 1000:
				add_notice("VITÓRIA PERFEITA",combat.winner)
				sound.play("perfect")
			elif winner.hp < 180:
				add_notice("VIRADA",combat.winner)

func record_input(player: int, commands: Dictionary) -> void:
	var keys: Array = []
	var labels = {"up":"↑", "down":"↓", "left":"←", "right":"→", "block":"D", "attack":"A1", "heavy":"A2", "kick":"A3"}
	var action_edge: bool = commands.get("attack_pressed",false) or commands.get("heavy_pressed",false) or commands.get("kick_pressed",false)
	for k in labels:
		if commands.get(k+"_pressed",false) or (k=="block" and action_edge and commands.get("block",false)):
			keys.append(labels[k])
	if keys.is_empty(): return
	input_history[player].push_front(" + ".join(keys))
	if input_history[player].size() > 7: input_history[player].pop_back()

func consume_combat_events() -> void:
	arena.ingest_events(combat.events)
	var step_at_start: int = tutorial_step
	for e in combat.events:
		var kind = str(e.get("type","hit"))
		sound.play(kind,int(combat.fighters[int(e.get("player",0))].id))
		if profile.data.settings.subtitles and kind in ["perfect_block","parry","counter","guard_break","throw_break","super","no_meter","tag","buff"]:
			add_notice(e.get("text",kind.to_upper().replace("_"," ")),int(e.get("player",0)))
		if kind == "perfect_block": event_counts.perfect_blocks += 1
		if kind == "guard_break": event_counts.guard_breaks += 1
		if kind == "super": event_counts.supers += 1
		if tutorial:
			if step_at_start == 1 and kind == "hit" and int(e.get("player",-1)) == 0: tutorial_hits += 1
			if step_at_start == tutorial_step:
				if step_at_start == 2 and kind in ["block","perfect_block","parry"] and int(e.get("player",-1)) == 0 and not combat.fighters[0].last_input.get("down",false): advance_tutorial()
				elif step_at_start == 3 and kind in ["block","perfect_block","parry"] and int(e.get("player",-1)) == 0 and combat.fighters[0].last_input.get("down",false): advance_tutorial()
				elif step_at_start == 4 and kind == "throw" and int(e.get("player",-1)) == 0: advance_tutorial()
				elif step_at_start == 5 and kind in ["projectile","special"] and int(e.get("player",-1)) == 0: advance_tutorial()
				elif step_at_start == 7 and kind == "super" and int(e.get("player",-1)) == 0: advance_tutorial()
				elif step_at_start == 8 and kind == "tag" and int(e.get("player",-1)) == 0: advance_tutorial()
	for f in combat.fighters:
		event_counts.biggest_combo = maxi(event_counts.biggest_combo,int(f.combo))

func add_notice(text: String, player: int) -> void:
	notices.append({"text":text,"player":player,"age":0.0})
	if notices.size() > 6: notices.pop_front()

func resolve_round() -> void:
	if combat.winner < 0: return
	if combat.winner < 2:
		wins[combat.winner] += 1
	var goal_rounds: int = 1 if mode=="survival" else 2
	if wins[0] >= goal_rounds or wins[1] >= goal_rounds:
		match_winner = 0 if wins[0] > wins[1] else 1
		if mode == "attract":
			chosen = [randi_range(0,PLAYABLE-1), randi_range(0,PLAYABLE-1)]
			stage = (stage+1)%STAGES.size()
			start_match()
			return
		if mode=="survival" and match_winner==0:
			survival_health=minf(1000,combat.fighters[0].hp+180)
			survival_score+=1000+int(combat.fighters[0].hp)+ceili(combat.time_frames/60.0)*10
		save_match()
		if mode=="tower":save_tower()
		result_index = 0
		sound.play("player_one_wins" if match_winner == 0 else "player_two_wins")
		set_screen("result")
	else:
		round_number += 1
		start_round()

func save_match() -> void:
	var stats: Dictionary = profile.data.stats
	stats.matches = int(stats.get("matches",0))+1
	var win_key = "p1_wins" if match_winner == 0 else "p2_wins"
	stats[win_key] = int(stats.get(win_key,0))+1
	var played: Dictionary = stats.get("most_played",{})
	for fighter_id in chosen:
		var key = str(fighter_id)
		played[key] = int(played.get(key,0))+1
	stats.most_played = played
	for key in ["perfect_blocks","guard_breaks","supers"]:
		stats[key] = int(stats.get(key,0))+event_counts[key]
	stats.biggest_combo = maxi(int(stats.get("biggest_combo",0)),event_counts.biggest_combo)
	unlock("PRIMEIRO CONFRONTO")
	if event_counts.biggest_combo>=5:unlock("CINCO ACERTOS")
	if mode=="survival":profile.data.progress.records.survival=maxi(int(profile.data.progress.records.get("survival",0)),survival_score)
	persist()

func result_options() -> Array:
	if mode=="tower":return ["AVANÇAR" if match_winner==0 else "TENTAR NOVAMENTE","REINICIAR TORRE","MENU PRINCIPAL"]
	if mode=="arcade":return ["AVANÇAR" if match_winner==0 else "TENTAR NOVAMENTE","MENU PRINCIPAL"]
	if mode=="survival":return ["PRÓXIMO RIVAL" if match_winner==0 else "NOVA SOBREVIVÊNCIA","MENU PRINCIPAL"]
	if mode=="tournament":return ["VER CHAVEAMENTO","MENU PRINCIPAL"]
	return ["REVANCHE","SELECIONAR LUTADORES","MENU PRINCIPAL"]

func tick_result(p: Array) -> void:
	if screen_time<.5:return
	var options=result_options()
	result_index=navigate(result_index,axis(p),options.size())
	if escape_pressed:set_screen("menu");return
	if not (confirm(p,0) or confirm(p,1)):return
	match options[result_index]:
		"REVANCHE","TENTAR NOVAMENTE":start_match()
		"SELECIONAR LUTADORES":begin_mode(mode)
		"MENU PRINCIPAL":set_screen("menu")
		"REINICIAR TORRE":begin_mode("tower")
		"NOVA SOBREVIVÊNCIA":begin_mode("survival")
		"AVANÇAR":
			arcade_index+=1
			if arcade_index>=arcade_order.size():
				if mode=="tower":
					profile.data.progress.tower={}
					profile.data.progress.records["torre_"+str(profile.data.settings.difficulty)]=true
				unlock("CAMPEÃO DA TORRE")
				persist();set_screen("ending")
			else:
				chosen[1]=arcade_order[arcade_index];stage=(stage+1)%STAGES.size()
				if mode=="tower":save_tower()
				set_screen("tower" if mode=="tower" else "vs")
		"PRÓXIMO RIVAL":
			survival_wave+=1
			chosen[1]=posmod(chosen[1]+3,PLAYABLE)
			if chosen[1]==chosen[0]:chosen[1]=(chosen[1]+1)%PLAYABLE
			profile.data.progress.records.survival=maxi(int(profile.data.progress.records.get("survival",0)),survival_score)
			persist();set_screen("vs")
		"VER CHAVEAMENTO":
			var slot=tournament_pair[match_winner]
			bracket_next.append(slot);tournament_winners.append(chosen[match_winner]);bracket_match+=1;tournament_round+=1
			if bracket_match>=bracket_current.size()/2:bracket_current=bracket_next.duplicate();bracket_next=[];bracket_match=0
			set_screen("tournament_result")

func tick_pause(p: Array) -> void:
	var options = ["CONTINUAR", "CONTROLES", "LISTA DE GOLPES", "REINICIAR PARTIDA", "SELEÇÃO", "MENU PRINCIPAL"]
	if mode == "training": options.insert(3,"OPÇÕES DE TREINO")
	pause_index = navigate(pause_index,axis(p),options.size())
	if escape_pressed: set_screen("fight")
	if confirm(p,0) or confirm(p,1):
		match options[pause_index]:
			"CONTINUAR": set_screen("fight")
			"CONTROLES":
				previous_screen = "pause"
				controls_index = 0
				set_screen("controls")
			"LISTA DE GOLPES":
				previous_screen = "pause"
				help_page = 2+chosen[0]
				set_screen("help")
			"REINICIAR PARTIDA": start_match()
			"SELEÇÃO": begin_mode(mode)
			"MENU PRINCIPAL": set_screen("menu")
			"OPÇÕES DE TREINO": set_screen("training_menu")

func tick_settings(p: Array) -> void:
	if escape_pressed:set_screen("menu");return
	settings_index=navigate(settings_index,axis(p),settings_entries.size())
	var direction=axis(p,true)
	if confirm(p,0) or confirm(p,1):direction=1
	if direction==0:return
	var s:Dictionary=profile.data.settings
	var key=["master","music","sfx","voice","fullscreen","resolution","quality","shake","flashes","particles","subtitles","text_size","difficulty","auto_accelerate","split_horizontal","controls","reset","back"][settings_index]
	if key in ["master","music","sfx","voice","shake","flashes","particles"]:s[key]=clampf(float(s[key])+direction*.1,0,1)
	elif key in ["fullscreen","subtitles","auto_accelerate","split_horizontal"]:s[key]=not s[key]
	elif key in ["resolution","quality","text_size"]:s[key]=posmod(int(s[key])+direction,2)
	elif key=="difficulty":s.difficulty=posmod(int(s.difficulty)+direction,4)
	elif key=="controls":previous_screen="settings";controls_index=0;set_screen("controls")
	elif key=="reset":profile.data.settings=profile.defaults().settings;show_toast("CONFIGURAÇÕES RESTAURADAS")
	else:set_screen("menu")
	apply_settings();persist()

func tick_controls(p: Array) -> void:
	if capturing_binding: return
	if binding_capture_wait_release:
		for commands in p:
			for action in controls_actions:
				if commands.get(action,false): return
		binding_capture_wait_release = false
		return
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen(previous_screen)
		return
	controls_player = posmod(controls_player+axis(p,true),2)
	controls_index = navigate(controls_index,axis(p),controls_actions.size()+7)
	if confirm(p,0) or confirm(p,1):
		if controls_index < controls_actions.size():
			capturing_binding = true
		elif controls_index == controls_actions.size():
			input.defaults()
			persist()
			show_toast("CONTROLES RESTAURADOS")
		elif controls_index==controls_actions.size()+1:input.use_laptop_profile();persist();show_toast("PERFIL SEM NUMÉRICO ATIVO")
		elif controls_index==controls_actions.size()+2:
			var options=["auto","keyboard","pad"]
			input.devices[controls_player]=options[(options.find(input.devices[controls_player])+1)%3];persist()
		elif controls_index==controls_actions.size()+3:
			var pads=Input.get_connected_joypads()
			if not pads.is_empty():input.set_gamepad_device(controls_player,pads[(pads.find(input.gamepads[controls_player].device)+1)%pads.size()]);persist()
		elif controls_index==controls_actions.size()+4:controls_kart=not controls_kart
		elif controls_index==controls_actions.size()+5:help_page=0;set_screen("help")
		else:set_screen(previous_screen)
	if escape_pressed:set_screen(previous_screen)

func tick_help(p: Array) -> void:
	help_page = navigate(help_page,axis(p,true),2+CATALOG.ROSTER.size())
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen(previous_screen)
	if confirm(p,0) and previous_screen == "menu":
		start_tutorial()

func tick_training_menu(p: Array) -> void:
	if escape_pressed or tab_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen("fight")
		return
	train_index = navigate(train_index,axis(p),TRAIN_OPTIONS.size())
	var direction = axis(p,true)
	if confirm(p,0): direction = 1
	if direction != 0:
		match train_index:
			0: train_options.dummy = posmod(int(train_options.dummy)+direction,5)
			1: train_options.health = not train_options.health
			2: train_options.meter = not train_options.meter
			3: train_options.guard = not train_options.guard
			4: train_options.boxes = not train_options.boxes
			5:chosen[1]=posmod(chosen[1]+direction,CATALOG.ROSTER.size());combat.setup(chosen,true);reset_training()
			6:reset_training()
			7:set_screen("fight")
	if escape_pressed or tab_pressed: set_screen("fight")

func reset_training() -> void:
	combat.reset_round()
	sync_training_options()
	if train_options.meter:
		for f in combat.fighters: f.meter = 100.0
	tutorial_move_start = combat.fighters[0].x
	input_history = [[],[]]

func sync_training_options() -> void:
	combat.training_options.infinite_health = bool(train_options.health)
	combat.training_options.infinite_meter = bool(train_options.meter)

func dummy_input() -> Dictionary:
	ai_frame += 1
	var behavior: int = train_options.dummy
	if tutorial:
		if tutorial_step in [2,3]: behavior = 3
		elif tutorial_step == 4: behavior = 0
		else: behavior = 0
	var commands: Dictionary = {}
	match behavior:
		1: commands = {"block":true,"down":true}
		2: commands = {"up":true,"up_pressed":ai_frame%45 == 0}
		3:
			var dist = combat.fighters[0].x-combat.fighters[1].x
			commands = {"left":dist < -100,"right":dist > 100,"attack":ai_frame%70 == 0,"attack_pressed":ai_frame%70 == 0}
		4: commands = bots[1].think(combat,1,int(profile.data.settings.difficulty))
	return commands

func tick_tutorial() -> void:
	if tutorial_done: return
	match tutorial_step:
		0:
			if absf(combat.fighters[0].x-tutorial_move_start) > 130: advance_tutorial()
		1:
			if tutorial_hits >= 3: advance_tutorial()
		5:
			var move: Dictionary = combat.fighters[0].move
			if not move.is_empty() and move.get("cost",0)>0 and move.get("family","")!="super": advance_tutorial()
		6:
			if combat.fighters[0].combo >= 2: advance_tutorial()

func advance_tutorial() -> void:
	if tutorial_step >= 9: return
	tutorial_step += 1
	sound.play("confirm")
	show_toast("ETAPA CONCLUÍDA")
	if tutorial_step >= 9: tutorial_done = true
	if tutorial_step==6:
		combat.fighters[0].combo=0
		combat.fighters[0].combo_timer=0
	if tutorial_step==8:combat.tag_cooldowns[0]=0

func tick_tournament(p: Array) -> void:
	if escape_pressed:set_screen("menu");return
	tournament_cursor=navigate(tournament_cursor,axis(p,true),PLAYABLE)
	if p[0].get("heavy_pressed",false) or p[1].get("heavy_pressed",false):entry_cpu=not entry_cpu
	if confirm(p,0) or confirm(p,1):
		tournament_roster.append(tournament_cursor);tournament_cpu.append(entry_cpu);tournament_cursor=(tournament_cursor+1)%PLAYABLE;sound.play("confirm")
		if tournament_roster.size()==tournament_size:
			bracket_current=range(tournament_size);bracket_next=[];bracket_match=0;prepare_tournament_match()

func prepare_tournament_match() -> void:
	tournament_pair=[bracket_current[bracket_match*2],bracket_current[bracket_match*2+1]]
	chosen=[tournament_roster[tournament_pair[0]],tournament_roster[tournament_pair[1]]]
	stage_cursor=stage;set_screen("stage")

func fighter_info(id: int) -> Dictionary:
	return combat.move_db.character(id)

func binding_label(player: int, action: String) -> String:
	return input.display_label(player,action)

func mouse_navigation(event: InputEvent) -> void:
	var point: Vector2 = get_global_mouse_position()
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var alt_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if clicked: any_pressed = true
	if screen == "menu":
		for i in MENU.size():
			if Rect2(824,103+i*35,400,32).has_point(point):
				if menu_index != i:
					menu_index = i
					sound.play("select")
				if clicked: tick_menu([{ "attack_pressed":true},{}])
				return
	elif screen == "select":
		var player := 1 if ready_players[0] and not ready_players[1] else 0
		for i in PLAYABLE:
			if Rect2(358+(i%7)*82,222+int(i/7)*149,76,139).has_point(point):
				if cursors[player] != i:
					cursors[player] = i
					sound.play("select")
				var commands = [{},{}]
				if clicked: commands[player] = {"attack_pressed":true}
				elif alt_click: commands[player] = {"heavy_pressed":true}
				if clicked or alt_click: tick_select(commands)
				return
	elif screen == "stage":
		for i in STAGES.size():
			if Rect2(60+(i%4)*294,186+int(i/4)*206,277,182).has_point(point):
				stage_cursor = i
				stage = i
				if clicked: tick_stage([{ "attack_pressed":true},{}])
				return

func apply_fighter_skins() -> void:
	for i in 2:
		combat.teams[i][0].skin=skins[i]
		combat.teams[i][1].skin=reserve_skins[i]

func open_setup(kind: String) -> void:
	setup_kind=kind;setup_index=0;set_screen("setup")

func setup_options() -> Array:
	match setup_kind:
		"tower":return ["RETOMAR TORRE","NOVA TORRE","VOLTAR"]
		"versus":return ["ADVERSÁRIO: "+("CPU" if local_cpu else "JOGADOR 2"),"ESCOLHER LUTADORES","VOLTAR"]
		"tournament":return ["PARTICIPANTES: "+str(tournament_size),"INSCREVER LUTADORES","VOLTAR"]
		_:return ["MODO: "+{"quick":"CORRIDA RÁPIDA","championship":"CAMPEONATO","time_trial":"CONTRARRELÓGIO"}[kart_mode],"JOGADORES: "+str(kart_players),"ACELERAÇÃO AUTO: "+("SIM" if profile.data.settings.auto_accelerate else "NÃO"),"DIVISÃO: "+("HORIZONTAL" if profile.data.settings.split_horizontal else "VERTICAL"),"ESCOLHER PILOTOS","RETOMAR CAMPEONATO","VOLTAR"]

func tick_setup(p: Array) -> void:
	if escape_pressed:set_screen("menu");return
	var options=setup_options()
	setup_index=navigate(setup_index,axis(p),options.size())
	var direction=axis(p,true)
	var go=confirm(p,0) or confirm(p,1)
	if not go and direction==0:return
	if setup_index==options.size()-1:set_screen("menu");return
	match setup_kind:
		"tower":
			if setup_index==0:
				var v:Dictionary=profile.data.progress.tower
				if v.is_empty():begin_mode("tower");return
				mode="tower";chosen=[int(v.character),int(v.order[int(v.step)])];skins[0]=int(v.get("skin",0));arcade_order=v.order.duplicate();arcade_index=int(v.step);profile.data.settings.difficulty=int(v.difficulty);set_screen("tower")
			else:begin_mode("tower")
		"versus":
			if setup_index==0:local_cpu=not local_cpu
			else:begin_mode("versus")
		"tournament":
			if setup_index==0:tournament_size=12-tournament_size
			else:mode="tournament";tournament_roster=[];tournament_cpu=[];tournament_winners=[];tournament_round=0;tournament_cursor=0;set_screen("tournament")
		"kart":
			match setup_index:
				0:
					var modes=["quick","championship","time_trial"]
					kart_mode=modes[posmod(modes.find(kart_mode)+(direction if direction!=0 else 1),3)]
					if kart_mode=="time_trial":kart_players=1
				1:kart_players=3-kart_players;if kart_mode=="time_trial":kart_players=1
				2:profile.data.settings.auto_accelerate=not profile.data.settings.auto_accelerate;persist()
				3:profile.data.settings.split_horizontal=not profile.data.settings.split_horizontal;persist()
				4:begin_mode("kart")
				5:
					var v:Dictionary=profile.data.progress.championship
					if v.is_empty():show_toast("NENHUM CAMPEONATO SALVO");return
					chosen=v.choices.duplicate();skins=v.skins.duplicate();kart_players=int(v.humans);kart_mode="championship";kart.race_mode=kart_mode;kart.championship_points=v.points.duplicate();kart.horizontal_split=profile.data.settings.split_horizontal;kart.auto_accelerate=profile.data.settings.auto_accelerate;kart.tutorial_mode=false;kart.difficulty=int(profile.data.settings.difficulty);set_screen("kart");kart.start(chosen,skins,int(v.track),kart_players)

func save_tower() -> void:
	profile.data.progress.tower={"character":chosen[0],"skin":skins[0],"step":arcade_index,"difficulty":profile.data.settings.difficulty,"order":arcade_order.duplicate()}
	persist()

func tick_gallery(p: Array) -> void:
	if escape_pressed:set_screen("menu");return
	if axis(p)!=0:gallery_tab=posmod(gallery_tab+axis(p),3);gallery_index=0
	var count=CATALOG.ROSTER.size() if gallery_tab==0 else (STAGES.size() if gallery_tab==1 else maxi(1,profile.data.progress.achievements.size()))
	gallery_index=navigate(gallery_index,axis(p,true),count)
	if gallery_tab==0 and gallery_index==3 and p[0].get("heavy_pressed",false):skins[0]=1-skins[0]

func unlock(title: String) -> void:
	if not profile.data.progress.achievements.has(title):profile.data.progress.achievements.append(title)

func _controller_changed(device: int, connected: bool) -> void:
	if not connected:
		if screen=="fight":set_screen("pause")
		if screen=="kart" and kart.active and not kart.paused:kart.toggle_pause()
		show_toast("CONTROLE DESCONECTADO · TECLADO DISPONÍVEL")
		for i in 2:
			if input.gamepads[i].device==device:input.devices[i]="auto"
	else:show_toast("CONTROLE CONECTADO · AJUSTE EM CONTROLES")

func _kart_finished(results: Array) -> void:
	unlock("BANDEIRADA UFN")
	if kart.race_mode=="time_trial":
		var key="tempo_"+str(kart.track_id)
		var value=float(results[0].time)
		profile.data.progress.records[key]=minf(float(profile.data.progress.records.get(key,99999)),value)
	if kart.race_mode=="championship":
		if kart.track_id<3:profile.data.progress.championship={"choices":chosen.duplicate(),"skins":skins.duplicate(),"humans":kart_players,"track":kart.track_id+1,"points":kart.championship_points.duplicate()}
		else:
			profile.data.progress.championship={}
			var standings: Array = results.duplicate(true)
			standings.sort_custom(func(a,b):return a.points>b.points if a.points!=b.points else a.rank<b.rank)
			profile.data.progress.records.campeonato={"winner":standings[0].name,"character":standings[0].character,"player":standings[0].player,"points":standings[0].points,"standings":standings}
			unlock("QUATRO CIRCUITOS")
	persist()

func start_tutorial() -> void:
	mode="training";tutorial=true;tutorial_step=0;tutorial_hits=0;tutorial_done=false;chosen=[0,3];stage=0
	train_options={"dummy":0,"health":true,"meter":true,"guard":false,"boxes":false}
	start_match()
	tutorial_move_start=combat.fighters[0].x

func control_binding(player:int, action:String) -> String:
	return input.display_label(player,action,controls_kart)
