@tool
class_name VillageTree
extends StaticBody2D

## Decorative tree prop for Snake Oil Salesman village square.

@export var tree_texture: Texture2D:
	set(val):
		tree_texture = val
		if has_node("Sprite2D"):
			$Sprite2D.texture = val

@export var tree_scale: Vector2 = Vector2(1.0, 1.0):
	set(val):
		tree_scale = val
		if has_node("Sprite2D"):
			$Sprite2D.scale = val


@export var enable_wind_sway: bool = true:
	set(val):
		enable_wind_sway = val
		_update_material()


func _ready() -> void:
	if has_node("Sprite2D"):
		if tree_texture:
			$Sprite2D.texture = tree_texture
		$Sprite2D.scale = tree_scale
		_update_material()


func _update_material() -> void:
	if has_node("Sprite2D") and $Sprite2D.material is ShaderMaterial:
		var mat: ShaderMaterial = $Sprite2D.material
		mat.set_shader_parameter("strength_scale", 1.0 if enable_wind_sway else 0.0)
