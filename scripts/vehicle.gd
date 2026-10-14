class_name VehicleController
extends VehicleBody3D

## VehicleController: Production 4-wheel physics with Ackermann steering,
## dynamic engine force curves, handbrake drift slip reduction, tire smoke,
## and seamless control authority swapping for carjacking.

enum State {
	PARKED,
	DRIVER_ENTERING,
	DRIVEN_BY_PLAYER,
	DRIVEN_BY_AI,
	DRIVER_EXITING,
	WRECKED
}

@export var vehicle_name: String = "Bravado Banshee"
@export var paint_color: Color = Color(0.88, 0.12, 0.15, 1.0)
@export var max_engine_force: float = 3800.0
@export var max_brake_force: float = 120.0
@export var max_steering_angle: float = 0.58 # ~33 degrees
@export var wheelbase: float = 2.65
@export var track_width: float = 1.72
@export var top_speed_kmh: float = 160.0
@export var reverse_top_speed_kmh: float = 40.0
@export var base_friction_slip: float = 2.4
@export var drift_friction_slip: float = 0.72

var current_state: State = State.PARKED
var driver_ref: CharacterBody3D = null
var current_health: float = 1000.0
var max_health: float = 1000.0

# Wheel Nodes
var wheel_fl: VehicleWheel3D
var wheel_fr: VehicleWheel3D
var wheel_rl: VehicleWheel3D
var wheel_rr: VehicleWheel3D

# Visual & FX Nodes
var body_mesh_root: Node3D
var headlight_left: SpotLight3D
var headlight_right: SpotLight3D
var taillight_mat: StandardMaterial3D
var smoke_particles_l: GPUParticles3D
var smoke_particles_r: GPUParticles3D
var engine_fire_particles: GPUParticles3D
var driver_seat_marker: Marker3D
var exit_door_marker: Marker3D

# Internal input & physics
var input_steer: float = 0.0
var input_throttle: float = 0.0
var input_brake: float = 0.0
var input_handbrake: bool = false
var current_steer_angle: float = 0.0
var speed_kmh: float = 0.0
var is_drifting: bool = false

# Signal for HUD / GameDirector
signal player_entered_vehicle(veh: VehicleController)
signal player_exited_vehicle(veh: VehicleController)
signal vehicle_damaged(current_hp: float, max_hp: float)
signal vehicle_destroyed(veh: VehicleController)

func _ready() -> void:
	mass = 1450.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.22, 0.05) # Low center of gravity prevents rolling over
	
	_setup_collision()
	_setup_wheels()
	_build_visuals()
	_setup_particles()
	
	GraphicsManagerCore.apply_vehicle_pbr_material(self, paint_color)

func _setup_collision() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "ChassisCollision"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.95, 0.95, 4.35)
	col.shape = box
	col.position = Vector3(0.0, 0.58, 0.0)
	add_child(col)

func _setup_wheels() -> void:
	var half_wb: float = wheelbase * 0.5
	var half_tw: float = track_width * 0.5
	var wheel_y: float = 0.38
	
	# Front Left
	wheel_fl = _create_wheel("WheelFL", Vector3(-half_tw, wheel_y, half_wb), true, false)
	# Front Right
	wheel_fr = _create_wheel("WheelFR", Vector3(half_tw, wheel_y, half_wb), true, false)
	# Rear Left
	wheel_rl = _create_wheel("WheelRL", Vector3(-half_tw, wheel_y, -half_wb), false, true)
	# Rear Right
	wheel_rr = _create_wheel("WheelRR", Vector3(half_tw, wheel_y, -half_wb), false, true)

func _create_wheel(wname: String, pos: Vector3, steer: bool, traction: bool) -> VehicleWheel3D:
	var w: VehicleWheel3D = VehicleWheel3D.new()
	w.name = wname
	w.position = pos
	w.use_as_steering = steer
	w.use_as_traction = traction
	w.wheel_roll_influence = 0.12
	w.wheel_radius = 0.38
	w.wheel_rest_length = 0.18
	w.wheel_friction_slip = base_friction_slip
	w.suspension_travel = 0.22
	w.suspension_stiffness = 52.0
	w.suspension_max_force = 14000.0
	w.damping_compression = 1.9
	w.damping_relaxation = 2.5
	add_child(w)
	return w

func _build_visuals() -> void:
	body_mesh_root = Node3D.new()
	body_mesh_root.name = "BodyVisuals"
	add_child(body_mesh_root)

	# Main aerodynamic body
	var body_mesh: MeshInstance3D = MeshInstance3D.new()
	body_mesh.name = "ChassisBody"
	var b_box: BoxMesh = BoxMesh.new()
	b_box.size = Vector3(1.85, 0.55, 4.2)
	body_mesh.mesh = b_box
	body_mesh.position = Vector3(0.0, 0.5, 0.0)
	body_mesh_root.add_child(body_mesh)

	# Cabin / Cockpit Roof
	var cabin_mesh: MeshInstance3D = MeshInstance3D.new()
	cabin_mesh.name = "CabinRoof"
	var c_box: BoxMesh = BoxMesh.new()
	c_box.size = Vector3(1.5, 0.48, 2.1)
	cabin_mesh.mesh = c_box
	cabin_mesh.position = Vector3(0.0, 0.95, -0.25)
	body_mesh_root.add_child(cabin_mesh)

	# Windshield & Windows
	var glass_mat: StandardMaterial3D = GraphicsManagerCore.create_glass_material()
	var windshield: MeshInstance3D = MeshInstance3D.new()
	windshield.name = "WindshieldGlass"
	var w_box: BoxMesh = BoxMesh.new()
	w_box.size = Vector3(1.48, 0.42, 0.15)
	windshield.mesh = w_box
	windshield.position = Vector3(0.0, 0.95, 0.8)
	windshield.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	windshield.material_override = glass_mat
	body_mesh_root.add_child(windshield)

	# Rear Spoiler
	var spoiler: MeshInstance3D = MeshInstance3D.new()
	spoiler.name = "SpoilerWing"
	var sp_box: BoxMesh = BoxMesh.new()
	sp_box.size = Vector3(1.65, 0.06, 0.35)
	spoiler.mesh = sp_box
	spoiler.position = Vector3(0.0, 0.98, -1.95)
	body_mesh_root.add_child(spoiler)

	# 4 3D Wheel Visuals
	var rubber_mat: StandardMaterial3D = GraphicsManagerCore.create_rubber_material()
	var rim_mat: StandardMaterial3D = GraphicsManagerCore.create_rim_chrome_material()
	_create_wheel_visual(wheel_fl, rubber_mat, rim_mat)
	_create_wheel_visual(wheel_fr, rubber_mat, rim_mat)
	_create_wheel_visual(wheel_rl, rubber_mat, rim_mat)
	_create_wheel_visual(wheel_rr, rubber_mat, rim_mat)

	# Headlights & Taillights
	var head_emissive: StandardMaterial3D = GraphicsManagerCore.create_emissive_material(Color(1.0, 0.95, 0.85, 1.0), 4.5)
	var hl_mesh: MeshInstance3D = MeshInstance3D.new()
	var hl_box: BoxMesh = BoxMesh.new()
	hl_box.size = Vector3(0.35, 0.12, 0.08)
	hl_mesh.mesh = hl_box
	hl_mesh.material_override = head_emissive
	hl_mesh.position = Vector3(-0.62, 0.52, 2.1)
	body_mesh_root.add_child(hl_mesh)

	var hr_mesh: MeshInstance3D = hl_mesh.duplicate() as MeshInstance3D
	hr_mesh.position.x = 0.62
	body_mesh_root.add_child(hr_mesh)

	# Headlight spotlights (beams)
	headlight_left = _create_headlight_beam(Vector3(-0.62, 0.52, 2.15))
	headlight_right = _create_headlight_beam(Vector3(0.62, 0.52, 2.15))
	add_child(headlight_left)
	add_child(headlight_right)

	# Taillights (glow red, brighten on brake)
	taillight_mat = GraphicsManagerCore.create_emissive_material(Color(0.9, 0.05, 0.05, 1.0), 2.2)
	var tl_mesh: MeshInstance3D = MeshInstance3D.new()
	var tl_box: BoxMesh = BoxMesh.new()
	tl_box.size = Vector3(0.38, 0.12, 0.08)
	tl_mesh.mesh = tl_box
	tl_mesh.material_override = taillight_mat
	tl_mesh.position = Vector3(-0.62, 0.55, -2.1)
	body_mesh_root.add_child(tl_mesh)

	var tr_mesh: MeshInstance3D = tl_mesh.duplicate() as MeshInstance3D
	tr_mesh.position.x = 0.62
	body_mesh_root.add_child(tr_mesh)

	# Markers for player seating & carjacking exit
	driver_seat_marker = Marker3D.new()
	driver_seat_marker.name = "DriverSeat"
	driver_seat_marker.position = Vector3(-0.38, 0.65, -0.15)
	add_child(driver_seat_marker)

	exit_door_marker = Marker3D.new()
	exit_door_marker.name = "ExitDoor"
	exit_door_marker.position = Vector3(-1.75, 0.1, -0.15)
	add_child(exit_door_marker)

func _create_headlight_beam(pos: Vector3) -> SpotLight3D:
	var sl: SpotLight3D = SpotLight3D.new()
	sl.position = pos
	sl.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
	sl.light_color = Color(1.0, 0.94, 0.82, 1.0)
	sl.light_energy = 2.8
	sl.spot_range = 35.0
	sl.spot_angle = 38.0
	sl.spot_attenuation = 1.2
	sl.shadow_enabled = true
	return sl

func _create_wheel_visual(wheel_node: VehicleWheel3D, tire_mat: Material, rim_mat: Material) -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "WheelVisual"
	
	# Tire
	var tire_mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 0.28
	cyl.radial_segments = 24
	tire_mesh.mesh = cyl
	tire_mesh.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	tire_mesh.material_override = tire_mat
	visual.add_child(tire_mesh)
	
	# Rim
	var rim_mesh: MeshInstance3D = MeshInstance3D.new()
	var rim_cyl: CylinderMesh = CylinderMesh.new()
	rim_cyl.top_radius = 0.25
	rim_cyl.bottom_radius = 0.25
	rim_cyl.height = 0.30
	rim_cyl.radial_segments = 16
	rim_mesh.mesh = rim_cyl
	rim_mesh.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rim_mesh.material_override = rim_mat
	visual.add_child(rim_mesh)
	
	wheel_node.add_child(visual)

func _setup_particles() -> void:
	smoke_particles_l = _create_tire_smoke_emitter(wheel_rl.position + Vector3(0.0, -0.2, -0.2))
	smoke_particles_r = _create_tire_smoke_emitter(wheel_rr.position + Vector3(0.0, -0.2, -0.2))
	add_child(smoke_particles_l)
	add_child(smoke_particles_r)

func _create_tire_smoke_emitter(pos: Vector3) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.position = pos
	p.emitting = false
	p.amount = 45
	p.lifetime = 0.8
	p.explosiveness = 0.05
	p.randomness = 0.5
	
	var pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0.0, 1.0, -1.0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3(0.0, 1.8, 0.0)
	pmat.scale_min = 0.3
	pmat.scale_max = 1.2
	pmat.color = Color(0.9, 0.9, 0.9, 0.45)
	p.process_material = pmat
	
	var quad: SphereMesh = SphereMesh.new()
	quad.radius = 0.3
	quad.height = 0.6
	var s_mat: StandardMaterial3D = StandardMaterial3D.new()
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.albedo_color = Color(0.85, 0.85, 0.85, 0.35)
	s_mat.roughness = 0.9
	quad.material = s_mat
	p.draw_pass_1 = quad
	return p

func _physics_process(delta: float) -> void:
	speed_kmh = linear_velocity.length() * 3.6
	
	match current_state:
		State.DRIVEN_BY_PLAYER:
			_process_player_driving(delta)
		State.DRIVEN_BY_AI:
			_process_ai_physics(delta)
		State.PARKED, State.DRIVER_ENTERING, State.DRIVER_EXITING:
			_process_parked(delta)
		State.WRECKED:
			engine_force = 0.0
			brake = max_brake_force

func _process_player_driving(delta: float) -> void:
	# Read user input
	input_steer = Input.get_axis("move_right", "move_left") # Godot 3D: positive Y rotation is left
	input_throttle = Input.get_action_strength("move_forward")
	input_brake = Input.get_action_strength("move_back")
	input_handbrake = Input.is_action_pressed("handbrake")
	
	# Speed-sensitive steering (taper maximum angle at high speeds)
	var speed_ratio: float = clampf(speed_kmh / top_speed_kmh, 0.0, 1.0)
	var dynamic_max_steer: float = lerpf(max_steering_angle, max_steering_angle * 0.35, speed_ratio)
	
	# Smooth steer transition
	var target_steer: float = input_steer * dynamic_max_steer
	current_steer_angle = move_toward(current_steer_angle, target_steer, delta * 3.2)
	
	# Apply Ackermann Steering Geometry
	_apply_ackermann_steering(current_steer_angle)
	
	# Handbrake Drift Slip Dynamics
	is_drifting = input_handbrake and speed_kmh > 15.0
	if is_drifting:
		wheel_rl.wheel_friction_slip = drift_friction_slip
		wheel_rr.wheel_friction_slip = drift_friction_slip
		smoke_particles_l.emitting = true
		smoke_particles_r.emitting = true
		AudioManagerCore.play_tire_screech(0.65)
		# Oversteer yaw torque kick
		if abs(current_steer_angle) > 0.05:
			apply_torque(Vector3(0.0, sign(current_steer_angle) * 1200.0, 0.0))
	else:
		wheel_rl.wheel_friction_slip = move_toward(wheel_rl.wheel_friction_slip, base_friction_slip, delta * 4.0)
		wheel_rr.wheel_friction_slip = move_toward(wheel_rr.wheel_friction_slip, base_friction_slip, delta * 4.0)
		smoke_particles_l.emitting = false
		smoke_particles_r.emitting = false

	# Engine Force & Transmission Curves
	var forward_dot: float = -transform.basis.z.dot(linear_velocity.normalized())
	if input_throttle > 0.0:
		# Forward acceleration curve: decreases as vehicle approaches top speed
		var power_curve: float = clampf(1.0 - (speed_kmh / top_speed_kmh), 0.05, 1.0)
		engine_force = input_throttle * max_engine_force * power_curve
		brake = 0.0
		taillight_mat.emission_energy_multiplier = 2.0
	elif input_brake > 0.0:
		if forward_dot > 0.1 and speed_kmh > 5.0:
			# Braking while in forward motion
			engine_force = 0.0
			brake = input_brake * max_brake_force
			taillight_mat.emission_energy_multiplier = 5.5 # Bright brake lights
		else:
			# Reverse gear
			var rev_curve: float = clampf(1.0 - (speed_kmh / reverse_top_speed_kmh), 0.0, 1.0)
			engine_force = -input_brake * max_engine_force * 0.65 * rev_curve
			brake = 0.0
			taillight_mat.emission_energy_multiplier = 3.0
	else:
		# Coasting / Engine resistance
		engine_force = 0.0
		brake = 4.0
		taillight_mat.emission_energy_multiplier = 2.0
		
	if input_handbrake:
		brake = max_brake_force * 0.85
		taillight_mat.emission_energy_multiplier = 5.0

	# Audio Manager Update
	var rpm_norm: float = clampf(speed_kmh / top_speed_kmh, 0.15, 1.0)
	if input_throttle > 0.0:
		rpm_norm = maxf(rpm_norm, 0.45 + input_throttle * 0.5)
	AudioManagerCore.set_engine_state(true, rpm_norm)
	
	# Check for Carjack Exit
	if Input.is_action_just_pressed("interact_vehicle"):
		carjack_exit()

func _apply_ackermann_steering(steer_center: float) -> void:
	if abs(steer_center) < 0.001:
		steering = 0.0
		wheel_fl.steering = 0.0
		wheel_fr.steering = 0.0
		return
	
	# Inner wheel turns at steeper angle than outer wheel
	var turn_radius: float = wheelbase / tan(abs(steer_center))
	var inner_angle: float = atan(wheelbase / (turn_radius - track_width * 0.5))
	var outer_angle: float = atan(wheelbase / (turn_radius + track_width * 0.5))
	
	if steer_center > 0.0:
		# Turning left
		wheel_fl.steering = inner_angle
		wheel_fr.steering = outer_angle
	else:
		# Turning right
		wheel_fl.steering = -outer_angle
		wheel_fr.steering = -inner_angle
	
	steering = steer_center

func _process_parked(delta: float) -> void:
	engine_force = 0.0
	brake = 30.0
	steering = move_toward(steering, 0.0, delta * 2.0)
	smoke_particles_l.emitting = false
	smoke_particles_r.emitting = false

func _process_ai_physics(delta: float) -> void:
	# Virtual inputs driven by AI script (police or traffic)
	var speed_ratio: float = clampf(speed_kmh / top_speed_kmh, 0.0, 1.0)
	var dynamic_max_steer: float = lerpf(max_steering_angle, max_steering_angle * 0.4, speed_ratio)
	current_steer_angle = move_toward(current_steer_angle, input_steer * dynamic_max_steer, delta * 3.5)
	_apply_ackermann_steering(current_steer_angle)
	
	if input_throttle > 0.0:
		var p_curve: float = clampf(1.0 - (speed_kmh / top_speed_kmh), 0.05, 1.0)
		engine_force = input_throttle * max_engine_force * p_curve
		brake = 0.0
	elif input_brake > 0.0:
		engine_force = 0.0
		brake = input_brake * max_brake_force
	else:
		engine_force = 0.0
		brake = 10.0

## Carjacking: Swaps control authority from Player character to Vehicle
func carjack_enter(player: CharacterBody3D) -> void:
	if current_state != State.PARKED and current_state != State.DRIVEN_BY_AI:
		return
	
	driver_ref = player
	current_state = State.DRIVEN_BY_PLAYER
	
	# Disable player body and hide
	player.set_physics_process(false)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	
	# Switch camera focus smoothly to vehicle
	if player.has_node("SpringArm3D"):
		var spring_arm: SpringArm3D = player.get_node("SpringArm3D") as SpringArm3D
		player.remove_child(spring_arm)
		add_child(spring_arm)
		spring_arm.position = Vector3(0.0, 1.6, 0.0)
		spring_arm.spring_length = 5.5
	
	AudioManagerCore.set_engine_state(true, 0.25)
	AudioManagerCore.play_car_horn(0.4)
	player_entered_vehicle.emit(self)
	
	# Increase crime if stealing occupied vehicle
	if GameDirectorCore.instance:
		GameDirectorCore.instance.report_crime("carjacking", global_position)

## Exiting Vehicle: Safely re-spawns player beside driver door and returns camera
func carjack_exit() -> void:
	if current_state != State.DRIVEN_BY_PLAYER or not driver_ref:
		return
	
	current_state = State.DRIVER_EXITING
	
	# Return SpringArm3D to player
	var spring_arm: SpringArm3D = find_child("SpringArm3D", false, false) as SpringArm3D
	if spring_arm:
		remove_child(spring_arm)
		driver_ref.add_child(spring_arm)
		spring_arm.position = Vector3(0.0, 1.6, 0.0)
		spring_arm.spring_length = 3.8
	
	# Reposition player at exit door marker
	var exit_pos: Vector3 = global_position + Vector3(-1.75, 0.1, -0.15)
	if is_inside_tree() and is_instance_valid(exit_door_marker) and exit_door_marker.is_inside_tree():
		exit_pos = exit_door_marker.global_position
	# Ensure on ground
	exit_pos.y = maxf(exit_pos.y, 0.8)
	if driver_ref.is_inside_tree():
		driver_ref.global_position = exit_pos
	else:
		driver_ref.position = exit_pos
	driver_ref.rotation.y = rotation.y
	driver_ref.velocity = Vector3.ZERO
	driver_ref.visible = true
	driver_ref.collision_layer = 1
	driver_ref.collision_mask = 1
	driver_ref.set_physics_process(true)
	
	AudioManagerCore.set_engine_state(false, 0.0)
	player_exited_vehicle.emit(self)
	
	driver_ref = null
	current_state = State.PARKED

## Damage handling
func take_damage(amount: float) -> void:
	if current_state == State.WRECKED:
		return
	current_health = maxf(0.0, current_health - amount)
	vehicle_damaged.emit(current_health, max_health)
	AudioManagerCore.play_impact(0.8)
	
	if current_health <= 0.0:
		_explode_vehicle()

func _explode_vehicle() -> void:
	current_state = State.WRECKED
	AudioManagerCore.play_impact(1.0)
	AudioManagerCore.play_gunshot(1.0)
	vehicle_destroyed.emit(self)
	
	# Eject player if inside
	if driver_ref:
		driver_ref.take_damage(65.0)
		carjack_exit()
		
	# Black charred appearance
	var charred_mat: StandardMaterial3D = StandardMaterial3D.new()
	charred_mat.albedo_color = Color(0.08, 0.08, 0.08, 1.0)
	charred_mat.metallic = 0.0
	charred_mat.roughness = 0.95
	body_mesh_root.material_override = charred_mat
