extends SceneTree
const App=preload("res://scripts/main.gd")
const Profile=preload("res://scripts/save_manager.gd")
var app
func _initialize():call_deferred("run")
func snap(name:String):
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://docs/screens/"+name+".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE "+name)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screens"))
	app=App.new();app.profile=Profile.new("user://capture_v2.json");root.add_child(app)
	app.set_physics_process(false);app.profile.data.settings.text_size=0;app.apply_settings()
	app.screen_time=1
	for screen in ["menu","select","stage","settings","controls","credits","kart_stage","stats"]:
		app.set_screen(screen);app.screen_time=1;await snap(screen)
	app.setup_kind="kart";app.set_screen("setup");app.screen_time=1;await snap("setup")
	app.mode="tower";app.chosen=[3,14];app.arcade_order=[0,1,2,4,5,6,10,13,14,15];app.arcade_index=8;app.set_screen("tower");app.screen_time=1;await snap("tower")
	app.mode="versus";app.chosen=[13,15];app.stage=7;app.start_match();app.intro_frames=0;app.combat.fighters[0].x=420;app.combat.fighters[1].x=810;app.combat.fighters[0].bear_x=560;app.screen_time=1;await snap("fight")
	for id in range(10,16):
		app.gallery_index=id;app.gallery_tab=0;app.set_screen("gallery");app.screen_time=1;await snap("fighter_"+str(id))
	app.set_screen("kart");app.kart.start([13,10],[0,0],0,2);app.kart.phase="race"
	for r in app.kart.racers:r.human=false
	var measurements=[]
	for i in 420:
		await process_frame
		if i>120:measurements.append(1.0/maxf(.001,root.get_process_delta_time()))
	await snap("kart")
	measurements.sort();print("KART FPS median=",measurements[measurements.size()/2]," p05=",measurements[measurements.size()/20])
	app.kart.stop();app.kart.horizontal_split=true;app.kart.start([3,10],[0,0],1,2);app.kart.phase="race";await snap("kart_horizontal")
	app.kart.stop();app.mode="attract";app.chosen=[10,12];app.start_match();app.intro_frames=0;app.set_physics_process(true)
	measurements=[]
	for i in 420:
		await process_frame
		if i>120:measurements.append(1.0/maxf(.001,root.get_process_delta_time()))
	measurements.sort();print("FIGHT FPS median=",measurements[measurements.size()/2]," p05=",measurements[measurements.size()/20])
	app.set_physics_process(false);await app.sound.shutdown();quit()
