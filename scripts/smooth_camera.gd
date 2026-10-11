extends Camera2D
class_name SmoothCamera2D

## Smooth following camera with clamp boundaries and smooth zoom controls.
## Automatically attaches to the Player and clamps to map dimensions.

@export var target_node: NodePath = NodePath("../Player")
@export var smooth_speed: float = 6.0
@export var default_zoom_level: float = 1.25
@export var min_zoom_level: float = 0.65
@export var max_zoom_level: float = 2.2
@export var zoom_step: float = 0.15
@export var zoom_lerp_speed: float = 8.0

var target: Node2D = null
var current_target_zoom: float = 1.25


func _ready() -> void:
	current_target_zoom = default_zoom_level
	zoom = Vector2(default_zoom_level, default_zoom_level)
	
	# Enable Godot built-in position smoothing as well for buttery smoothness
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed
	
	# Set map limits (2560 x 1920 full island bounds)
	limit_left = 0
	limit_top = 0
	limit_right = 2560
	limit_bottom = 1920
	limit_smoothed = true
	
	if has_node(target_node):
		target = get_node(target_node) as Node2D
	elif target == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as Node2D
	
	if target:
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		# Smoothly lag toward target position
		var weight := 1.0 - exp(-smooth_speed * delta)
		global_position = global_position.lerp(target.global_position, weight)
	
	# Smoothly interpolate zoom
	if abs(zoom.x - current_target_zoom) > 0.001:
		var z_weight := 1.0 - exp(-zoom_lerp_speed * delta)
		var new_z: float = lerp(zoom.x, current_target_zoom, z_weight)
		zoom = Vector2(new_z, new_z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.is_pressed():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var ek := event as InputEventKey
		if ek.is_pressed() and not ek.is_echo():
			if ek.keycode == KEY_EQUAL or ek.keycode == KEY_PLUS or ek.keycode == KEY_KP_ADD:
				zoom_in()
			elif ek.keycode == KEY_MINUS or ek.keycode == KEY_KP_SUBTRACT:
				zoom_out()
			elif ek.keycode == KEY_0 or ek.keycode == KEY_KP_0:
				reset_zoom()


func zoom_in() -> void:
	current_target_zoom = clampf(current_target_zoom + zoom_step, min_zoom_level, max_zoom_level)


func zoom_out() -> void:
	current_target_zoom = clampf(current_target_zoom - zoom_step, min_zoom_level, max_zoom_level)


func reset_zoom() -> void:
	current_target_zoom = default_zoom_level
