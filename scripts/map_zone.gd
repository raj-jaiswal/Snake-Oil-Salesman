extends Area2D
class_name MapZone

## MapZone displays a notification/banner in HUD when player enters a geographic district.

@export var zone_name: String = "Unknown Region"
@export var zone_subtitle: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_zone_banner"):
			hud.show_zone_banner(zone_name, zone_subtitle)
		elif hud and hud.has_method("show_notification"):
			hud.show_notification("📍 " + zone_name)
