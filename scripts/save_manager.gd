extends RefCounted
## Versioned local profile. A failed write leaves the last good profile intact.

const PROFILE: String = "user://profile.json"
const TEMP: String = "user://profile.json.tmp"
const BACKUP: String = "user://profile.json.bak"
var data: Dictionary = {}
var last_error: String = ""
var _profile_path: String = PROFILE
var _temp_path: String = TEMP
var _backup_path: String = BACKUP

func _init(profile_path: String = PROFILE) -> void:
	_profile_path = profile_path
	_temp_path = profile_path + ".tmp"
	_backup_path = profile_path + ".bak"
	data = defaults()

func defaults() -> Dictionary:
	return {
		"version": 2,
		"settings": {"music": 0.5, "sfx": 0.7, "shake": 0.6, "flashes": 0.5, "rounds": 3, "difficulty": 1, "fullscreen": false, "resolution": 0, "arcade_mode": false,"master":0.8,"voice":0.7,"quality":1,"particles":0.7,"subtitles":true,"text_size":0,"auto_accelerate":false,"split_horizontal":false},
		"stats": {"matches": 0, "p1_wins": 0, "p2_wins": 0, "most_played": {}, "biggest_combo": 0, "perfect_blocks": 0, "guard_breaks": 0, "supers": 0},
		"progress":{"tower":{},"championship":{},"records":{},"achievements":[]},
		"bindings": {}
	}

func load_profile() -> Dictionary:
	data = defaults()
	last_error = ""
	var parsed: Variant = _read(_profile_path)
	if not parsed is Dictionary:
		parsed = _read(_backup_path)
	if parsed is Dictionary:
		for section: String in ["settings", "stats", "bindings", "progress"]:
			var incoming: Variant = parsed.get(section, {})
			if incoming is Dictionary:
				data[section].merge(incoming, true)
	_sanitize()
	return data

func save_profile() -> bool:
	last_error = ""
	_sanitize()
	var file: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "Não foi possível gravar o perfil: " + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Falha ao gravar o perfil: " + error_string(write_error)
		return false
	# Backup is secondary recovery; rename of a fully flushed temporary is the commit.
	if FileAccess.file_exists(_profile_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(_profile_path), ProjectSettings.globalize_path(_backup_path))
	var commit_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(_temp_path), ProjectSettings.globalize_path(_profile_path))
	if commit_error != OK:
		last_error = "Falha ao confirmar o perfil: " + error_string(commit_error)
		return false
	return true

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func _sanitize() -> void:
	var baseline: Dictionary = defaults()
	for section: String in ["settings", "stats", "bindings", "progress"]:
		if not data.get(section) is Dictionary:
			data[section] = baseline[section].duplicate(true)
		else:
			data[section].merge(baseline[section], false)
	var settings: Dictionary = data["settings"]
	for setting: String in ["music", "sfx", "shake", "flashes","master","voice","particles"]:
		var value: Variant = settings[setting]
		settings[setting] = clampf(float(value), 0.0, 1.0) if value is float or value is int else baseline["settings"][setting]
	if not settings["rounds"] in [1, 3, 5]:
		settings["rounds"] = 3
	for setting: String in ["difficulty", "resolution", "quality", "text_size"]:
		var value: Variant = settings[setting]
		var upper_bound: int = 3 if setting == "difficulty" else 1
		settings[setting] = clampi(int(value), 0, upper_bound) if value is float or value is int else baseline["settings"][setting]
	for setting: String in ["fullscreen", "arcade_mode", "subtitles", "auto_accelerate", "split_horizontal"]:
		if not settings[setting] is bool:
			settings[setting] = baseline["settings"][setting]
	var stats: Dictionary = data["stats"]
	for stat: String in baseline["stats"]:
		if stat == "most_played":
			if not stats[stat] is Dictionary:
				stats[stat] = {}
		else:
			var value: Variant = stats[stat]
			stats[stat] = maxi(0, int(value)) if value is float or value is int else 0
	var progress:Dictionary=data.progress
	for key in ["tower","championship","records"]:
		if not progress.get(key) is Dictionary:progress[key]={}
	if not progress.get("achievements") is Array:progress.achievements=[]
	var tower:Dictionary=progress.tower
	if not tower.is_empty():
		if not tower.get("order") is Array or tower.get("order",[]).size()!=10 or int(tower.get("step",-1)) not in range(10) or int(tower.get("character",-1)) not in range(14):progress.tower={}
		else:
			for id in tower.order:
				if not (id is int or id is float) or int(id) not in range(16):progress.tower={};break
			tower.difficulty=clampi(int(tower.get("difficulty",1)),0,3)
	var championship:Dictionary=progress.championship
	if not championship.is_empty():
		if not championship.get("choices") is Array or championship.get("choices",[]).size()!=2 or not championship.get("skins") is Array or not championship.get("points") is Dictionary or int(championship.get("track",-1)) not in range(4):progress.championship={}
	data["version"] = 2
