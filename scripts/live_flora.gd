@tool
class_name LiveFlora
extends Node2D

## Interactive, wind-swayed live flora and wildflower prop for Snake Oil Salesman.
## Reacts physically to characters stepping through or near flowerbeds.

@export var flora_texture: Texture2D:
	set(val):
		flora_texture = val
		_update_texture()

@export var flora_type: String = "wildflower": # "wildflower", "bush", "solid", "ground"
	set(val):
		flora_type = val
		if flora_type == "solid":
			has_collision = true
		_update_shader_parameters()
		_update_collision()

@export var sway_strength: float = 3.5:
	set(val):
		sway_strength = val
		_update_shader_parameters()

@export var sway_speed: float = 2.2:
	set(val):
		sway_speed = val
		_update_shader_parameters()

@export var has_collision: bool = false:
	set(val):
		has_collision = val
		_update_collision()

var _sprite: Sprite2D
var _collision_shape: CollisionShape2D
var _static_body: StaticBody2D
var _rustle_tween: Tween


func _ready() -> void:
	_sprite = get_node_or_null("Sprite2D")
	_static_body = get_node_or_null("StaticBody2D")
	if _static_body:
		_collision_shape = _static_body.get_node_or_null("CollisionShape2D")
	
	if flora_type == "solid":
		has_collision = true
	
	_update_texture()
	_update_shader_parameters()
	_update_collision()
	
	if not Engine.is_editor_hint():
		var rustle_area := get_node_or_null("RustleArea") as Area2D
		if rustle_area:
			rustle_area.body_entered.connect(_on_body_entered)


func _update_texture() -> void:
	if not _sprite:
		_sprite = get_node_or_null("Sprite2D")
	if _sprite and flora_texture:
		_sprite.texture = flora_texture


func _update_shader_parameters() -> void:
	if not _sprite:
		_sprite = get_node_or_null("Sprite2D")
	if _sprite and _sprite.material is ShaderMaterial:
		var mat: ShaderMaterial = _sprite.material
		if flora_type == "solid":
			mat.set_shader_parameter("sway_strength", 0.0)
		elif flora_type == "bush":
			mat.set_shader_parameter("sway_strength", 2.0)
			mat.set_shader_parameter("speed", 1.5)
			mat.set_shader_parameter("height_offset", 0.1)
		elif flora_type == "ground":
			mat.set_shader_parameter("sway_strength", 1.2)
			mat.set_shader_parameter("speed", 1.8)
		else: # "wildflower"
			mat.set_shader_parameter("sway_strength", sway_strength)
			mat.set_shader_parameter("speed", sway_speed)
			mat.set_shader_parameter("height_offset", 0.0)


func _update_collision() -> void:
	if not _static_body:
		_static_body = get_node_or_null("StaticBody2D")
	if _static_body:
		_static_body.process_mode = PROCESS_MODE_INHERIT if has_collision else PROCESS_MODE_DISABLED
		if not _collision_shape:
			_collision_shape = _static_body.get_node_or_null("CollisionShape2D")
		if _collision_shape:
			_collision_shape.disabled = not has_collision


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("npcs") or body.is_in_group("guards"):
		rustle(body.global_position)


func rustle(pusher_pos: Vector2, force: float = 0.25) -> void:
	if flora_type == "solid" or not _sprite:
		return
	
	if _rustle_tween and _rustle_tween.is_valid():
		_rustle_tween.kill()
	
	var dir_x := 1.0 if global_position.x >= pusher_pos.x else -1.0
	var deflect_angle := dir_x * force
	
	_rustle_tween = create_tween()
	_rustle_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_rustle_tween.tween_property(_sprite, "rotation", deflect_angle, 0.12)
	_rustle_tween.tween_property(_sprite, "rotation", 0.0, 0.35)
