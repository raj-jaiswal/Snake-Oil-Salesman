@tool
class_name VillageBuilding
extends StaticBody2D

## Prop building for Snake Oil Salesman village square.
## Combines pixel art building sprite, matching collision polygon, and atmospheric sign.

@export var building_texture: Texture2D:
	set(val):
		building_texture = val
		if has_node("Sprite2D"):
			$Sprite2D.texture = val
		_update_building()

@export var show_label: bool = false:
	set(val):
		show_label = val
		if has_node("NameLabel"):
			$NameLabel.visible = val and not building_name.is_empty()

@export var building_name: String = "":
	set(val):
		building_name = val
		if has_node("NameLabel"):
			$NameLabel.text = val
			$NameLabel.visible = show_label and not val.is_empty()

@export var match_asset_collider: bool = false:
	set(val):
		match_asset_collider = val
		_update_building()

@export var custom_polygon: PackedVector2Array = PackedVector2Array():
	set(val):
		custom_polygon = val
		_update_building()

@export var footprint_size: Vector2 = Vector2(140, 60):
	set(val):
		footprint_size = val
		_update_building()

@export var footprint_offset: Vector2 = Vector2(0, 20):
	set(val):
		footprint_offset = val
		_update_building()

@export var sprite_scale: Vector2 = Vector2(1.0, 1.0):
	set(val):
		sprite_scale = val
		if has_node("Sprite2D"):
			$Sprite2D.scale = val
		_update_building()


func _ready() -> void:
	_update_building()


func _update_building() -> void:
	if has_node("Sprite2D") and building_texture:
		$Sprite2D.texture = building_texture
		$Sprite2D.scale = sprite_scale
	
	if has_node("NameLabel"):
		$NameLabel.text = building_name
		$NameLabel.visible = show_label and not building_name.is_empty()
	
	_update_collision()


func _update_collision() -> void:
	var col_poly := _get_collision_polygon_node()
	var col_shape := _get_collision_shape_node()
	
	if col_poly != null:
		if custom_polygon.size() > 0:
			col_poly.polygon = custom_polygon
			col_poly.disabled = false
			if col_shape:
				col_shape.disabled = true
			return
		elif match_asset_collider and building_texture != null:
			var pts := _extract_polygon_from_texture(building_texture)
			if pts.size() > 0:
				var decomp := Geometry2D.decompose_polygon_in_convex(pts)
				if decomp.size() > 0:
					col_poly.polygon = pts
					col_poly.disabled = false
					if col_shape:
						col_shape.disabled = true
					return

	# Fallback to rectangular collision shape if polygon matching not used or failed
	if col_shape != null:
		if col_shape.shape == null or not (col_shape.shape is RectangleShape2D):
			col_shape.shape = RectangleShape2D.new()
		(col_shape.shape as RectangleShape2D).size = footprint_size
		col_shape.position = footprint_offset
		col_shape.disabled = false
		if col_poly != null:
			col_poly.disabled = true
			col_poly.polygon = PackedVector2Array()


func _get_collision_polygon_node() -> CollisionPolygon2D:
	var node := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if node != null:
		return node
	for child in get_children():
		if child is CollisionPolygon2D:
			return child as CollisionPolygon2D
	return null


func _get_collision_shape_node() -> CollisionShape2D:
	var node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if node != null:
		return node
	for child in get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null


func _extract_polygon_from_texture(tex: Texture2D) -> PackedVector2Array:
	if tex == null:
		return PackedVector2Array()
	var img := tex.get_image()
	if img == null:
		return PackedVector2Array()
	
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.1)
	var polys := bm.opaque_to_polygons(Rect2i(0, 0, img.get_width(), img.get_height()), 2.0)
	if polys.is_empty():
		return PackedVector2Array()
	
	var main_poly := polys[0]
	var half_w := img.get_width() / 2.0
	var half_h := img.get_height() / 2.0
	var scaled_pts := PackedVector2Array()
	for pt in main_poly:
		scaled_pts.append(Vector2(
			(pt.x - half_w) * sprite_scale.x,
			(pt.y - half_h) * sprite_scale.y
		))
	return scaled_pts
