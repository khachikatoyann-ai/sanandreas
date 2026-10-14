class_name InputManagerCore
extends Node

## InputManager: Programmatically registers and manages action bindings for desktop & mobile
## Guarantees all required actions exist on startup and maps physical & virtual devices.

const ACTIONS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"fire": [MOUSE_BUTTON_LEFT, KEY_CTRL, KEY_ENTER],
	"interact_vehicle": [KEY_F, KEY_E],
	"handbrake": [KEY_SPACE, KEY_C]
}

const GAMEPAD_ACTIONS: Dictionary = {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_forward": [JOY_BUTTON_DPAD_UP],
	"move_back": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"fire": [JOY_BUTTON_RIGHT_SHOULDER],
	"interact_vehicle": [JOY_BUTTON_Y, JOY_BUTTON_X],
	"handbrake": [JOY_BUTTON_B]
}

func _enter_tree() -> void:
	register_input_bindings()

static func register_input_bindings() -> void:
	for action_name: String in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		
		var bindings: Array = ACTIONS[action_name]
		for item in bindings:
			if item is Key:
				var ev_key: InputEventKey = InputEventKey.new()
				ev_key.physical_keycode = item
				ev_key.pressed = false
				if not _has_event(action_name, ev_key):
					InputMap.action_add_event(action_name, ev_key)
			elif item is MouseButton:
				var ev_mouse: InputEventMouseButton = InputEventMouseButton.new()
				ev_mouse.button_index = item
				if not _has_event(action_name, ev_mouse):
					InputMap.action_add_event(action_name, ev_mouse)
		
		if GAMEPAD_ACTIONS.has(action_name):
			for joy_btn: JoyButton in GAMEPAD_ACTIONS[action_name]:
				var ev_joy: InputEventJoypadButton = InputEventJoypadButton.new()
				ev_joy.button_index = joy_btn
				if not _has_event(action_name, ev_joy):
					InputMap.action_add_event(action_name, ev_joy)

static func _has_event(action_name: String, event: InputEvent) -> bool:
	for existing: InputEvent in InputMap.action_get_events(action_name):
		if existing.is_match(event, true):
			return true
	return false

## Helper for mobile HUD virtual controls to simulate action states
static func set_virtual_action(action_name: String, pressed: bool, strength: float = 1.0) -> void:
	if not InputMap.has_action(action_name):
		return
	if pressed:
		Input.action_press(action_name, strength)
	else:
		Input.action_release(action_name)
