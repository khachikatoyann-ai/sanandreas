class_name PlayerCharacter
extends CharacterBody3D

## PlayerCharacter: Production-grade 3D third-person character with smooth locomotion,
## procedural jump physics, orbiting SpringArm3D camera, raycast hitscan combat,
## muzzle flash bloom FX, and proximity-based vehicle hijacking.

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 9.2
@export var acceleration: float = 24.0
@export var friction: float = 28.0
@export var jump_velocity: float = 7.6
@export var mouse_sensitivity: float = 0.003
@export var touch_sensitivity: float = 0.004

var current_health: float = 100.0
var max_health: float = 100.0
var current_armor: float = 100.0
var max_armor: float = 100.0
var current_ammo: int = 180
var max_ammo: int = 300

# Camera nodes
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var cam_rot_x: float = -0.15 # Pitch
var cam_rot_y: float = 0.0   # Yaw

# Visual Model Nodes
var visual_root: Node3D
var torso_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var weapon_mesh: MeshInstance3D

# Combat & Weapon FX
var weapon_raycast: RayCast3D
var muzzle_particles: GPUParticles3D
var muzzle_light: OmniLight3D
var fire_cooldown: float = 0.11
var fire_timer: float = 0.0
var recoil_kick: float = 0.0

# Vehicle Hijacking Area
var vehicle_detect_area: Area3D
var nearby_vehicles: Array[VehicleController] = []
var closest_vehicle: VehicleController = null

# Procedural animation parameters
var anim_walk_phase: float = 0.0
var coyote_timer: float = 0.0

# Signals
signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)
signal nearby_vehicle_updated(vehicle: VehicleController)

func _ready() -> void:
	_setup_collision()
	_setup_camera_rig()
	_build_character_visuals()
	_setup_combat_rig()
	_setup_vehicle_hijack_area()
	
	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)
	ammo_changed.emit(current_ammo, max_ammo)

func _setup_collision() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "PlayerCollision"
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.82
	col.shape = cap
	col.position = Vector3(0.0, 0.91, 0.0)
	add_child(col)

func _setup_camera_rig() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(camera_pivot)
	
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 3.6
	spring_arm.margin = 0.28
	spring_arm.add_excluded_object(get_rid())
	camera_pivot.add_child(spring_arm)
	
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = 75.0
	spring_arm.add_child(camera)

func _build_character_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	# Stylized PBR Materials
	var skin_mat: StandardMaterial3D = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.42, 0.28, 0.22, 1.0) # Deep warm skin tone
	skin_mat.roughness = 0.65

	var tank_top_mat: StandardMaterial3D = StandardMaterial3D.new()
	tank_top_mat.albedo_color = Color(0.92, 0.92, 0.90, 1.0) # White ribbed tank top
	tank_top_mat.roughness = 0.75

	var jeans_mat: StandardMaterial3D = StandardMaterial3D.new()
	jeans_mat.albedo_color = Color(0.18, 0.26, 0.42, 1.0) # Classic San Andreas blue denim
	jeans_mat.roughness = 0.85

	var shoes_mat: StandardMaterial3D = StandardMaterial3D.new()
	shoes_mat.albedo_color = Color(0.12, 0.12, 0.12, 1.0) # Black sneakers

	# Torso
	torso_mesh = MeshInstance3D.new()
	var t_box: BoxMesh = BoxMesh.new()
	t_box.size = Vector3(0.48, 0.58, 0.26)
	torso_mesh.mesh = t_box
	torso_mesh.position = Vector3(0.0, 1.15, 0.0)
	torso_mesh.material_override = tank_top_mat
	visual_root.add_child(torso_mesh)

	# Head
	head_mesh = MeshInstance3D.new()
	var h_box: BoxMesh = BoxMesh.new()
	h_box.size = Vector3(0.26, 0.28, 0.26)
	head_mesh.mesh = h_box
	head_mesh.position = Vector3(0.0, 1.62, 0.0)
	head_mesh.material_override = skin_mat
	visual_root.add_child(head_mesh)

	# Sunglasses
	var sun_glasses: MeshInstance3D = MeshInstance3D.new()
	var sg_box: BoxMesh = BoxMesh.new()
	sg_box.size = Vector3(0.28, 0.08, 0.06)
	sun_glasses.mesh = sg_box
	sun_glasses.position = Vector3(0.0, 1.64, 0.14)
	var shades_mat: StandardMaterial3D = StandardMaterial3D.new()
	shades_mat.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
	shades_mat.metallic = 0.9
	shades_mat.roughness = 0.1
	sun_glasses.material_override = shades_mat
	visual_root.add_child(sun_glasses)

	# Left Arm
	arm_left = Node3D.new()
	arm_left.position = Vector3(-0.32, 1.38, 0.0)
	var al_mesh: MeshInstance3D = MeshInstance3D.new()
	var a_box: BoxMesh = BoxMesh.new()
	a_box.size = Vector3(0.14, 0.55, 0.14)
	al_mesh.mesh = a_box
	al_mesh.position = Vector3(0.0, -0.22, 0.0)
	al_mesh.material_override = skin_mat
	arm_left.add_child(al_mesh)
	visual_root.add_child(arm_left)

	# Right Arm (Weapon holding arm)
	arm_right = Node3D.new()
	arm_right.position = Vector3(0.32, 1.38, 0.0)
	var ar_mesh: MeshInstance3D = MeshInstance3D.new()
	ar_mesh.mesh = a_box
	ar_mesh.position = Vector3(0.0, -0.22, 0.0)
	ar_mesh.material_override = skin_mat
	arm_right.add_child(ar_mesh)
	visual_root.add_child(arm_right)

	# Left Leg
	leg_left = Node3D.new()
	leg_left.position = Vector3(-0.16, 0.85, 0.0)
	var ll_mesh: MeshInstance3D = MeshInstance3D.new()
	var l_box: BoxMesh = BoxMesh.new()
	l_box.size = Vector3(0.18, 0.72, 0.20)
	ll_mesh.mesh = l_box
	ll_mesh.position = Vector3(0.0, -0.32, 0.0)
	ll_mesh.material_override = jeans_mat
	leg_left.add_child(ll_mesh)
	
	# Left Shoe
	var shoe_l: MeshInstance3D = MeshInstance3D.new()
	var s_box: BoxMesh = BoxMesh.new()
	s_box.size = Vector3(0.20, 0.12, 0.32)
	shoe_l.mesh = s_box
	shoe_l.position = Vector3(0.0, -0.72, 0.05)
	shoe_l.material_override = shoes_mat
	leg_left.add_child(shoe_l)
	visual_root.add_child(leg_left)

	# Right Leg
	leg_right = Node3D.new()
	leg_right.position = Vector3(0.16, 0.85, 0.0)
	var lr_mesh: MeshInstance3D = MeshInstance3D.new()
	lr_mesh.mesh = l_box
	lr_mesh.position = Vector3(0.0, -0.32, 0.0)
	lr_mesh.material_override = jeans_mat
	leg_right.add_child(lr_mesh)

	# Right Shoe
	var shoe_r: MeshInstance3D = shoe_l.duplicate() as MeshInstance3D
	leg_right.add_child(shoe_r)
	visual_root.add_child(leg_right)

	# Weapon Model (Micro-SMG in right hand)
	weapon_mesh = MeshInstance3D.new()
	var w_box: BoxMesh = BoxMesh.new()
	w_box.size = Vector3(0.08, 0.16, 0.42)
	weapon_mesh.mesh = w_box
	weapon_mesh.position = Vector3(0.0, -0.38, 0.22)
	var gun_mat: StandardMaterial3D = StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.15, 0.15, 0.16, 1.0)
	gun_mat.metallic = 0.95
	gun_mat.roughness = 0.25
	weapon_mesh.material_override = gun_mat
	arm_right.add_child(weapon_mesh)

func _setup_combat_rig() -> void:
	# Raycast from camera center for pinpoint hitscan accuracy
	weapon_raycast = RayCast3D.new()
	weapon_raycast.name = "HitscanRaycast"
	weapon_raycast.target_position = Vector3(0.0, 0.0, -120.0)
	weapon_raycast.collide_with_areas = true
	weapon_raycast.collide_with_bodies = true
	camera.add_child(weapon_raycast)

	# Muzzle Flash Particles
	muzzle_particles = GPUParticles3D.new()
	muzzle_particles.name = "MuzzleParticles"
	muzzle_particles.emitting = false
	muzzle_particles.one_shot = true
	muzzle_particles.amount = 16
	muzzle_particles.lifetime = 0.08
	muzzle_particles.explosiveness = 1.0
	
	var pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pmat.direction = Vector3(0.0, 0.0, 1.0)
	pmat.spread = 25.0
	pmat.initial_velocity_min = 8.0
	pmat.initial_velocity_max = 16.0
	pmat.scale_min = 0.15
	pmat.scale_max = 0.35
	pmat.color = Color(1.0, 0.85, 0.3, 1.0)
	muzzle_particles.process_material = pmat
	
	var quad: SphereMesh = SphereMesh.new()
	quad.radius = 0.08
	quad.height = 0.16
	var f_mat: StandardMaterial3D = GraphicsManagerCore.create_emissive_material(Color(1.0, 0.75, 0.2, 1.0), 6.0)
	quad.material = f_mat
	muzzle_particles.draw_pass_1 = quad
	weapon_mesh.add_child(muzzle_particles)
	muzzle_particles.position = Vector3(0.0, 0.04, 0.24)

	# Dynamic OmniLight3D Flash (exceeds 0.9 threshold for HDR bloom flare)
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.light_color = Color(1.0, 0.82, 0.4, 1.0)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 6.0
	muzzle_light.shadow_enabled = false
	weapon_mesh.add_child(muzzle_light)

func _setup_vehicle_hijack_area() -> void:
	vehicle_detect_area = Area3D.new()
	vehicle_detect_area.name = "VehicleDetectArea"
	var col: CollisionShape3D = CollisionShape3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 3.4
	col.shape = sph
	col.position = Vector3(0.0, 0.8, 0.0)
	vehicle_detect_area.add_child(col)
	vehicle_detect_area.collision_layer = 0
	vehicle_detect_area.collision_mask = 1 | 2 # Default & Vehicle layer
	add_child(vehicle_detect_area)
	
	vehicle_detect_area.body_entered.connect(_on_vehicle_detect_entered)
	vehicle_detect_area.body_exited.connect(_on_vehicle_detect_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Mouse look camera orbiting
		rotate_camera_look(Vector2(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity))

## Public helper for both mouse look and mobile HUD virtual touch drag
func rotate_camera_look(delta: Vector2) -> void:
	cam_rot_y += delta.x
	cam_rot_x = clampf(cam_rot_x + delta.y, -1.22, 0.75) # -70 to +43 degrees
	
	camera_pivot.rotation.y = cam_rot_y
	spring_arm.rotation.x = cam_rot_x

func _physics_process(delta: float) -> void:
	# Gravity & Coyote Time
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		coyote_timer = maxf(0.0, coyote_timer - delta)
	else:
		coyote_timer = 0.12
		if velocity.y < 0.0:
			velocity.y = -0.5
	
	# Movement Input
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_z: float = Input.get_axis("move_forward", "move_back")
	var move_dir: Vector3 = Vector3.ZERO
	
	if input_x != 0.0 or input_z != 0.0:
		var cam_basis: Basis = camera_pivot.global_transform.basis
		var forward: Vector3 = -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right: Vector3 = cam_basis.x
		right.y = 0.0
		right = right.normalized()
		move_dir = (right * input_x + forward * -input_z).normalized()
	
	# Sprint modifier
	var is_sprinting: bool = Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	
	# Smooth acceleration / deceleration
	var target_vel_h: Vector3 = move_dir * target_speed
	var current_vel_h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	
	if move_dir.length_squared() > 0.01:
		current_vel_h = current_vel_h.move_toward(target_vel_h, acceleration * delta)
		# Face movement direction
		var target_rot_y: float = atan2(move_dir.x, move_dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot_y, delta * 14.0)
	else:
		current_vel_h = current_vel_h.move_toward(Vector3.ZERO, friction * delta)
	
	velocity.x = current_vel_h.x
	velocity.z = current_vel_h.z
	
	# Jump
	if Input.is_action_just_pressed("jump") and coyote_timer > 0.0:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		AudioManagerCore.play_impact(0.3)
	
	move_and_slide()
	
	# Combat Processing
	_process_combat(delta)
	
	# Procedural Animation update
	_update_procedural_animations(delta, current_vel_h.length())
	
	# Vehicle hijacking input
	_process_vehicle_interaction()

func _process_combat(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	
	# Muzzle light flash fade
	if muzzle_light.light_energy > 0.0:
		muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, delta * 35.0)
	
	if recoil_kick > 0.0:
		recoil_kick = move_toward(recoil_kick, 0.0, delta * 12.0)
		arm_right.rotation.x = -recoil_kick
	
	if Input.is_action_pressed("fire") and fire_timer <= 0.0 and current_ammo > 0:
		_execute_hitscan_shot()

func _execute_hitscan_shot() -> void:
	fire_timer = fire_cooldown
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	
	# Audio & Visual FX
	AudioManagerCore.play_gunshot(0.9)
	muzzle_particles.restart()
	muzzle_particles.emitting = true
	muzzle_light.light_energy = 4.2 # Triggers ACES HDR bloom!
	recoil_kick = 0.35
	
	# Align visual torso towards camera when firing
	visual_root.rotation.y = camera_pivot.rotation.y
	
	# Raycast hit resolution
	weapon_raycast.force_raycast_update()
	if weapon_raycast.is_colliding():
		var hit_collider: Object = weapon_raycast.get_collider()
		var hit_point: Vector3 = weapon_raycast.get_collision_point()
		
		if hit_collider.has_method("take_damage"):
			hit_collider.take_damage(28.0)
		elif hit_collider is VehicleController:
			hit_collider.take_damage(35.0)
		
		# Spawn impact FX
		AudioManagerCore.play_impact(0.5)
	
	# Report crime to GameDirector
	if GameDirectorCore.instance:
		GameDirectorCore.instance.report_crime("gunfire", global_position)

func _update_procedural_animations(delta: float, horiz_speed: float) -> void:
	if not is_on_floor():
		# Jump pose
		leg_left.rotation.x = 0.5
		leg_right.rotation.x = -0.3
		arm_left.rotation.x = -0.6
		return
	
	if horiz_speed > 0.2:
		anim_walk_phase += delta * horiz_speed * 1.8
		var leg_swing: float = sin(anim_walk_phase) * 0.75
		leg_left.rotation.x = leg_swing
		leg_right.rotation.x = -leg_swing
		arm_left.rotation.x = -leg_swing * 0.8
		
		# Bobbing
		torso_mesh.position.y = 1.15 + abs(sin(anim_walk_phase * 2.0)) * 0.05
	else:
		# Idle pose
		leg_left.rotation.x = move_toward(leg_left.rotation.x, 0.0, delta * 6.0)
		leg_right.rotation.x = move_toward(leg_right.rotation.x, 0.0, delta * 6.0)
		arm_left.rotation.x = move_toward(arm_left.rotation.x, 0.0, delta * 6.0)
		torso_mesh.position.y = move_toward(torso_mesh.position.y, 1.15, delta * 2.0)

func _on_vehicle_detect_entered(body: Node3D) -> void:
	if body is VehicleController and not nearby_vehicles.has(body):
		nearby_vehicles.append(body)
		_update_closest_vehicle()

func _on_vehicle_detect_exited(body: Node3D) -> void:
	if body is VehicleController and nearby_vehicles.has(body):
		nearby_vehicles.erase(body)
		_update_closest_vehicle()

func _update_closest_vehicle() -> void:
	closest_vehicle = null
	var min_dist: float = 9999.0
	for veh: VehicleController in nearby_vehicles:
		if is_instance_valid(veh) and veh.current_state != VehicleController.State.WRECKED:
			var d: float = global_position.distance_to(veh.global_position)
			if d < min_dist:
				min_dist = d
				closest_vehicle = veh
	nearby_vehicle_updated.emit(closest_vehicle)

func _process_vehicle_interaction() -> void:
	if Input.is_action_just_pressed("interact_vehicle") and closest_vehicle:
		closest_vehicle.carjack_enter(self)

## Damage & Health
func take_damage(amount: float) -> void:
	if current_armor > 0.0:
		var armor_dmg: float = minf(current_armor, amount * 0.7)
		current_armor -= armor_dmg
		amount -= armor_dmg
		armor_changed.emit(current_armor, max_armor)
	
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	AudioManagerCore.play_impact(0.9)
	
	if current_health <= 0.0:
		_die()

func _die() -> void:
	# Waste screen effect / respawn
	if GameDirectorCore.instance:
		GameDirectorCore.instance.on_player_died()
