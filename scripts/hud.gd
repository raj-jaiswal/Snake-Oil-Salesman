class_name GameHUD
extends Control

signal layout_requested

## In-game HUD displaying player currency progress toward 1 Million, Day counter,
## Overall trust rating, inventory, advance-day controls, and notification toasts.

@onready var kurtos_label: Label = %KurtosLabel
@onready var day_label: Label = %DayLabel
@onready var trust_label: Label = %TrustLabel
@onready var advance_day_btn: Button = %AdvanceDayBtn
@onready var inventory_btn: Button = %InventoryBtn
@onready var info_btn: Button = %InfoBtn
@onready var achievements_btn: Button = %AchievementsBtn
@onready var settings_btn: Button = %SettingsBtn

@onready var info_panel: PanelContainer = %InfoPanel
@onready var close_info_btn: Button = %CloseInfoBtn

@onready var achievements_panel: PanelContainer = %AchievementsPanel
@onready var close_achievements_btn: Button = %CloseAchievementsBtn
@onready var achievements_text: Label = %Text

@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var close_settings_btn: Button = %CloseSettingsBtn
@onready var fullscreen_btn: Button = %FullscreenBtn

@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel

var _toast_timer: float = 0.0
var _inventory_popup: Control = null

func _ready() -> void:
	toast_panel.visible = false
	advance_day_btn.pressed.connect(_on_advance_day_pressed)
	inventory_btn.pressed.connect(_on_inventory_btn_pressed)
	info_btn.pressed.connect(func(): info_panel.visible = not info_panel.visible; achievements_panel.visible = false; settings_panel.visible = false)
	close_info_btn.pressed.connect(func(): info_panel.visible = false)

	achievements_btn.pressed.connect(_on_achievements_btn_pressed)
	close_achievements_btn.pressed.connect(func(): achievements_panel.visible = false)

	settings_btn.pressed.connect(func(): settings_panel.visible = not settings_panel.visible; achievements_panel.visible = false; info_panel.visible = false)
	close_settings_btn.pressed.connect(func(): settings_panel.visible = false)
	fullscreen_btn.pressed.connect(_on_fullscreen_pressed)

	
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.connect("kurtos_changed", Callable(self, "_on_kurtos_changed"))
		game_state.connect("day_changed", Callable(self, "_on_day_changed"))
		game_state.connect("overall_trust_changed", Callable(self, "_on_overall_trust_changed"))
		game_state.connect("item_added", Callable(self, "_on_item_added"))
		game_state.connect("game_ended", Callable(self, "_on_game_ended"))
		
		# Initial UI sync
		_update_kurtos(game_state.player_kurtos, game_state.goal_kurtos)
		_update_day(game_state.current_day, game_state.max_days)
		_update_trust(game_state.overall_trust)

func _process(delta: float) -> void:
	if toast_panel.visible:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_panel.visible = false


func show_toast(message: String, is_positive: bool = true, duration: float = 3.5) -> void:
	toast_label.text = message
	# Status tint affects text only; the shared pixel frame is retained.
	toast_label.add_theme_color_override("font_color",
		Color("c7dc9e") if is_positive else Color("f0a080"))
	toast_panel.position.y = $TopPanel.position.y + $TopPanel.size.y + 8.0
	
	toast_panel.visible = true
	_toast_timer = duration
	layout_requested.emit()


func _on_advance_day_pressed() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("advance_day"):
		game_state.advance_day()
		show_toast("Day %d has begun! All NPC daily budgets have been reset." % game_state.current_day, true, 3.0)

func _on_inventory_btn_pressed() -> void:
	if _inventory_popup and is_instance_valid(_inventory_popup):
		_inventory_popup.queue_free()
		_inventory_popup = null
		var gs = get_node_or_null("/root/GameState")
		if gs: gs.can_player_move = true
	else:
		var inv_scene = load("res://scenes/ui/inventory_ui.tscn")
		if inv_scene:
			_inventory_popup = inv_scene.instantiate()
			add_child(_inventory_popup)
			move_child(_inventory_popup, 0)
			var gs = get_node_or_null("/root/GameState")
			if gs: gs.can_player_move = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_ESCAPE:
			var focus = get_viewport().gui_get_focus_owner()
			if focus is LineEdit or focus is TextEdit: return
			
			if _inventory_popup and is_instance_valid(_inventory_popup):
				_on_inventory_btn_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_I:
				_on_inventory_btn_pressed()
				get_viewport().set_input_as_handled()


func _on_kurtos_changed(new_amount: int, delta: int) -> void:
	var game_state = get_node_or_null("/root/GameState")
	var goal: int = game_state.goal_kurtos if game_state else 1_000_000
	_update_kurtos(new_amount, goal)
	if delta > 0:
		show_toast("Received +%d Kurtos!" % delta, true, 3.0)


func _on_day_changed(new_day: int) -> void:
	var game_state = get_node_or_null("/root/GameState")
	var max_d: int = game_state.max_days if game_state else 30
	_update_day(new_day, max_d)


func _on_overall_trust_changed(new_val: int, _delta: int) -> void:
	_update_trust(new_val)


func _on_item_added(item: Dictionary) -> void:
	show_toast("Acquired item: %s!" % str(item.get("name", "Item")), true, 3.0)


func _on_game_ended(won: bool, message: String) -> void:
	show_toast("%s" % message, won, 10.0)


func _update_kurtos(val: int, goal: int) -> void:
	kurtos_label.text = "%s / %s Kurtos" % [_format_number(val), _format_number(goal)]


func _update_day(day: int, max_d: int) -> void:
	day_label.text = "Day %d / %d" % [day, max_d]


func _update_trust(trust: int) -> void:
	trust_label.text = "Reputation: %d%%" % trust


func _format_number(n: int) -> String:
	var s := str(n)
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			res = "," + res
		res = s[i] + res
		count += 1
	return res

func _on_achievements_btn_pressed() -> void:
	achievements_panel.visible = not achievements_panel.visible
	info_panel.visible = false
	settings_panel.visible = false
	if achievements_panel.visible:
		var gs = get_node_or_null("/root/GameState")
		if gs:
			var txt = "- Current Kurtos: " + str(gs.player_kurtos) + " / " + str(gs.goal_kurtos) + "\n"
			txt += "- Days Elapsed: " + str(gs.current_day) + "\n"
			txt += "- Reputation: " + str(gs.overall_trust) + "%\n"
			txt += "- Items Collected: " + str(gs.inventory.size()) + "\n"
			achievements_text.text = txt

func _on_fullscreen_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
