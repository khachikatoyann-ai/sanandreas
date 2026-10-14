class_name GraphicsManagerCore
extends Node

## GraphicsManager: Programmatic AAA graphics, PBR lighting, and Los Santos sunset atmosphere.
## Sets up WorldEnvironment, DirectionalLight3D with 4-split cascades, ACES tonemap, HDR bloom,
## and provides master vehicle clearcoat PBR materials.

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var environment_resource: Environment

func _ready() -> void:
	# If running as autoload, check if scene already has an environment or construct one
	call_deferred("_setup_global_graphics")

func _setup_global_graphics() -> void:
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return
	
	# Check if main scene already has WorldEnvironment
	var existing_env: WorldEnvironment = tree.current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if not existing_env:
		world_environment = build_world_environment()
		tree.current_scene.add_child(world_environment)
	else:
		world_environment = existing_env
		environment_resource = existing_env.environment

	var existing_sun: DirectionalLight3D = tree.current_scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if not existing_sun:
		sun_light = build_directional_light()
		tree.current_scene.add_child(sun_light)
	else:
		sun_light = existing_sun

## Programmatically construct the complete WorldEnvironment
func build_world_environment() -> WorldEnvironment:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	
	var env: Environment = Environment.new()
	
	# 1. Sky & Golden Hour Sunset Palette
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.28, 0.58, 1.0) # Deep twilight zenith
	sky_mat.sky_horizon_color = Color(0.98, 0.52, 0.20, 1.0) # Warm sunset amber
	sky_mat.ground_bottom_color = Color(0.12, 0.10, 0.14, 1.0) # Dusk earth
	sky_mat.ground_horizon_color = Color(0.85, 0.40, 0.15, 1.0) # Golden glow horizon
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.06
	sky.sky_material = sky_mat
	env.sky = sky
	
	# Ambient & Reflections
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.95, 0.70, 0.50, 1.0)
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	
	# 2. ACES Filmic Tonemapping
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 1.0
	
	# 3. HDR Glow / Bloom (Threshold 0.9 for streetlights, headlights, muzzle flashes)
	env.glow_enabled = true
	env.glow_bloom = 0.32
	env.glow_intensity = 0.95
	env.glow_strength = 1.1
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 1.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# 4. Volumetric Atmospheric Fog & Sunset Haze
	env.fog_enabled = true
	env.fog_light_color = Color(0.96, 0.62, 0.35, 1.0)
	env.fog_light_energy = 0.85
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.35
	
	# Volumetric Atmospheric Fog (conditionally enabled depending on active renderer)
	var rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "mobile")
	if rendering_method != "mobile" and rendering_method != "gl_compatibility":
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color(0.96, 0.68, 0.42, 1.0)
		env.volumetric_fog_emission = Color(0.15, 0.08, 0.04, 1.0)
		env.volumetric_fog_emission_energy = 0.5
		env.volumetric_fog_length = 160.0
	
	we.environment = env
	environment_resource = env
	return we

## Programmatically construct the DirectionalLight3D with 4-split parallel cascades
func build_directional_light() -> DirectionalLight3D:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	# Golden hour sun angle low on the horizon
	sun.rotation_degrees = Vector3(-18.5, 142.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68, 1.0)
	sun.light_energy = 1.85
	sun.light_indirect_energy = 1.2
	
	# Shadows
	sun.shadow_enabled = true
	sun.shadow_bias = 0.025
	sun.shadow_opacity = 0.88
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.52
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = true
	
	return sun

## Production PBR Material Utility: Applies metallic clearcoat PBR shader to vehicle bodies
static func apply_vehicle_pbr_material(node: Node, paint_color: Color = Color(0.85, 0.08, 0.12, 1.0)) -> void:
	var pbr_mat: StandardMaterial3D = StandardMaterial3D.new()
	pbr_mat.albedo_color = paint_color
	pbr_mat.metallic = 0.88
	pbr_mat.roughness = 0.16
	pbr_mat.clearcoat_enabled = true
	pbr_mat.clearcoat = 1.0
	pbr_mat.clearcoat_roughness = 0.08
	pbr_mat.rim_enabled = true
	pbr_mat.rim = 0.25
	pbr_mat.rim_tint = 0.4
	
	_apply_material_recursive(node, pbr_mat, ["chassis", "body", "hood", "spoiler", "door", "trunk", "roof"])

static func _apply_material_recursive(n: Node, mat: Material, tag_filters: Array = []) -> void:
	if n is MeshInstance3D:
		var name_lower: String = n.name.to_lower()
		var matches: bool = tag_filters.is_empty()
		if not matches:
			for tag: String in tag_filters:
				if name_lower.contains(tag):
					matches = true
					break
		if matches:
			n.material_override = mat
	
	for child in n.get_children():
		_apply_material_recursive(child, mat, tag_filters)

# Global Material Palette Helpers for City & Props
static func create_emissive_material(color: Color, energy: float = 3.5) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat

static func create_glass_material(tint: Color = Color(0.12, 0.18, 0.22, 0.45)) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = tint
	mat.metallic = 0.95
	mat.roughness = 0.05
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	return mat

static func create_rubber_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.15, 1.0)
	mat.metallic = 0.05
	mat.roughness = 0.82
	return mat

static func create_rim_chrome_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.95, 1.0)
	mat.metallic = 0.98
	mat.roughness = 0.12
	return mat

static func create_asphalt_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.20, 1.0)
	mat.metallic = 0.08
	mat.roughness = 0.85
	return mat

static func create_sidewalk_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.65, 0.62, 1.0)
	mat.metallic = 0.02
	mat.roughness = 0.78
	return mat
