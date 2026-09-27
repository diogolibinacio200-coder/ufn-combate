extends RefCounted
## Independent, physical input polling. Call update() once at the start of each
## physics tick, then sample(0) / sample(1) as often as needed during that tick.
## Keyboard auto-repeat never creates extra edges. Hardware ghosting cannot be
## repaired in software; test an arcade encoder or an N-key-rollover keyboard.

const ACTIONS: Array[String] = ["left", "right", "up", "down", "attack", "heavy", "kick", "block"]
const DEADZONE: float = 0.32
const RESERVED_KEYS: Array[int] = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_F2, KEY_F3, KEY_F11]
var bindings: Array[Dictionary] = []
var gamepads: Array[Dictionary] = []
var kart_bindings:Array = []
var kart_buttons:Array = []
var devices: Array[String] = ["auto","auto"]
var last_device: Array[String] = ["teclado","teclado"]
var raw_states: Array[Dictionary] = [{}, {}]
var _previous: Array[Dictionary] = [{}, {}]

func _init() -> void:
	reset_defaults()
	for player: int in range(2):
		for action: String in ACTIONS:
			_previous[player][action] = false
			raw_states[player][action] = false
			raw_states[player][action + "_pressed"] = false
			raw_states[player][action + "_released"] = false

func defaults() -> Array[Dictionary]:
	bindings = [
		{"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "attack": KEY_J, "heavy": KEY_K, "kick": KEY_L, "block": KEY_U},
		{"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "attack": KEY_KP_1, "heavy": KEY_KP_2, "kick": KEY_KP_3, "block": KEY_KP_4}
	]
	gamepads.clear()
	for player: int in range(2):
		gamepads.append({
			"device": player, "deadzone": DEADZONE,
			"horizontal": JOY_AXIS_LEFT_X, "vertical": JOY_AXIS_LEFT_Y,
			"invert_horizontal": false, "invert_vertical": false,
			"buttons": {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "attack": JOY_BUTTON_X, "heavy": JOY_BUTTON_Y, "kick": JOY_BUTTON_A, "block": JOY_BUTTON_LEFT_SHOULDER}
		})
	kart_bindings=bindings.duplicate(true)
	kart_buttons=[gamepads[0].buttons.duplicate(),gamepads[1].buttons.duplicate()]
	return bindings.duplicate(true)

func reset_defaults() -> void:
	defaults()

func update() -> void:
	var connected: Array[int] = Input.get_connected_joypads()
	for player: int in range(2):
		var pad: Dictionary = _pad_state(player) if devices[player]!="keyboard" and connected.has(int(gamepads[player]["device"])) else {}
		for action: String in ACTIONS:
			var keyboard: bool = devices[player]!="pad" and Input.is_physical_key_pressed(int(bindings[player][action]))
			var controller: bool = bool(pad.get(action,false))
			var held: bool = keyboard or controller
			if keyboard:last_device[player]="teclado"
			elif controller:last_device[player]="controle"
			var was_held: bool = bool(_previous[player].get(action, false))
			raw_states[player][action] = held
			raw_states[player][action + "_pressed"] = held and not was_held
			raw_states[player][action + "_released"] = was_held and not held
			_previous[player][action] = held

func sample(player: int) -> Dictionary:
	if player < 0 or player > 1:
		return {}
	return raw_states[player].duplicate()

func get_binding(player: int, action: String, kart_mode:bool=false) -> int:
	if player < 0 or player > 1 or not ACTIONS.has(action):
		return KEY_NONE
	return int((kart_bindings if kart_mode else bindings)[player][action])

func set_binding(player: int, action: String, physical_key: int, kart_mode:bool=false) -> bool:
	if player < 0 or player > 1 or not ACTIONS.has(action) or physical_key <= 0 or RESERVED_KEYS.has(physical_key):
		return false
	var map=kart_bindings if kart_mode else bindings
	var old_key: int = int(map[player][action])
	# A keyboard is shared hardware: a remap cannot silently control both players.
	for other_player: int in range(2):
		for other: String in ACTIONS:
			if (other_player != player or other != action) and int(map[other_player][other]) == physical_key:
				map[other_player][other] = old_key
	map[player][action] = physical_key
	return true

func export_bindings() -> Dictionary:
	return {"kart":{"keys":kart_bindings.duplicate(true),"buttons":kart_buttons.duplicate(true)},"devices":devices.duplicate(),"0": bindings[0].duplicate(), "1": bindings[1].duplicate(), "gamepads": {"0": gamepads[0].duplicate(true), "1": gamepads[1].duplicate(true)}}

func load_bindings(saved: Variant) -> void:
	reset_defaults()
	if not saved is Dictionary:
		return
	for player: int in range(2):
		var entry: Variant = saved.get(str(player), {})
		if not entry is Dictionary:
			continue
		for action: String in ACTIONS:
			var key: Variant = entry.get(action, bindings[player][action])
			if (key is int or key is float) and int(key) > 0:
				set_binding(player, action, int(key))
	var kart_saved=saved.get("kart",{})
	if kart_saved is Dictionary:
		var keys=kart_saved.get("keys",[]);var buttons=kart_saved.get("buttons",[])
		for i in 2:
			if keys is Array and keys.size()==2 and keys[i] is Dictionary:
				for action in ACTIONS:
					var value=keys[i].get(action)
					if value is int or value is float:set_binding(i,action,int(value),true)
			if buttons is Array and buttons.size()==2 and buttons[i] is Dictionary:
				for action in ACTIONS:
					var value=buttons[i].get(action)
					if value is int or value is float:set_gamepad_binding(i,action,int(value),-1,true)
	var saved_devices=saved.get("devices",["auto","auto"])
	if saved_devices is Array and saved_devices.size()==2:
		for i in 2:devices[i]=saved_devices[i] if saved_devices[i] in ["auto","keyboard","pad"] else "auto"
	var saved_pads: Variant = saved.get("gamepads", {})
	if not saved_pads is Dictionary:
		return
	for player: int in range(2):
		var entry: Variant = saved_pads.get(str(player), {})
		if not entry is Dictionary:
			continue
		var device: Variant = entry.get("device", player)
		if device is int or device is float:
			set_gamepad_device(player, int(device))
		var zone: Variant = entry.get("deadzone", DEADZONE)
		if zone is int or zone is float:
			set_gamepad_deadzone(player, float(zone))
		for axis: String in ["horizontal", "vertical"]:
			var number: Variant = entry.get(axis, gamepads[player][axis])
			var inverted: Variant = entry.get("invert_" + axis, false)
			if number is int or number is float:
				set_gamepad_axis(player, axis, int(number), bool(inverted) if inverted is bool else false)
		var buttons: Variant = entry.get("buttons", {})
		if buttons is Dictionary:
			for action: String in ACTIONS:
				var button: Variant = buttons.get(action, gamepads[player]["buttons"][action])
				if button is int or button is float:
					set_gamepad_binding(player, action, int(button))

func set_gamepad_binding(player: int, action: String, button: int, device: int = -1, kart_mode:bool=false) -> bool:
	if player < 0 or player > 1 or not ACTIONS.has(action) or button < 0 or button >= JOY_BUTTON_MAX or button in [JOY_BUTTON_START, JOY_BUTTON_BACK]:
		return false
	if device >= 0 and not set_gamepad_device(player, device):
		return false
	var buttons: Dictionary = kart_buttons[player] if kart_mode else gamepads[player]["buttons"]
	var old_button: int = int(buttons[action])
	for other: String in ACTIONS:
		if other != action and int(buttons[other]) == button:
			buttons[other] = old_button
	buttons[action] = button
	return true

func get_gamepad_binding(player: int, action: String, kart_mode:bool=false) -> int:
	if player < 0 or player > 1 or not ACTIONS.has(action):
		return -1
	return int((kart_buttons[player] if kart_mode else gamepads[player]["buttons"])[action])

func get_gamepad_config(player: int) -> Dictionary:
	return gamepads[player].duplicate(true) if player >= 0 and player <= 1 else {}

func set_gamepad_device(player: int, device: int) -> bool:
	if player < 0 or player > 1 or device < 0 or device > 15:
		return false
	var old_device: int = int(gamepads[player]["device"])
	if int(gamepads[1-player]["device"]) == device:
		gamepads[1-player]["device"] = old_device
	gamepads[player]["device"] = device
	return true

func set_gamepad_axis(player: int, axis: String, axis_index: int, inverted: bool = false) -> bool:
	if player < 0 or player > 1 or axis not in ["horizontal", "vertical"] or axis_index < 0 or axis_index >= JOY_AXIS_MAX:
		return false
	gamepads[player][axis] = axis_index
	gamepads[player]["invert_" + axis] = inverted
	return true

func set_gamepad_deadzone(player: int, value: float) -> bool:
	if player < 0 or player > 1 or not is_finite(value):
		return false
	gamepads[player]["deadzone"] = clampf(value, 0.1, 0.9)
	return true

func _pad_state(player: int, kart_mode:bool=false) -> Dictionary:
	var config: Dictionary = gamepads[player]
	var device: int = int(config["device"])
	var horizontal: float = Input.get_joy_axis(device, int(config["horizontal"])) * (-1.0 if config["invert_horizontal"] else 1.0)
	var vertical: float = Input.get_joy_axis(device, int(config["vertical"])) * (-1.0 if config["invert_vertical"] else 1.0)
	var zone: float = float(config["deadzone"])
	var result: Dictionary = {}
	for action: String in ACTIONS:
		result[action] = Input.is_joy_button_pressed(device, int(kart_buttons[player][action] if kart_mode else config["buttons"][action]))
	result["left"] = bool(result["left"]) or horizontal < -zone
	result["right"] = bool(result["right"]) or horizontal > zone
	result["up"] = bool(result["up"]) or vertical < -zone
	result["down"] = bool(result["down"]) or vertical > zone
	return result

func use_laptop_profile() -> void:
	reset_defaults()
	bindings[0].merge({"attack":KEY_F,"heavy":KEY_G,"kick":KEY_H,"block":KEY_R},true)
	bindings[1].merge({"attack":KEY_J,"heavy":KEY_K,"kick":KEY_L,"block":KEY_U},true)
	kart_bindings=bindings.duplicate(true)

func display_label(player: int, action: String, kart_mode:bool=false) -> String:
	if last_device[player]=="controle":
		var names={JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",JOY_BUTTON_LEFT_SHOULDER:"LB",JOY_BUTTON_RIGHT_SHOULDER:"RB"}
		return str(names.get(get_gamepad_binding(player,action,kart_mode),"PAD "+str(get_gamepad_binding(player,action,kart_mode))))
	return OS.get_keycode_string(get_binding(player,action,kart_mode)).replace("Kp ","N")

func sample_kart(player:int) -> Dictionary:
	var pad=_pad_state(player,true) if devices[player]!="keyboard" and Input.get_connected_joypads().has(int(gamepads[player].device)) else {}
	var result={}
	for action in ACTIONS:
		var key=devices[player]!="pad" and Input.is_physical_key_pressed(get_binding(player,action,true))
		result[action]=key or pad.get(action,false)
		if key:last_device[player]="teclado"
		elif pad.get(action,false):last_device[player]="controle"
	return result
