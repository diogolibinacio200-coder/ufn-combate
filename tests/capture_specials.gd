extends SceneTree
const App=preload("res://scripts/main.gd")
const Profile=preload("res://scripts/save_manager.gd")
var app
func _initialize():call_deferred("run")
func snap(label:String):
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screens/"+label+".png")
	print("CAPTURE "+label)
func run():
	app=App.new();app.profile=Profile.new("user://capture_specials.json");root.add_child(app)
	app.set_physics_process(false)
	app.profile.data.settings.fullscreen=false;app.apply_settings()
	for id in range(10,16):
		app.chosen=[id,3];app.stage=7;app.mode="versus";app.start_match();app.intro_frames=0
		var c=app.combat;var a=c.fighters[0];var d=c.fighters[1]
		a.x=450;d.x=800;a.meter=100;a.bear_x=620
		var ult=c.move_db.super_move(id);c._start_move(a,ult)
		if id!=14:c._apply_hit(a,d,ult,c.EMPTY,false)
		for i in 65:c.tick([{},{}])
		app.screen_time=1;await snap("ultimate_"+str(id))
	app.set_screen("kart");app.kart.race_mode="championship";app.kart.start([3,10],[0,0],3,2)
	app.kart.championship_points={"0":24,"1":34,"2":27,"3":22,"4":16,"5":12,"6":6,"7":3}
	for r in app.kart.racers:r.finish_time=64.1+r.id*1.27;r.progress=1000
	app.kart.finish_race();await snap("podium")
	app.kart.stop();app.set_screen("select");app.screen_time=1;await snap("select")
	app.controls_index=12;app.controls_kart=true;app.set_screen("controls");app.screen_time=1;await snap("controls")
	app.profile.data.settings.resolution=1;app.apply_settings();app.set_screen("menu");app.screen_time=1
	await snap("menu_1080p")
	await app.sound.shutdown();quit()
