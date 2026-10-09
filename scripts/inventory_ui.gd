class_name InventoryUI
extends Control

@onready var grid: GridContainer = %ItemGrid
@onready var close_btn: Button = %CloseBtn
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var item_icon_rect: TextureRect = %ItemIconRect
@onready var equip_btn: Button = %EquipBtn
@onready var cancel_btn: Button = %CancelBtn
@onready var item_rarity_label: Label = %ItemRarityLabel
@onready var item_quantity_label: Label = %ItemQuantityLabel
@onready var item_effect_label: Label = %ItemEffectLabel
@onready var item_duration_label: Label = %ItemDurationLabel

var selected_item_id: String = ""

const RARITY_COLORS = {
	"Common": Color(0.6, 0.5, 0.4),
	"Uncommon": Color(0.2, 0.8, 0.2),
	"Rare": Color(0.2, 0.5, 1.0),
	"Epic": Color(0.7, 0.2, 0.9),
	"Legendary": Color(1.0, 0.8, 0.1)
}

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	equip_btn.pressed.connect(_on_equip_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	equip_btn.disabled = true
	
	var preview_shine = TextureRect.new()
	preview_shine.name = "PreviewShine"
	var grad_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 0.7))
	grad.add_point(0.7, Color(1, 1, 1, 0.0))
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	preview_shine.texture = grad_tex
	preview_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shine.modulate = Color(0, 0, 0, 0)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	preview_shine.material = mat
	item_icon_rect.add_child(preview_shine)

	_refresh_inventory()
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.item_added.connect(_on_item_added)

func _on_close_pressed() -> void:
	var hud = get_parent()
	if hud and hud.has_method("_on_inventory_btn_pressed"):
		hud._on_inventory_btn_pressed()
	else:
		queue_free()

func _on_cancel_pressed() -> void:
	selected_item_id = ""
	_clear_details_panel()
	_update_grid_highlights()

func _on_item_added(_item: Dictionary) -> void:
	_refresh_inventory()
	if selected_item_id != "":
		# Refresh selected item details if it's still in inventory
		var gs = get_node_or_null("/root/GameState")
		if gs:
			var found = false
			for it in gs.inventory:
				if it.id == selected_item_id:
					_update_details_panel(it)
					found = true
					break
			if not found:
				_on_cancel_pressed()

func _refresh_inventory() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	var gs = get_node_or_null("/root/GameState")
	if not gs: return
	if gs.inventory.size() == 0:
		_on_cancel_pressed()
	
	for item in gs.inventory:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.icon = gs.get_item_icon(item.id)
		btn.set_meta("item_id", item.id)
		
		var r_col = RARITY_COLORS.get(item.get("rarity", "Common"), Color(1, 1, 1))

		# Add quantity label
		var qty_label = Label.new()
		qty_label.text = str(item.get("quantity", 1))
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		qty_label.add_theme_color_override("font_color", Color(1, 1, 1))
		qty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		qty_label.add_theme_constant_override("outline_size", 4)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(qty_label)

		# Add rarity border
		var rect = ReferenceRect.new()
		rect.border_color = r_col
		rect.border_width = 2.0
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(rect)
		
		if item.id == selected_item_id:
			btn.modulate = Color(1.5, 1.5, 1.5)
			
		var bound_item = item
		btn.pressed.connect(func(): _on_item_selected(bound_item))
		
		# Hover logic
		btn.mouse_entered.connect(func():
			_update_details_panel(bound_item)
			if selected_item_id != bound_item.id:
				btn.modulate = Color(1.2, 1.2, 1.2)
		)
		btn.mouse_exited.connect(func():
			if selected_item_id != bound_item.id:
				btn.modulate = Color(1.0, 1.0, 1.0)
			
			if selected_item_id != "":
				var pgs = get_node_or_null("/root/GameState")
				if pgs:
					for it in pgs.inventory:
						if it.id == selected_item_id:
							_update_details_panel(it)
							break
			else:
				_clear_details_panel()
		)
		
		grid.add_child(btn)


func _update_details_panel(item: Dictionary) -> void:
	item_name_label.text = item.get("name", "Unknown Item")
	item_desc_label.text = item.get("description", "No description available.")
	var gs = get_node_or_null("/root/GameState")
	if gs:
		item_icon_rect.texture = gs.get_item_icon(item.id)
	
	var rarity = item.get("rarity", "Common")
	item_rarity_label.text = "Rarity: " + rarity
	var r_col = RARITY_COLORS.get(rarity, Color(1, 1, 1))
	item_rarity_label.add_theme_color_override("font_color", r_col)
	
	if item_icon_rect.has_node("PreviewShine"):
		item_icon_rect.get_node("PreviewShine").modulate = r_col * Color(1.3, 1.3, 1.3, 0.8)
	
	item_quantity_label.text = "Quantity: " + str(item.get("quantity", 1))
	
	var eff = item.get("effect", "none")
	var val = item.get("effect_val", 0)
	if eff != "none":
		item_effect_label.text = "Effect: " + eff.capitalize().replace("_", " ") + " +" + str(val)
	else:
		item_effect_label.text = "Effect: None"
		
	var dur = item.get("duration", 0)
	if dur > 0:
		item_duration_label.text = "Duration: " + str(dur) + " days"
	else:
		item_duration_label.text = ""
	
	equip_btn.disabled = false
	if item.get("consumable", false):
		equip_btn.text = "Use"
	else:
		equip_btn.text = "Inspect"

func _clear_details_panel() -> void:
	item_name_label.text = "Select an item"
	item_desc_label.text = "Hover or tap an item to see its details here."
	item_icon_rect.texture = null
	item_rarity_label.text = ""
	item_quantity_label.text = ""
	item_effect_label.text = ""
	item_duration_label.text = ""
	equip_btn.disabled = true
	if item_icon_rect.has_node("PreviewShine"):
		item_icon_rect.get_node("PreviewShine").modulate = Color(0, 0, 0, 0)
	
	var preview_shine = TextureRect.new()
	preview_shine.name = "PreviewShine"
	var grad_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 0.7))
	grad.add_point(0.7, Color(1, 1, 1, 0.0))
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	preview_shine.texture = grad_tex
	preview_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shine.modulate = Color(0, 0, 0, 0)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	preview_shine.material = mat
	item_icon_rect.add_child(preview_shine)


func _on_item_selected(item: Dictionary) -> void:
	selected_item_id = item.id
	_update_details_panel(item)
	_update_grid_highlights()

func _update_grid_highlights() -> void:
	for btn in grid.get_children():
		var id = btn.get_meta("item_id")
		if id == selected_item_id:
			btn.modulate = Color(1.5, 1.5, 1.5)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)



func _on_equip_pressed() -> void:
	if selected_item_id == "": return
	
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var found = false
		for it in gs.inventory:
			if it.id == selected_item_id:
				if it.get("consumable", false):
					gs.use_item(selected_item_id)
				found = true
				break
