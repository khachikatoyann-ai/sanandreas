class_name GameDirectorCore
extends Node

## GameDirector: Global singleton orchestrating the 1-5 Star Wanted Level system,
## AI police cruiser pursuits, crime telemetry, cash economy, and NPC traffic spawning.

signal wanted_level_changed(stars: int, is_evading: bool)
signal crime_committed(crime_type: String, location: Vector3)
signal cash_changed(amount: int)
signal player_vehicle_swapped(vehicle: VehicleController)

var wanted_stars: int = 0
var crime_meter: float = 0.0
var evade_timer: float = 0.0
var is_evading: bool = false
var cash: int = 25400

var player_ref: CharacterBody3D = null
var active_player_vehicle: VehicleController = null
var active_police: Array[PoliceVehicle] = []

const MAX_POLICE_BY_STAR: Array[int] = [0, 1, 2, 3, 4, 6]
var police_spawn_timer: float = 0.0
var evade_cooldown_duration: float = 12.0

static var instance: GameDirectorCore = null

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	if instance == self:
		instance = null

func register_player(player: CharacterBody3D) -> void:
	player_ref = player
	if player_ref:
		player_ref.health_changed.connect(_on_player_health_changed)

func register_player_vehicle(veh: VehicleController) -> void:
	active_player_vehicle = veh
	player_vehicle_swapped.emit(veh)

func clear_player_vehicle() -> void:
	active_player_vehicle = null
	player_vehicle_swapped.emit(null)

func _process(delta: float) -> void:
	_update_wanted_system(delta)
	_update_police_spawner(delta)

func report_crime(crime_type: String, location: Vector3) -> void:
	var crime_val: float = 0.0
	match crime_type:
		"gunfire":
			crime_val = 18.0
		"carjacking":
			crime_val = 35.0
		"pedestrian_hit":
			crime_val = 45.0
		"cop_rammed":
			crime_val = 60.0
		"cop_destroyed":
			crime_val = 110.0
		_:
			crime_val = 15.0

	crime_meter += crime_val
	is_evading = false
	evade_timer = evade_cooldown_duration

	# Calculate stars (each 100 crime points = 1 star, min 1 star upon crime)
	var new_stars: int = clamp(int(floor(crime_meter / 70.0)) + 1, 1, 5)
	if new_stars > wanted_stars:
		wanted_stars = new_stars
		AudioManagerCore.play_impact(0.8)
	
	wanted_level_changed.emit(wanted_stars, is_evading)
	crime_committed.emit(crime_type, location)

func _update_wanted_system(delta: float) -> void:
	if wanted_stars <= 0:
		AudioManagerCore.set_siren_active(false)
		return

	# Check line of sight / distance to active police
	var player_pos: Vector3 = _get_active_target_pos()
	var in_police_sight: bool = false
	
	# Clean invalid cruisers
	active_police = active_police.filter(func(p: PoliceVehicle) -> bool: return is_instance_valid(p) and p.current_state != VehicleController.State.WRECKED)
	
	for cop: PoliceVehicle in active_police:
		if cop.global_position.distance_to(player_pos) < 65.0:
			in_police_sight = true
			break

	if in_police_sight:
		is_evading = false
		evade_timer = evade_cooldown_duration
		AudioManagerCore.set_siren_active(true)
	else:
		# Player is outside police sight radius: begin evasion decay
		is_evading = true
		evade_timer -= delta
		if evade_timer <= 0.0:
			# Degrade wanted level
			wanted_stars -= 1
			crime_meter = maxf(0.0, float(wanted_stars * 70.0))
			evade_timer = evade_cooldown_duration
			if wanted_stars <= 0:
				is_evading = false
				AudioManagerCore.set_siren_active(false)
			wanted_level_changed.emit(wanted_stars, is_evading)

func _update_police_spawner(delta: float) -> void:
	if wanted_stars <= 0:
		return

	police_spawn_timer -= delta
	var target_police_count: int = MAX_POLICE_BY_STAR[wanted_stars]
	
	if police_spawn_timer <= 0.0 and active_police.size() < target_police_count:
		police_spawn_timer = randf_range(3.5, 7.0)
		_spawn_police_cruiser()

func _spawn_police_cruiser() -> void:
	var target_pos: Vector3 = _get_active_target_pos()
	
	# Spawn police 65-90 meters away along city grid
	var spawn_angle: float = randf_range(0.0, TAU)
	var spawn_dist: float = randf_range(65.0, 95.0)
	var spawn_pos: Vector3 = target_pos + Vector3(cos(spawn_angle) * spawn_dist, 0.5, sin(spawn_angle) * spawn_dist)
	# Snap to ground
	spawn_pos.y = 0.5
	
	var parent_scene: Node = get_tree().current_scene
	if parent_scene:
		var cop_cruiser: PoliceVehicle = PoliceVehicle.new()
		parent_scene.add_child(cop_cruiser)
		cop_cruiser.global_position = spawn_pos
		cop_cruiser.look_at(Vector3(target_pos.x, spawn_pos.y, target_pos.z), Vector3.UP)
		active_police.append(cop_cruiser)
		cop_cruiser.set_pursuit_target(player_ref)

func _get_active_target_pos() -> Vector3:
	if active_player_vehicle and is_instance_valid(active_player_vehicle):
		return active_player_vehicle.global_position
	elif player_ref and is_instance_valid(player_ref):
		return player_ref.global_position
	return Vector3.ZERO

func add_cash(amount: int) -> void:
	cash += amount
	cash_changed.emit(cash)

func on_player_died() -> void:
	# Reset wanted on death, respawn
	wanted_stars = 0
	crime_meter = 0.0
	is_evading = false
	wanted_level_changed.emit(0, false)
	AudioManagerCore.set_siren_active(false)
	
	# Respawn after short delay
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if player_ref:
			player_ref.global_position = Vector3(0.0, 1.2, 0.0)
			player_ref.current_health = 100.0
			player_ref.current_armor = 100.0
			player_ref.health_changed.emit(100.0, 100.0)
			player_ref.armor_changed.emit(100.0, 100.0)
	)

func _on_player_health_changed(current: float, max_val: float) -> void:
	pass
