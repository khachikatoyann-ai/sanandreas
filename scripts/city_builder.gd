class_name CityBuilder
extends Node3D

## CityBuilder: Generates a complete 3D open-world Los Santos sandbox district.
## Features multi-lane asphalt avenues, crosswalks, concrete sidewalks, California palm trees,
## street lamps, downtown skyscrapers with night windows, billboard signs, stunt ramps,
## beachfront coastline, and drivable sports cars ready for carjacking.

@export var block_size: float = 70.0
@export var road_width: float = 16.0
@export var sidewalk_width: float = 3.5
@export var grid_x_blocks: int = 5
@export var grid_z_blocks: int = 5

# Materials Cache
var asphalt_mat: StandardMaterial3D
var road_line_mat: StandardMaterial3D
var sidewalk_mat: StandardMaterial3D
var curb_mat: StandardMaterial3D
var palm_trunk_mat: StandardMaterial3D
var palm_frond_mat: StandardMaterial3D
var building_mats: Array[StandardMaterial3D] = []
var window_mat: StandardMaterial3D
var beach_sand_mat: StandardMaterial3D
var ocean_mat: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	_generate_city_grid()
	_generate_beachfront()
	_spawn_parked_vehicles()
	_spawn_initial_pedestrians()

func _init_materials() -> void:
	asphalt_mat = GraphicsManagerCore.create_asphalt_material()
	sidewalk_mat = GraphicsManagerCore.create_sidewalk_material()
	
	road_line_mat = StandardMaterial3D.new()
	road_line_mat.albedo_color = Color(0.95, 0.85, 0.2, 1.0) # Yellow road stripes
	road_line_mat.roughness = 0.5
	
	curb_mat = StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.5, 0.5, 0.52, 1.0)
	curb_mat.roughness = 0.7
	
	palm_trunk_mat = StandardMaterial3D.new()
	palm_trunk_mat.albedo_color = Color(0.38, 0.26, 0.18, 1.0)
	palm_trunk_mat.roughness = 0.9
	
	palm_frond_mat = StandardMaterial3D.new()
	palm_frond_mat.albedo_color = Color(0.18, 0.45, 0.16, 1.0)
	palm_frond_mat.roughness = 0.7
	
	window_mat = GraphicsManagerCore.create_emissive_material(Color(1.0, 0.88, 0.55, 1.0), 1.8)
	
	beach_sand_mat = StandardMaterial3D.new()
	beach_sand_mat.albedo_color = Color(0.88, 0.78, 0.52, 1.0)
	beach_sand_mat.roughness = 0.92
	
	ocean_mat = StandardMaterial3D.new()
	ocean_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ocean_mat.albedo_color = Color(0.08, 0.45, 0.65, 0.85)
	ocean_mat.metallic = 0.9
	ocean_mat.roughness = 0.1
	
	# Diverse building facade materials
	var colors: Array[Color] = [
		Color(0.25, 0.26, 0.28), # Charcoal glass tower
		Color(0.82, 0.78, 0.72), # Sandstone deco
		Color(0.35, 0.42, 0.48), # Slate blue steel
		Color(0.72, 0.45, 0.35), # Brick plaza
		Color(0.92, 0.90, 0.88)  # White modern luxury highrise
	]
	for c: Color in colors:
		var bm: StandardMaterial3D = StandardMaterial3D.new()
		bm.albedo_color = c
		bm.metallic = 0.35
		bm.roughness = 0.4
		building_mats.append(bm)

func _generate_city_grid() -> void:
	var roads_root: Node3D = Node3D.new()
	roads_root.name = "RoadsAndSidewalks"
	add_child(roads_root)

	var buildings_root: Node3D = Node3D.new()
	buildings_root.name = "DowntownSkyline"
	add_child(buildings_root)

	var props_root: Node3D = Node3D.new()
	props_root.name = "PropsAndTrees"
	add_child(props_root)

	var half_x: float = (grid_x_blocks * block_size) * 0.5
	var half_z: float = (grid_z_blocks * block_size) * 0.5

	# Generate Ground & Road Network
	for bx in range(-grid_x_blocks / 2, grid_x_blocks / 2 + 1):
		for bz in range(-grid_z_blocks / 2, grid_z_blocks / 2 + 1):
			var center: Vector3 = Vector3(bx * block_size, 0.0, bz * block_size)
			
			# Road intersection / avenue segment
			_create_road_segment(roads_root, center)
			
			# City Block (Buildings & Sidewalks) inside each quadrant
			if bx != grid_x_blocks / 2 and bz != grid_z_blocks / 2:
				var block_center: Vector3 = center + Vector3(block_size * 0.5, 0.0, block_size * 0.5)
				_create_city_block(buildings_root, props_root, block_center)

	# Stunt Ramps in open avenues
	_create_stunt_ramp(props_root, Vector3(0.0, 0.0, 35.0), 0.0)
	_create_stunt_ramp(props_root, Vector3(-70.0, 0.0, -35.0), PI * 0.5)

func _create_road_segment(parent: Node3D, pos: Vector3) -> void:
	# Main Road Surface
	var road_body: StaticBody3D = StaticBody3D.new()
	road_body.position = pos
	
	var col: CollisionShape3D = CollisionShape3D.new()
	var box_col: BoxShape3D = BoxShape3D.new()
	box_col.size = Vector3(block_size, 0.3, road_width)
	col.shape = box_col
	col.position = Vector3(0.0, -0.15, 0.0)
	road_body.add_child(col)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var r_mesh: BoxMesh = BoxMesh.new()
	r_mesh.size = Vector3(block_size, 0.3, road_width)
	mesh_inst.mesh = r_mesh
	mesh_inst.position = Vector3(0.0, -0.15, 0.0)
	mesh_inst.material_override = asphalt_mat
	road_body.add_child(mesh_inst)

	# Cross Avenue
	var col_cross: CollisionShape3D = CollisionShape3D.new()
	var box_col_cross: BoxShape3D = BoxShape3D.new()
	box_col_cross.size = Vector3(road_width, 0.3, block_size)
	col_cross.shape = box_col_cross
	col_cross.position = Vector3(0.0, -0.15, 0.0)
	road_body.add_child(col_cross)

	var cross_mesh: MeshInstance3D = MeshInstance3D.new()
	var c_box: BoxMesh = BoxMesh.new()
	c_box.size = Vector3(road_width, 0.3, block_size)
	cross_mesh.mesh = c_box
	cross_mesh.position = Vector3(0.0, -0.15, 0.0)
	cross_mesh.material_override = asphalt_mat
	road_body.add_child(cross_mesh)

	# Centerline Yellow Road Marking Stripes
	var line_mesh: MeshInstance3D = MeshInstance3D.new()
	var l_box: BoxMesh = BoxMesh.new()
	l_box.size = Vector3(block_size - road_width, 0.02, 0.28)
	line_mesh.mesh = l_box
	line_mesh.position = Vector3(0.0, 0.01, 0.0)
	line_mesh.material_override = road_line_mat
	road_body.add_child(line_mesh)

	parent.add_child(road_body)

func _create_city_block(buildings_parent: Node3D, props_parent: Node3D, center: Vector3) -> void:
	var inner_size: float = block_size - road_width
	
	# Sidewalk Platform
	var sw_body: StaticBody3D = StaticBody3D.new()
	sw_body.position = center
	
	var col: CollisionShape3D = CollisionShape3D.new()
	var b_col: BoxShape3D = BoxShape3D.new()
	b_col.size = Vector3(inner_size, 0.45, inner_size)
	col.shape = b_col
	col.position = Vector3(0.0, 0.1, 0.0)
	sw_body.add_child(col)

	var sw_mesh: MeshInstance3D = MeshInstance3D.new()
	var s_mesh: BoxMesh = BoxMesh.new()
	s_mesh.size = Vector3(inner_size, 0.45, inner_size)
	sw_mesh.mesh = s_mesh
	sw_mesh.position = Vector3(0.0, 0.1, 0.0)
	sw_mesh.material_override = sidewalk_mat
	sw_body.add_child(sw_mesh)
	buildings_parent.add_child(sw_body)

	# Downtown Skyscraper in this block
	var tower_height: float = randf_range(25.0, 85.0)
	var tower_width: float = inner_size - 8.0
	var tower_depth: float = inner_size - 8.0
	
	var b_body: StaticBody3D = StaticBody3D.new()
	b_body.position = center + Vector3(0.0, tower_height * 0.5 + 0.3, 0.0)
	
	var t_col: CollisionShape3D = CollisionShape3D.new()
	var tb_shape: BoxShape3D = BoxShape3D.new()
	tb_shape.size = Vector3(tower_width, tower_height, tower_depth)
	t_col.shape = tb_shape
	b_body.add_child(t_col)

	var t_mesh: MeshInstance3D = MeshInstance3D.new()
	var tm_box: BoxMesh = BoxMesh.new()
	tm_box.size = Vector3(tower_width, tower_height, tower_depth)
	t_mesh.mesh = tm_box
	t_mesh.material_override = building_mats.pick_random()
	b_body.add_child(t_mesh)

	# Window rows (warm emissive lighting)
	var win_band: MeshInstance3D = MeshInstance3D.new()
	var w_box: BoxMesh = BoxMesh.new()
	w_box.size = Vector3(tower_width + 0.1, tower_height * 0.6, tower_depth + 0.1)
	win_band.mesh = w_box
	win_band.position = Vector3(0.0, 0.0, 0.0)
	win_band.material_override = window_mat
	b_body.add_child(win_band)

	buildings_parent.add_child(b_body)

	# California Palm Trees along Sidewalk Corners
	var corners: Array[Vector3] = [
		Vector3(-inner_size * 0.45, 0.3, -inner_size * 0.45),
		Vector3(inner_size * 0.45, 0.3, -inner_size * 0.45),
		Vector3(-inner_size * 0.45, 0.3, inner_size * 0.45),
		Vector3(inner_size * 0.45, 0.3, inner_size * 0.45)
	]
	for c_pos: Vector3 in corners:
		_create_palm_tree(props_parent, center + c_pos)
		# Street lamp
		_create_street_lamp(props_parent, center + c_pos + Vector3(2.5, 0.0, 0.0))

func _create_palm_tree(parent: Node3D, pos: Vector3) -> void:
	var tree_root: StaticBody3D = StaticBody3D.new()
	tree_root.position = pos
	
	# Trunk Collision
	var col: CollisionShape3D = CollisionShape3D.new()
	var cyl_shape: CylinderShape3D = CylinderShape3D.new()
	cyl_shape.height = 8.5
	cyl_shape.radius = 0.28
	col.shape = cyl_shape
	col.position = Vector3(0.0, 4.25, 0.0)
	tree_root.add_child(col)

	# Trunk Mesh
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var c_mesh: CylinderMesh = CylinderMesh.new()
	c_mesh.top_radius = 0.22
	c_mesh.bottom_radius = 0.38
	c_mesh.height = 8.5
	trunk.mesh = c_mesh
	trunk.position = Vector3(0.0, 4.25, 0.0)
	trunk.material_override = palm_trunk_mat
	tree_root.add_child(trunk)

	# Lush Palm Fronds Canopy
	for i in range(8):
		var frond: MeshInstance3D = MeshInstance3D.new()
		var f_box: BoxMesh = BoxMesh.new()
		f_box.size = Vector3(0.65, 0.08, 3.2)
		frond.mesh = f_box
		frond.position = Vector3(0.0, 8.4, 1.4)
		frond.rotation_degrees = Vector3(-25.0, i * 45.0, 0.0)
		frond.material_override = palm_frond_mat
		tree_root.add_child(frond)

	parent.add_child(tree_root)

func _create_street_lamp(parent: Node3D, pos: Vector3) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.position = pos
	
	# Pole
	var pole: MeshInstance3D = MeshInstance3D.new()
	var p_cyl: CylinderMesh = CylinderMesh.new()
	p_cyl.top_radius = 0.08
	p_cyl.bottom_radius = 0.12
	p_cyl.height = 6.2
	pole.mesh = p_cyl
	pole.position = Vector3(0.0, 3.1, 0.0)
	pole.material_override = curb_mat
	lamp.add_child(pole)

	# Emissive Head fixture (exceeds bloom threshold 0.9)
	var head: MeshInstance3D = MeshInstance3D.new()
	var h_box: BoxMesh = BoxMesh.new()
	h_box.size = Vector3(0.5, 0.2, 0.8)
	head.mesh = h_box
	head.position = Vector3(0.0, 6.2, 0.3)
	var head_mat: StandardMaterial3D = GraphicsManagerCore.create_emissive_material(Color(1.0, 0.88, 0.65, 1.0), 3.8)
	head.material_override = head_mat
	lamp.add_child(head)

	# Warm Street Spotlight Cone
	var light: SpotLight3D = SpotLight3D.new()
	light.position = Vector3(0.0, 6.1, 0.3)
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.light_color = Color(1.0, 0.88, 0.68, 1.0)
	light.light_energy = 2.4
	light.spot_range = 16.0
	light.spot_angle = 48.0
	light.shadow_enabled = true
	lamp.add_child(light)

	parent.add_child(lamp)

func _create_stunt_ramp(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var ramp: StaticBody3D = StaticBody3D.new()
	ramp.position = pos
	ramp.rotation.y = rot_y
	
	var col: CollisionShape3D = CollisionShape3D.new()
	var r_shape: BoxShape3D = BoxShape3D.new()
	r_shape.size = Vector3(6.5, 0.35, 9.0)
	col.shape = r_shape
	col.position = Vector3(0.0, 1.4, 0.0)
	col.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	ramp.add_child(col)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var b_box: BoxMesh = BoxMesh.new()
	b_box.size = Vector3(6.5, 0.35, 9.0)
	mesh.mesh = b_box
	mesh.position = Vector3(0.0, 1.4, 0.0)
	mesh.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	
	var ramp_mat: StandardMaterial3D = StandardMaterial3D.new()
	ramp_mat.albedo_color = Color(0.95, 0.55, 0.05, 1.0) # Yellow/Orange hazard stunt ramp
	ramp_mat.metallic = 0.8
	ramp_mat.roughness = 0.2
	mesh.material_override = ramp_mat
	ramp.add_child(mesh)

	parent.add_child(ramp)

func _generate_beachfront() -> void:
	var beach_root: Node3D = Node3D.new()
	beach_root.name = "BeachfrontAndOcean"
	add_child(beach_root)

	# Sand Coast Strip on West Side
	var sand_body: StaticBody3D = StaticBody3D.new()
	sand_body.position = Vector3(-190.0, -0.2, 0.0)
	
	var col: CollisionShape3D = CollisionShape3D.new()
	var s_col: BoxShape3D = BoxShape3D.new()
	s_col.size = Vector3(80.0, 0.5, 360.0)
	col.shape = s_col
	sand_body.add_child(col)

	var sand_mesh: MeshInstance3D = MeshInstance3D.new()
	var sm_box: BoxMesh = BoxMesh.new()
	sm_box.size = Vector3(80.0, 0.5, 360.0)
	sand_mesh.mesh = sm_box
	sand_mesh.material_override = beach_sand_mat
	sand_body.add_child(sand_mesh)
	beach_root.add_child(sand_body)

	# Ocean Water Plane
	var ocean_mesh: MeshInstance3D = MeshInstance3D.new()
	var o_plane: PlaneMesh = PlaneMesh.new()
	o_plane.size = Vector2(400.0, 400.0)
	ocean_mesh.mesh = o_plane
	ocean_mesh.position = Vector3(-350.0, -0.4, 0.0)
	ocean_mesh.material_override = ocean_mat
	beach_root.add_child(ocean_mesh)

func _spawn_parked_vehicles() -> void:
	var cars_root: Node3D = Node3D.new()
	cars_root.name = "ParkedVehicles"
	add_child(cars_root)

	var spawn_configs: Array[Dictionary] = [
		{"pos": Vector3(8.0, 0.2, 12.0), "rot": 0.0, "color": Color(0.88, 0.10, 0.12, 1.0)}, # Crimson Red Sports Car
		{"pos": Vector3(-8.0, 0.2, 45.0), "rot": PI, "color": Color(0.12, 0.45, 0.95, 1.0)}, # Electric Blue Tuner
		{"pos": Vector3(78.0, 0.2, -15.0), "rot": PI * 0.5, "color": Color(0.95, 0.85, 0.08, 1.0)}, # Canary Yellow Muscle Car
		{"pos": Vector3(-62.0, 0.2, -80.0), "rot": -PI * 0.5, "color": Color(0.08, 0.08, 0.10, 1.0)} # Midnight Black Coupe
	]

	for cfg: Dictionary in spawn_configs:
		var car: VehicleController = VehicleController.new()
		car.paint_color = cfg["color"]
		cars_root.add_child(car)
		car.global_position = cfg["pos"]
		car.rotation.y = cfg["rot"]

func _spawn_initial_pedestrians() -> void:
	var peds_root: Node3D = Node3D.new()
	peds_root.name = "Civilians"
	add_child(peds_root)

	var spawn_points: Array[Vector3] = [
		Vector3(22.0, 0.4, 25.0),
		Vector3(26.0, 0.4, -18.0),
		Vector3(-22.0, 0.4, 32.0),
		Vector3(-26.0, 0.4, -40.0),
		Vector3(55.0, 0.4, 60.0),
		Vector3(-55.0, 0.4, -60.0),
		Vector3(85.0, 0.4, 15.0),
		Vector3(-85.0, 0.4, 25.0)
	]

	for pos: Vector3 in spawn_points:
		var ped: PedestrianNPC = PedestrianNPC.new()
		peds_root.add_child(ped)
		ped.global_position = pos
