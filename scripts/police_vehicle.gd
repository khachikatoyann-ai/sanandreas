class_name PoliceVehicle
extends VehicleController

## PoliceVehicle: AI-driven LSPD Police Cruiser with flashing red/blue OmniLight3D siren bar,
## siren acoustics, NavigationAgent3D pursuit pathfinding, and PIT maneuver ramming physics.

var nav_agent: NavigationAgent3D
var target_node: Node3D = null

# Siren FX
var siren_light_red: OmniLight3D
var siren_light_blue: OmniLight3D
var siren_mesh_red: MeshInstance3D
var siren_mesh_blue: MeshInstance3D
var siren_mat_red: StandardMaterial3D
var siren_mat_blue: StandardMaterial3D
var siren_timer: float = 0.0
var siren_flash_state: bool = false

# AI Pursuit parameters
var repath_timer: float = 0.0
var aggression: float = 1.0
var is_active_pursuit: bool = true

func _ready() -> void:
	paint_color = Color(0.08, 0.08, 0.1, 1.0) # Black interceptor base
	vehicle_name = "LSPD Cruiser"
	max_engine_force = 4200.0 # High performance interceptor engine
	top_speed_kmh = 165.0
	
	super._ready()
	current_state = State.DRIVEN_BY_AI
	
	_build_police_equipment()
	_setup_navigation_agent()

func _build_police_equipment() -> void:
	# White doors & roof (Classic Black & White Police Cruiser livery)
	var white_mat: StandardMaterial3D = StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
	white_mat.metallic = 0.8
	white_mat.roughness = 0.2
	
	var door_l: MeshInstance3D = MeshInstance3D.new()
	var d_box: BoxMesh = BoxMesh.new()
	d_box.size = Vector3(0.05, 0.45, 1.6)
	door_l.mesh = d_box
	door_l.position = Vector3(-0.93, 0.52, -0.1)
	door_l.material_override = white_mat
	body_mesh_root.add_child(door_l)

	var door_r: MeshInstance3D = door_l.duplicate() as MeshInstance3D
	door_r.position.x = 0.93
	body_mesh_root.add_child(door_r)

	# Heavy Duty Push Bumper (Bullbar)
	var bullbar_mat: StandardMaterial3D = StandardMaterial3D.new()
	bullbar_mat.albedo_color = Color(0.12, 0.12, 0.12, 1.0)
	bullbar_mat.metallic = 0.95
	bullbar_mat.roughness = 0.3
	
	var bullbar: MeshInstance3D = MeshInstance3D.new()
	var bb_box: BoxMesh = BoxMesh.new()
	bb_box.size = Vector3(1.6, 0.4, 0.2)
	bullbar.mesh = bb_box
	bullbar.position = Vector3(0.0, 0.45, 2.22)
	bullbar.material_override = bullbar_mat
	body_mesh_root.add_child(bullbar)

	# Roof Siren Lightbar Base
	var bar_base: MeshInstance3D = MeshInstance3D.new()
	var sb_box: BoxMesh = BoxMesh.new()
	sb_box.size = Vector3(1.2, 0.08, 0.28)
	bar_base.mesh = sb_box
	bar_base.position = Vector3(0.0, 1.25, -0.2)
	bar_base.material_override = bullbar_mat
	body_mesh_root.add_child(bar_base)

	# Red Siren Lens & OmniLight3D
	siren_mat_red = GraphicsManagerCore.create_emissive_material(Color(1.0, 0.05, 0.05, 1.0), 5.0)
	siren_mesh_red = MeshInstance3D.new()
	var lr_box: BoxMesh = BoxMesh.new()
	lr_box.size = Vector3(0.45, 0.12, 0.22)
	siren_mesh_red.mesh = lr_box
	siren_mesh_red.position = Vector3(-0.35, 1.32, -0.2)
	siren_mesh_red.material_override = siren_mat_red
	body_mesh_root.add_child(siren_mesh_red)

	siren_light_red = OmniLight3D.new()
	siren_light_red.light_color = Color(1.0, 0.1, 0.1, 1.0)
	siren_light_red.light_energy = 4.0
	siren_light_red.omni_range = 14.0
	siren_light_red.shadow_enabled = false
	siren_mesh_red.add_child(siren_light_red)

	# Blue Siren Lens & OmniLight3D
	siren_mat_blue = GraphicsManagerCore.create_emissive_material(Color(0.1, 0.3, 1.0, 1.0), 5.0)
	siren_mesh_blue = MeshInstance3D.new()
	siren_mesh_blue.mesh = lr_box
	siren_mesh_blue.position = Vector3(0.35, 1.32, -0.2)
	siren_mesh_blue.material_override = siren_mat_blue
	body_mesh_root.add_child(siren_mesh_blue)

	siren_light_blue = OmniLight3D.new()
	siren_light_blue.light_color = Color(0.15, 0.4, 1.0, 1.0)
	siren_light_blue.light_energy = 4.0
	siren_light_blue.omni_range = 14.0
	siren_light_blue.shadow_enabled = false
	siren_mesh_blue.add_child(siren_light_blue)

func _setup_navigation_agent() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "PursuitNavAgent"
	nav_agent.path_desired_distance = 3.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.max_speed = 35.0
	add_child(nav_agent)

func _physics_process(delta: float) -> void:
	if current_state == State.DRIVEN_BY_PLAYER:
		super._physics_process(delta)
		_update_sirens(delta)
		return

	if current_state == State.WRECKED:
		_disable_sirens()
		super._physics_process(delta)
		return

	_update_sirens(delta)
	_update_pursuit_ai(delta)
	super._physics_process(delta)

func _update_sirens(delta: float) -> void:
	siren_timer += delta
	# Strobe flash every 0.14 seconds
	if siren_timer >= 0.14:
		siren_timer = 0.0
		siren_flash_state = not siren_flash_state
		
		if siren_flash_state:
			siren_light_red.light_energy = 5.5 # Exceeds 0.9 bloom threshold!
			siren_mat_red.emission_energy_multiplier = 6.0
			siren_light_blue.light_energy = 0.0
			siren_mat_blue.emission_energy_multiplier = 0.2
		else:
			siren_light_red.light_energy = 0.0
			siren_mat_red.emission_energy_multiplier = 0.2
			siren_light_blue.light_energy = 5.5 # Exceeds 0.9 bloom threshold!
			siren_mat_blue.emission_energy_multiplier = 6.0

func _disable_sirens() -> void:
	siren_light_red.light_energy = 0.0
	siren_light_blue.light_energy = 0.0
	siren_mat_red.emission_energy_multiplier = 0.0
	siren_mat_blue.emission_energy_multiplier = 0.0

func _update_pursuit_ai(delta: float) -> void:
	if not is_active_pursuit:
		input_throttle = 0.0
		input_steer = 0.0
		input_brake = 1.0
		return

	# Locate target (Player or Player's vehicle)
	if not is_instance_valid(target_node):
		if GameDirectorCore.instance and GameDirectorCore.instance.player_ref:
			target_node = GameDirectorCore.instance.player_ref
		return

	# If player is in a vehicle, pursue that vehicle
	var actual_target_pos: Vector3 = target_node.global_position
	if GameDirectorCore.instance and GameDirectorCore.instance.active_player_vehicle:
		actual_target_pos = GameDirectorCore.instance.active_player_vehicle.global_position

	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = 0.25
		nav_agent.target_position = actual_target_pos

	var dist_to_target: float = global_position.distance_to(actual_target_pos)
	
	# Determine next waypoint from NavigationAgent or direct vector
	var next_waypoint: Vector3 = actual_target_pos
	if not nav_agent.is_navigation_finished():
		var nav_next: Vector3 = nav_agent.get_next_path_position()
		if nav_next.distance_to(global_position) > 1.5:
			next_waypoint = nav_next

	# Calculate steering angle towards waypoint
	var to_waypoint_local: Vector3 = global_transform.basis.inverse() * (next_waypoint - global_position)
	var angle_to_target: float = atan2(-to_waypoint_local.x, -to_waypoint_local.z)
	
	# Clamp steering
	input_steer = clampf(angle_to_target * 1.8, -1.0, 1.0)
	
	# Throttle & Braking logic
	if dist_to_target > 8.0:
		# Full throttle to chase
		input_throttle = 1.0
		input_brake = 0.0
		# Drift around sharp corners
		if abs(input_steer) > 0.65 and speed_kmh > 40.0:
			input_handbrake = true
		else:
			input_handbrake = false
	elif dist_to_target > 3.5:
		# Aggressive PIT maneuver / Ramming
		input_throttle = 0.85
		input_brake = 0.0
		input_handbrake = false
	else:
		# Close range containment
		input_throttle = 0.3
		input_brake = 0.6
		input_handbrake = false

func set_pursuit_target(node: Node3D) -> void:
	target_node = node
