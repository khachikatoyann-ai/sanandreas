class_name GameHUD
extends CanvasLayer

## GameHUD: Production mobile horizontal widescreen HUD (1920x1080)
## Features virtual joystick, ergonomic touch action buttons (on-foot & in-car),
## circular overhead real-time radar minimap with SubViewport, wanted stars, cash, and health bars.

# References
var player_ref: CharacterBody3D = null
var current_vehicle: VehicleController = null

# UI Root Containers
var root_control: Control
var joystick_base: Control
var joystick_knob: Control
var buttons_on_foot_container: Control
var buttons_in_car_container: Control
var minimap_container: SubViewportContainer
var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var wanted_container: HBoxContainer
var star_labels: Array[Label] = []
var cash_label: Label
var health_bar: ProgressBar
var armor_bar: ProgressBar
var ammo_label: Label
var speedo_container: Control
var speedo_label: Label
var gear_label: Label
var carjack_prompt: Label

# Joystick state
var joystick_touch_idx: int = -1
var joystick_center: Vector2 = Vector2(230, 850)
var joystick_max_radius: float = 85.0
var joystick_knob_pos: Vector2 = Vector2.ZERO
var joystick_output: Vector2 = Vector2.ZERO

# Touch Look Orbit state
var look_touch_idx: int = -1
var last_look_pos: Vector2 = Vector2.ZERO

# Cash roll-up
var displayed_cash: int = 25400
var target_cash: int = 25400

# Wanted Stars animation
var wanted_pulse_time: float = 0.0

func _ready() -> void:
	layer = 10
	_build_hud_layout()
	_connect_signals()

func _connect_signals() -> void:
	if GameDirectorCore.instance:
		GameDirectorCore.instance.wanted_level_changed.connect(_on_wanted_level_changed)
		GameDirectorCore.instance.cash_changed.connect(_on_cash_changed)
		GameDirectorCore.instance.player_vehicle_swapped.connect(_on_player_vehicle_swapped)

func setup_player(p: CharacterBody3D) -> void:
	player_ref = p
	p.health_changed.connect(_on_health_changed)
	p.armor_changed.connect(_on_armor_changed)
	p.ammo_changed.connect(_on_ammo_changed)
	p.nearby_vehicle_updated.connect(_on_nearby_vehicle_updated)
	_setup_minimap_camera()

func _build_hud_layout() -> void:
	root_control = Control.new()
	root_control.name = "RootHUD"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_build_virtual_joystick()
	_build_action_buttons()
	_build_minimap_radar()
	_build_top_right_dashboard()
	_build_speedometer()
	_build_carjack_prompt()

func _build_virtual_joystick() -> void:
	# Base circle
	joystick_base = Control.new()
	joystick_base.name = "JoystickBase"
	joystick_base.position = joystick_center - Vector2(100, 100)
	joystick_base.custom_minimum_size = Vector2(200, 200)
	joystick_base.size = Vector2(200, 200)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(joystick_base)

	# Draw base ring via custom draw or stylebox
	var base_panel: Panel = Panel.new()
	base_panel.size = Vector2(200, 200)
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style: StyleBoxFlat = StyleBoxFlat.new()
	base_style.bg_color = Color(0.1, 0.12, 0.18, 0.45)
	base_style.border_width_left = 3
	base_style.border_width_top = 3
	base_style.border_width_right = 3
	base_style.border_width_bottom = 3
	base_style.border_color = Color(0.3, 0.75, 1.0, 0.65)
	base_style.corner_radius_top_left = 100
	base_style.corner_radius_top_right = 100
	base_style.corner_radius_bottom_left = 100
	base_style.corner_radius_bottom_right = 100
	base_panel.add_theme_stylebox_override("panel", base_style)
	joystick_base.add_child(base_panel)

	# Knob
	joystick_knob = Control.new()
	joystick_knob.name = "JoystickKnob"
	joystick_knob.size = Vector2(76, 76)
	joystick_knob.position = Vector2(62, 62)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_panel: Panel = Panel.new()
	knob_panel.size = Vector2(76, 76)
	knob_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style: StyleBoxFlat = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.2, 0.8, 1.0, 0.85)
	knob_style.border_width_left = 2
	knob_style.border_width_top = 2
	knob_style.border_width_right = 2
	knob_style.border_width_bottom = 2
	knob_style.border_color = Color(1.0, 1.0, 1.0, 0.95)
	knob_style.corner_radius_top_left = 38
	knob_style.corner_radius_top_right = 38
	knob_style.corner_radius_bottom_left = 38
	knob_style.corner_radius_bottom_right = 38
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	joystick_knob.add_child(knob_panel)
	joystick_base.add_child(joystick_knob)

func _build_action_buttons() -> void:
	# 1. On-Foot Container
	buttons_on_foot_container = Control.new()
	buttons_on_foot_container.name = "OnFootButtons"
	buttons_on_foot_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons_on_foot_container.position = Vector2(1480, 680)
	buttons_on_foot_container.size = Vector2(400, 360)
	buttons_on_foot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(buttons_on_foot_container)

	# [FIRE] Button (Large, Red)
	_create_touch_button(buttons_on_foot_container, "FIRE", Vector2(230, 120), Vector2(120, 120), Color(0.9, 0.15, 0.15, 0.85), func(pressed: bool) -> void:
		InputManagerCore.set_virtual_action("fire", pressed)
	)
	# [JUMP] Button (Green)
	_create_touch_button(buttons_on_foot_container, "JUMP", Vector2(100, 200), Vector2(95, 95), Color(0.18, 0.8, 0.3, 0.85), func(pressed: bool) -> void:
		InputManagerCore.set_virtual_action("jump", pressed)
	)
	# [RUN] Button (Yellow)
	_create_touch_button(buttons_on_foot_container, "RUN", Vector2(100, 70), Vector2(90, 90), Color(0.95, 0.75, 0.1, 0.85), func(pressed: bool) -> void:
		InputManagerCore.set_virtual_action("sprint", pressed)
	)
	# [JACK CAR] Button (Blue)
	_create_touch_button(buttons_on_foot_container, "JACK CAR", Vector2(235, -20), Vector2(110, 110), Color(0.15, 0.55, 0.95, 0.85), func(pressed: bool) -> void:
		if pressed:
			InputManagerCore.set_virtual_action("interact_vehicle", true)
		else:
			InputManagerCore.set_virtual_action("interact_vehicle", false)
	)

	# 2. In-Vehicle Container
	buttons_in_car_container = Control.new()
	buttons_in_car_container.name = "InCarButtons"
	buttons_in_car_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons_in_car_container.position = Vector2(1460, 680)
	buttons_in_car_container.size = Vector2(420, 360)
	buttons_in_car_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons_in_car_container.visible = false
	root_control.add_child(buttons_in_car_container)

	# [GAS] Pedal
	_create_touch_button(buttons_in_car_container, "GAS", Vector2(240, 100), Vector2(125, 140), Color(0.15, 0.85, 0.35, 0.85), func(pressed: bool) -> void:
		InputManagerCore.set_virtual_action("move_forward", pressed)
	)
	# [BRAKE / REV] Pedal
	_create_touch_button(buttons_in_car_container, "BRAKE", Vector2(100, 150), Vector2(110, 120), Color(0.92, 0.15, 0.15, 0.85), func(pressed: bool) -> void:
		InputManagerCore.set_virtual_action("move_back", pressed)
	)
	# [DRIFT] Handbrake
	_create_touch_button(buttons_in_car_container, "DRIFT", Vector2(90, 20), Vector2(115, 95), Color(0.98, 0.55, 0.1, 0.85), func(pressed: bool) -> void:
		InputManagerCore.set_virtual_action("handbrake", pressed)
	)
	# [EXIT CAR] Button
	_create_touch_button(buttons_in_car_container, "EXIT", Vector2(240, -30), Vector2(110, 95), Color(0.2, 0.5, 0.9, 0.85), func(pressed: bool) -> void:
		if pressed:
			InputManagerCore.set_virtual_action("interact_vehicle", true)
		else:
			InputManagerCore.set_virtual_action("interact_vehicle", false)
	)

func _create_touch_button(parent: Control, text: String, pos: Vector2, btn_size: Vector2, color: Color, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = btn_size
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_NONE
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(btn_size.x * 0.45)
	style.corner_radius_top_right = int(btn_size.x * 0.45)
	style.corner_radius_bottom_left = int(btn_size.x * 0.45)
	style.corner_radius_bottom_right = int(btn_size.x * 0.45)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 1.0, 1.0, 0.85)
	btn.add_theme_stylebox_override("normal", style)
	
	var press_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	press_style.bg_color = color.lightened(0.25)
	btn.add_theme_stylebox_override("pressed", press_style)
	
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	
	btn.button_down.connect(func() -> void: callback.call(true))
	btn.button_up.connect(func() -> void: callback.call(false))
	
	parent.add_child(btn)
	return btn

func _build_minimap_radar() -> void:
	# Circular Bezel Container (Diameter 240px)
	var radar_frame: Panel = Panel.new()
	radar_frame.name = "RadarFrame"
	radar_frame.position = Vector2(40, 40)
	radar_frame.size = Vector2(240, 240)
	radar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.08, 0.10, 0.14, 0.9)
	frame_style.border_width_left = 4
	frame_style.border_width_top = 4
	frame_style.border_width_right = 4
	frame_style.border_width_bottom = 4
	frame_style.border_color = Color(0.2, 0.8, 1.0, 0.9)
	frame_style.corner_radius_top_left = 120
	frame_style.corner_radius_top_right = 120
	frame_style.corner_radius_bottom_left = 120
	frame_style.corner_radius_bottom_right = 120
	radar_frame.add_theme_stylebox_override("panel", frame_style)
	root_control.add_child(radar_frame)

	# SubViewportContainer for real-time overhead camera
	minimap_container = SubViewportContainer.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.position = Vector2(8, 8)
	minimap_container.size = Vector2(224, 224)
	minimap_container.stretch = true
	minimap_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_frame.add_child(minimap_container)

	minimap_viewport = SubViewport.new()
	minimap_viewport.name = "MinimapViewport"
	minimap_viewport.size = Vector2i(224, 224)
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_container.add_child(minimap_viewport)

	# Player Arrow in Center of Radar
	var player_arrow: Label = Label.new()
	player_arrow.text = "▲"
	player_arrow.position = Vector2(104, 98)
	player_arrow.add_theme_font_size_override("font_size", 28)
	player_arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	radar_frame.add_child(player_arrow)

	# Compass North Indicator
	var north_lbl: Label = Label.new()
	north_lbl.text = "N"
	north_lbl.position = Vector2(112, 10)
	north_lbl.add_theme_font_size_override("font_size", 16)
	north_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	radar_frame.add_child(north_lbl)

	# Street Name Label below radar
	var street_lbl: Label = Label.new()
	street_lbl.text = "OCEAN BLVD / DOWNTOWN"
	street_lbl.position = Vector2(40, 290)
	street_lbl.add_theme_font_size_override("font_size", 16)
	street_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.85))
	root_control.add_child(street_lbl)

func _setup_minimap_camera() -> void:
	if not minimap_viewport:
		return
	
	minimap_camera = Camera3D.new()
	minimap_camera.name = "MinimapCamera"
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = 110.0 # Field of view width in meters
	minimap_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0) # Directly top-down
	minimap_viewport.add_child(minimap_camera)

func _build_top_right_dashboard() -> void:
	var dash: Control = Control.new()
	dash.name = "TopRightDashboard"
	dash.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dash.position = Vector2(1500, 35)
	dash.size = Vector2(380, 180)
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(dash)

	# 1. Wanted Stars Row
	wanted_container = HBoxContainer.new()
	wanted_container.position = Vector2(100, 0)
	wanted_container.size = Vector2(280, 40)
	dash.add_child(wanted_container)

	for i in range(5):
		var star: Label = Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 34)
		star.add_theme_color_override("font_color", Color(0.35, 0.35, 0.38, 0.5)) # Dim inactive
		wanted_container.add_child(star)
		star_labels.append(star)

	# 2. Cash Counter (Classic Green Digital Font)
	cash_label = Label.new()
	cash_label.text = "$0025400"
	cash_label.position = Vector2(120, 48)
	cash_label.add_theme_font_size_override("font_size", 38)
	cash_label.add_theme_color_override("font_color", Color(0.35, 0.88, 0.35, 1.0))
	dash.add_child(cash_label)

	# 3. Health & Armor Bars
	var stats_vbox: VBoxContainer = VBoxContainer.new()
	stats_vbox.position = Vector2(80, 100)
	stats_vbox.size = Vector2(290, 45)
	dash.add_child(stats_vbox)

	# Health Bar
	health_bar = ProgressBar.new()
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(290, 14)
	
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.9, 0.15, 0.18, 1.0)
	hp_fill.corner_radius_top_left = 4
	hp_fill.corner_radius_bottom_left = 4
	hp_fill.corner_radius_top_right = 4
	hp_fill.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", hp_fill)
	
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.18, 0.18, 0.2, 0.8)
	health_bar.add_theme_stylebox_override("background", hp_bg)
	stats_vbox.add_child(health_bar)

	# Armor Bar
	armor_bar = ProgressBar.new()
	armor_bar.min_value = 0.0
	armor_bar.max_value = 100.0
	armor_bar.value = 100.0
	armor_bar.show_percentage = false
	armor_bar.custom_minimum_size = Vector2(290, 10)
	
	var ar_fill: StyleBoxFlat = StyleBoxFlat.new()
	ar_fill.bg_color = Color(0.18, 0.65, 0.95, 1.0)
	ar_fill.corner_radius_top_left = 4
	ar_fill.corner_radius_bottom_left = 4
	ar_fill.corner_radius_top_right = 4
	ar_fill.corner_radius_bottom_right = 4
	armor_bar.add_theme_stylebox_override("fill", ar_fill)
	armor_bar.add_theme_stylebox_override("background", hp_bg)
	stats_vbox.add_child(armor_bar)

	# Ammo Label
	ammo_label = Label.new()
	ammo_label.text = "SMG  180 / 300"
	ammo_label.position = Vector2(170, 145)
	ammo_label.add_theme_font_size_override("font_size", 18)
	ammo_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
	dash.add_child(ammo_label)

func _build_speedometer() -> void:
	speedo_container = Control.new()
	speedo_container.name = "Speedometer"
	speedo_container.position = Vector2(860, 940)
	speedo_container.size = Vector2(200, 100)
	speedo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedo_container.visible = false
	root_control.add_child(speedo_container)

	speedo_label = Label.new()
	speedo_label.text = "000 KM/H"
	speedo_label.position = Vector2(0, 0)
	speedo_label.add_theme_font_size_override("font_size", 38)
	speedo_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
	speedo_container.add_child(speedo_label)

	gear_label = Label.new()
	gear_label.text = "GEAR 1"
	gear_label.position = Vector2(45, 45)
	gear_label.add_theme_font_size_override("font_size", 20)
	gear_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 0.9))
	speedo_container.add_child(gear_label)

func _build_carjack_prompt() -> void:
	carjack_prompt = Label.new()
	carjack_prompt.text = "PRESS [JACK CAR] OR [F] TO ENTER"
	carjack_prompt.position = Vector2(740, 780)
	carjack_prompt.add_theme_font_size_override("font_size", 24)
	carjack_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	carjack_prompt.visible = false
	root_control.add_child(carjack_prompt)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Fallback mouse emulation for joystick
		var fake_touch: InputEventScreenTouch = InputEventScreenTouch.new()
		fake_touch.index = 99
		fake_touch.position = event.position
		fake_touch.pressed = event.pressed
		_handle_touch_event(fake_touch)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var fake_drag: InputEventScreenDrag = InputEventScreenDrag.new()
		fake_drag.index = 99
		fake_drag.position = event.position
		fake_drag.relative = event.relative
		_handle_drag_event(fake_drag)

func _handle_touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var dist_to_joy: float = event.position.distance_to(joystick_center)
		if dist_to_joy <= joystick_max_radius * 1.5 and joystick_touch_idx == -1:
			joystick_touch_idx = event.index
			_update_joystick(event.position)
		elif event.position.x > 800 and event.position.x < 1500 and look_touch_idx == -1:
			# Touch look area in center-right
			look_touch_idx = event.index
			last_look_pos = event.position
	else:
		if event.index == joystick_touch_idx:
			joystick_touch_idx = -1
			_reset_joystick()
		elif event.index == look_touch_idx:
			look_touch_idx = -1

func _handle_drag_event(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_idx:
		_update_joystick(event.position)
	elif event.index == look_touch_idx:
		var drag_delta: Vector2 = event.position - last_look_pos
		last_look_pos = event.position
		if player_ref:
			player_ref.rotate_camera_look(Vector2(-drag_delta.x * 0.005, -drag_delta.y * 0.005))

func _update_joystick(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joystick_center
	var dist: float = offset.length()
	if dist > joystick_max_radius:
		offset = offset.normalized() * joystick_max_radius

	joystick_knob_pos = offset
	joystick_knob.position = Vector2(62, 62) + joystick_knob_pos

	var norm_vec: Vector2 = offset / joystick_max_radius
	# Deadzone
	if norm_vec.length() < 0.12:
		norm_vec = Vector2.ZERO
	joystick_output = norm_vec

	# Map to actions
	InputManagerCore.set_virtual_action("move_right", norm_vec.x > 0.35, abs(norm_vec.x))
	InputManagerCore.set_virtual_action("move_left", norm_vec.x < -0.35, abs(norm_vec.x))
	InputManagerCore.set_virtual_action("move_forward", norm_vec.y < -0.35, abs(norm_vec.y))
	InputManagerCore.set_virtual_action("move_back", norm_vec.y > 0.35, abs(norm_vec.y))

func _reset_joystick() -> void:
	joystick_knob_pos = Vector2.ZERO
	joystick_knob.position = Vector2(62, 62)
	joystick_output = Vector2.ZERO
	InputManagerCore.set_virtual_action("move_right", false)
	InputManagerCore.set_virtual_action("move_left", false)
	InputManagerCore.set_virtual_action("move_forward", false)
	InputManagerCore.set_virtual_action("move_back", false)

func _process(delta: float) -> void:
	_update_cash_counter(delta)
	_update_wanted_flashing(delta)
	_update_minimap_camera_pos()
	_update_vehicle_speedometer()

func _update_minimap_camera_pos() -> void:
	if not minimap_camera:
		return
	var target_pos: Vector3 = Vector3.ZERO
	if current_vehicle and is_instance_valid(current_vehicle):
		target_pos = current_vehicle.global_position
	elif player_ref and is_instance_valid(player_ref):
		target_pos = player_ref.global_position
	
	minimap_camera.global_position = Vector3(target_pos.x, 80.0, target_pos.z)

func _update_cash_counter(delta: float) -> void:
	if displayed_cash != target_cash:
		var step: int = int(ceil(abs(target_cash - displayed_cash) * delta * 8.0))
		step = maxi(step, 1)
		if displayed_cash < target_cash:
			displayed_cash = mini(displayed_cash + step, target_cash)
		else:
			displayed_cash = maxi(displayed_cash - step, target_cash)
		cash_label.text = "$" + str(displayed_cash).pad_zeros(7)

func _update_wanted_flashing(delta: float) -> void:
	if not GameDirectorCore.instance or GameDirectorCore.instance.wanted_stars <= 0:
		return
	
	wanted_pulse_time += delta * 6.0
	var flash_on: bool = int(floor(wanted_pulse_time)) % 2 == 0
	
	for i in range(5):
		var star: Label = star_labels[i]
		if i < GameDirectorCore.instance.wanted_stars:
			if GameDirectorCore.instance.is_evading and not flash_on:
				# Flashing grey/blue while evading
				star.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8, 0.4))
			else:
				# Golden bright wanted star
				star.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
		else:
			star.add_theme_color_override("font_color", Color(0.35, 0.35, 0.38, 0.4))

func _update_vehicle_speedometer() -> void:
	if not current_vehicle or not is_instance_valid(current_vehicle):
		speedo_container.visible = false
		return

	speedo_container.visible = true
	var spd: int = int(current_vehicle.speed_kmh)
	speedo_label.text = str(spd).pad_zeros(3) + " KM/H"

	var gear: int = 1
	if spd > 115: gear = 5
	elif spd > 80: gear = 4
	elif spd > 45: gear = 3
	elif spd > 20: gear = 2
	gear_label.text = "GEAR " + str(gear)

func _on_wanted_level_changed(_stars: int, _evading: bool) -> void:
	pass

func _on_cash_changed(new_cash: int) -> void:
	target_cash = new_cash

func _on_health_changed(cur: float, _max_val: float) -> void:
	health_bar.value = cur

func _on_armor_changed(cur: float, _max_val: float) -> void:
	armor_bar.value = cur

func _on_ammo_changed(cur: int, max_val: int) -> void:
	ammo_label.text = "SMG  " + str(cur) + " / " + str(max_val)

func _on_nearby_vehicle_updated(veh: VehicleController) -> void:
	carjack_prompt.visible = (veh != null and not current_vehicle)

func _on_player_vehicle_swapped(veh: VehicleController) -> void:
	current_vehicle = veh
	if veh:
		buttons_on_foot_container.visible = false
		buttons_in_car_container.visible = true
		carjack_prompt.visible = false
	else:
		buttons_on_foot_container.visible = true
		buttons_in_car_container.visible = false
