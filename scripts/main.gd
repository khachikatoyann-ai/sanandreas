class_name MainGameLoop
extends Node3D

## MainGameLoop: Master coordinator for Los Santos Advanced.
## Instantiates the procedural city, player character, HUD, lighting, and connects engine telemetry.

var city_builder: CityBuilder
var player: PlayerCharacter
var hud: GameHUD

func _ready() -> void:
	# Ensure graphics environment is applied
	GraphicsManager.call_deferred("_setup_global_graphics")
	
	_assemble_world()
	_setup_desktop_controls()

func _assemble_world() -> void:
	# 1. City Sandbox District
	city_builder = CityBuilder.new()
	city_builder.name = "CitySandbox"
	add_child(city_builder)

	# 2. Player Character
	player = PlayerCharacter.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.2, 0.0)
	add_child(player)
	if GameDirectorCore.instance:
		GameDirectorCore.instance.register_player(player)

	# 3. Mobile Landscape HUD & Radar
	hud = GameHUD.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.setup_player(player)

	# Connect vehicle entry/exit to track control authority
	_hook_vehicle_events()

func _hook_vehicle_events() -> void:
	# Observe tree for spawned vehicles
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is VehicleController:
		if not node.player_entered_vehicle.is_connected(_on_player_entered_vehicle):
			node.player_entered_vehicle.connect(_on_player_entered_vehicle)
		if not node.player_exited_vehicle.is_connected(_on_player_exited_vehicle):
			node.player_exited_vehicle.connect(_on_player_exited_vehicle)

func _on_player_entered_vehicle(veh: VehicleController) -> void:
	if GameDirectorCore.instance:
		GameDirectorCore.instance.register_player_vehicle(veh)

func _on_player_exited_vehicle(veh: VehicleController) -> void:
	if GameDirectorCore.instance:
		GameDirectorCore.instance.clear_player_vehicle()

func _setup_desktop_controls() -> void:
	# For desktop convenience, capture mouse on click; ESC to release
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
