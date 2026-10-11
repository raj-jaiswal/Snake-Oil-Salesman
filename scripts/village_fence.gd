@tool
class_name VillageFence
extends StaticBody2D

## Modular fence line for Snake Oil Salesman village square.

@export var fence_texture: Texture2D:
	set(val):
		fence_texture = val
		_update_fence()

@export var tile_count: int = 4:
	set(val):
		tile_count = maxi(1, val)
		_update_fence()

@export var fence_scale: float = 1.0:
	set(val):
		fence_scale = maxf(1.0, val)
		_update_fence()


func _ready() -> void:
	_update_fence()


func _update_fence() -> void:
	var total_width := tile_count * 16.0 * fence_scale
	var height := 16.0 * fence_scale
	
	if has_node("TextureRect") and fence_texture:
		var tr := $TextureRect as TextureRect
		tr.texture = fence_texture
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.scale = Vector2(fence_scale, fence_scale)
		tr.size = Vector2(tile_count * 16.0, 16.0)
		tr.position = Vector2(-total_width * 0.5, -height * 0.5)
	
	if has_node("CollisionShape2D"):
		var col := $CollisionShape2D as CollisionShape2D
		if col.shape == null or not (col.shape is RectangleShape2D):
			col.shape = RectangleShape2D.new()
		(col.shape as RectangleShape2D).size = Vector2(total_width, height * 0.8)
		col.position = Vector2.ZERO
