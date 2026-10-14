class_name PedestrianNPC
extends CharacterBody3D

## PedestrianNPC: Civilian pedestrian that wanders sidewalks, panics and flees
## when gunshots are fired, reacts to incoming vehicles, and drops cash when neutralized.

enum State {
	WANDERING,
	PANIC_FLEEING,
	KNOCKED_DOWN
}

@export var walk_speed: float = 2.2
@export var sprint_speed: float = 6.8

var current_state: State = State.WANDERING
var current_health: float = 45.0
var move_direction: Vector3 = Vector3.FORWARD
var state_timer: float = 0.0
var panic_origin: Vector3 = Vector3.ZERO

# Visual Nodes
var visual_root: Node3D
var torso_mesh: MeshInstance3D
var leg_left: Node3D
var leg_right: Node3D
var arm_left: Node3D
var arm_right: Node3D
var anim_phase: float = 0.0

func _ready() -> void:
	_setup_collision()
	_build_visuals()
	_pick_random_wander_direction()
	
	if GameDirectorCore.instance:
		GameDirectorCore.instance.crime_committed.connect(_on_crime_committed)

func _setup_collision() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0.0, 0.88, 0.0)
	add_child(col)

func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "PedVisualRoot"
	add_child(visual_root)

	# Randomize outfit colors for diversity
	var shirt_colors: Array[Color] = [
		Color(0.2, 0.6, 0.8), # Cyan tee
		Color(0.85, 0.3, 0.2), # Red shirt
		Color(0.2, 0.7, 0.3), # Green polo
		Color(0.85, 0.75, 0.2), # Yellow hoodie
		Color(0.7, 0.3, 0.8), # Purple
		Color(0.9, 0.9, 0.9)  # White
	]
	var pants_colors: Array[Color] = [
		Color(0.15, 0.18, 0.25), # Dark jeans
		Color(0.55, 0.48, 0.38), # Khakis
		Color(0.12, 0.12, 0.12)  # Black pants
	]
	
	var shirt_mat: StandardMaterial3D = StandardMaterial3D.new()
	shirt_mat.albedo_color = shirt_colors.pick_random()
	shirt_mat.roughness = 0.8
	
	var pants_mat: StandardMaterial3D = StandardMaterial3D.new()
	pants_mat.albedo_color = pants_colors.pick_random()
	pants_mat.roughness = 0.85
	
	var skin_mat: StandardMaterial3D = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.55, 0.38, 0.30, 1.0)
	skin_mat.roughness = 0.6

	# Torso
	torso_mesh = MeshInstance3D.new()
	var t_box: BoxMesh = BoxMesh.new()
	t_box.size = Vector3(0.44, 0.54, 0.24)
	torso_mesh.mesh = t_box
	torso_mesh.position = Vector3(0.0, 1.1, 0.0)
	torso_mesh.material_override = shirt_mat
	visual_root.add_child(torso_mesh)

	# Head
	var head_mesh: MeshInstance3D = MeshInstance3D.new()
	var h_box: BoxMesh = BoxMesh.new()
	h_box.size = Vector3(0.24, 0.26, 0.24)
	head_mesh.mesh = h_box
	head_mesh.position = Vector3(0.0, 1.52, 0.0)
	head_mesh.material_override = skin_mat
	visual_root.add_child(head_mesh)

	# Left Arm
	arm_left = Node3D.new()
	arm_left.position = Vector3(-0.28, 1.3, 0.0)
	var al_mesh: MeshInstance3D = MeshInstance3D.new()
	var a_box: BoxMesh = BoxMesh.new()
	a_box.size = Vector3(0.12, 0.5, 0.12)
	al_mesh.mesh = a_box
	al_mesh.position = Vector3(0.0, -0.22, 0.0)
	al_mesh.material_override = shirt_mat
	arm_left.add_child(al_mesh)
	visual_root.add_child(arm_left)

	# Right Arm
	arm_right = Node3D.new()
	arm_right.position = Vector3(0.28, 1.3, 0.0)
	var ar_mesh: MeshInstance3D = al_mesh.duplicate() as MeshInstance3D
	arm_right.add_child(ar_mesh)
	visual_root.add_child(arm_right)

	# Legs
	leg_left = Node3D.new()
	leg_left.position = Vector3(-0.14, 0.8, 0.0)
	var ll_mesh: MeshInstance3D = MeshInstance3D.new()
	var l_box: BoxMesh = BoxMesh.new()
	l_box.size = Vector3(0.16, 0.7, 0.18)
	ll_mesh.mesh = l_box
	ll_mesh.position = Vector3(0.0, -0.32, 0.0)
	ll_mesh.material_override = pants_mat
	leg_left.add_child(ll_mesh)
	visual_root.add_child(leg_left)

	leg_right = Node3D.new()
	leg_right.position = Vector3(0.14, 0.8, 0.0)
	var lr_mesh: MeshInstance3D = ll_mesh.duplicate() as MeshInstance3D
	leg_right.add_child(lr_mesh)
	visual_root.add_child(leg_right)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.5

	match current_state:
		State.WANDERING:
			_process_wandering(delta)
		State.PANIC_FLEEING:
			_process_fleeing(delta)
		State.KNOCKED_DOWN:
			velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)

	move_and_slide()
	_update_ped_animation(delta)

func _process_wandering(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_pick_random_wander_direction()

	var target_vel: Vector3 = move_direction * walk_speed
	velocity.x = move_toward(velocity.x, target_vel.x, delta * 10.0)
	velocity.z = move_toward(velocity.z, target_vel.z, delta * 10.0)
	
	if move_direction.length_squared() > 0.01:
		var target_rot: float = atan2(move_direction.x, move_direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot, delta * 8.0)

func _process_fleeing(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.WANDERING
		_pick_random_wander_direction()
		return

	# Run away from panic origin
	var flee_vec: Vector3 = (global_position - panic_origin)
	flee_vec.y = 0.0
	if flee_vec.length_squared() < 0.1:
		flee_vec = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	flee_vec = flee_vec.normalized()
	
	var target_vel: Vector3 = flee_vec * sprint_speed
	velocity.x = move_toward(velocity.x, target_vel.x, delta * 16.0)
	velocity.z = move_toward(velocity.z, target_vel.z, delta * 16.0)

	var target_rot: float = atan2(flee_vec.x, flee_vec.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot, delta * 16.0)

func _pick_random_wander_direction() -> void:
	state_timer = randf_range(4.0, 9.0)
	# Align mainly along city grid axes (X or Z)
	if randf() > 0.5:
		move_direction = Vector3(1.0 if randf() > 0.5 else -1.0, 0.0, 0.0)
	else:
		move_direction = Vector3(0.0, 0.0, 1.0 if randf() > 0.5 else -1.0)

func _update_ped_animation(delta: float) -> void:
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if current_state == State.KNOCKED_DOWN:
		visual_root.rotation.x = PI * 0.5 # Lie flat
		return

	visual_root.rotation.x = 0.0
	if horiz_speed > 0.2:
		anim_phase += delta * horiz_speed * 2.2
		var swing: float = sin(anim_phase) * 0.7
		leg_left.rotation.x = swing
		leg_right.rotation.x = -swing
		
		if current_state == State.PANIC_FLEEING:
			# Hands in the air waving in panic!
			arm_left.rotation.x = -2.2 + sin(anim_phase * 1.5) * 0.4
			arm_right.rotation.x = -2.2 - sin(anim_phase * 1.5) * 0.4
		else:
			arm_left.rotation.x = -swing * 0.7
			arm_right.rotation.x = swing * 0.7
	else:
		leg_left.rotation.x = 0.0
		leg_right.rotation.x = 0.0
		arm_left.rotation.x = 0.0
		arm_right.rotation.x = 0.0

func _on_crime_committed(crime_type: String, location: Vector3) -> void:
	var dist: float = global_position.distance_to(location)
	if dist < 45.0 and current_state != State.KNOCKED_DOWN:
		panic_origin = location
		current_state = State.PANIC_FLEEING
		state_timer = randf_range(8.0, 15.0)

func take_damage(amount: float) -> void:
	current_health -= amount
	AudioManagerCore.play_impact(0.6)
	
	if current_health <= 0.0 and current_state != State.KNOCKED_DOWN:
		_knockdown()

func _knockdown() -> void:
	current_state = State.KNOCKED_DOWN
	# Drop cash reward
	_drop_cash()
	if GameDirectorCore.instance:
		GameDirectorCore.instance.report_crime("pedestrian_hit", global_position)

func _drop_cash() -> void:
	var drop_amount: int = randi_range(75, 280)
	if GameDirectorCore.instance:
		GameDirectorCore.instance.add_cash(drop_amount)
		AudioManagerCore.play_cash_pickup(0.9)
