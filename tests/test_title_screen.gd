extends SceneTree
## Programmatic title, save/load, movement and pickup regression checks.
## The isolation guard prevents this destructive save fixture using real progress.
var passed := 0
var failed := 0
var deadline := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(label)

func _process(_delta: float) -> bool:
	if deadline > 0 and Time.get_ticks_msec() > deadline:
		push_error("Title/world suite watchdog expired")
		quit(1)
	return false

func settle() -> void:
	for i in range(5): await process_frame

func title_screen() -> Control:
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	return title

func wait_main() -> Node:
	var until := Time.get_ticks_msec() + 5000
	while (not is_instance_valid(current_scene) or current_scene.scene_file_path != "res://scenes/main.tscn") and Time.get_ticks_msec() < until:
		await process_frame
	check(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/main.tscn", "Title action loads the real main scene")
	await settle()
	return current_scene

func discard_scene() -> void:
	if is_instance_valid(current_scene): current_scene.queue_free()
	current_scene = null
	await settle()

func run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "Snake Oil Salesman Integration Tests":
		push_error("Run through tests/run_isolated.ps1; refusing to modify real saves.")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 60000
	var state: GameStateManager = root.get_node("GameState")
	state.player_kurtos = 999
	state.current_day = 7
	state.overall_trust = 62
	state.save_game()
	check(state.has_save(), "Isolated save created")
	var title := title_screen()
	await settle()
	check(title.start_btn.pressed.is_connected(title._on_start_pressed), "Start signal remains connected")
	check(title.continue_btn.pressed.is_connected(title._on_continue_pressed), "Continue signal remains connected")
	check(not title.continue_btn.disabled, "Existing save enables Continue")
	title.start_btn.pressed.emit()
	check(title.confirm_panel.visible and state.player_kurtos == 999, "Start with save requests confirmation before resetting")
	title.get_node("ConfirmPanel/VBox/HBox/NoBtn").pressed.emit()
	check(not title.confirm_panel.visible and state.player_kurtos == 999, "Cancel preserves saved progress")
	title.start_btn.pressed.emit()
	title.get_node("ConfirmPanel/VBox/HBox/YesBtn").pressed.emit()
	var world := await wait_main()
	check(state.player_kurtos == 50 and state.current_day == 1 and state.overall_trust == 25, "Confirmed Start uses existing reset values")
	var retains_catalogue := state.inventory.size() == 50
	var retained_ids: Array = []
	for item in state.inventory: retained_ids.append(item.id)
	for id in state.ITEMS:
		if not retained_ids.has(id): retains_catalogue = false
	check(retains_catalogue, "Start retains all 50 item records (starter tonic becomes a real item under existing rules)")
	check(world.has_node("UI/HUD") and world.has_node("UI/ChatUI"), "World/HUD/dialogue instantiate")
	var hud := world.get_node("UI/HUD")
	hud.inventory_btn.pressed.emit()
	await settle()
	check(is_instance_valid(hud._inventory_popup) and hud._inventory_popup is InventoryUI and not state.can_player_move, "Inventory button opens actual inventory UI and suspends movement")
	check(hud._inventory_popup.grid.get_child_count() >= 50, "Inventory UI populates existing item slots")
	hud._inventory_popup.close_btn.pressed.emit()
	await settle()
	check(not is_instance_valid(hud._inventory_popup) and state.can_player_move, "Inventory Close restores movement")
	var player: CharacterBody2D = world.get_node("Player")
	var origin := player.global_position
	Input.action_press("move_right")
	for i in range(8): await physics_frame
	Input.action_release("move_right")
	for i in range(2): await physics_frame
	check(player.global_position.distance_to(origin) > 0.1, "Synthetic movement input moves player")
	check(player.velocity == Vector2.ZERO, "Releasing movement stops player")
	var npc: TownNPC = world.get_node("NPC_Barnaby")
	var chat: ChatUI = world.get_node("UI/ChatUI")
	chat.local_llm.enabled = false
	npc._on_interaction_area_body_entered(player)
	chat.chat_prompt_btn.pressed.emit()
	check(chat.is_chatting and chat.active_npc == npc and not state.can_player_move, "NPC interaction opens existing dialogue and suspends movement")
	origin = player.global_position
	Input.action_press("move_right")
	for i in range(4): await physics_frame
	Input.action_release("move_right")
	check(player.global_position.distance_to(origin) < 0.01, "Dialogue blocks actual player movement")
	chat.close_btn.pressed.emit()
	check(not chat.is_chatting and state.can_player_move, "Close restores gameplay movement")
	await settle()
	var saved_inventory := state.inventory.duplicate(true)
	# Remove one fixture item so its actual pickup scene can be exercised.
	while state.has_item("beggars_robe"): state.remove_item("beggars_robe")
	var chest: ItemChest = load("res://assets/objects/item_chest.tscn").instantiate()
	root.add_child(chest)
	await settle()
	chest._on_body_entered(player)
	check(chest.is_player_in_range and chest.prompt_label.visible, "Pickup detects player and displays prompt")
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	chest._unhandled_input(event)
	check(chest.is_collected and not chest.visible and state.has_item("beggars_robe"), "Pickup input adds item and hides collected pickup")
	var collected_inventory := state.inventory.duplicate(true)
	chest._unhandled_input(event)
	check(state.inventory == collected_inventory, "Repeated pickup input cannot duplicate collected item")
	chest.queue_free()
	state.inventory.assign(saved_inventory)
	state.player_kurtos = 777
	state.current_day = 12
	state.overall_trust = 67
	state.is_game_over = false
	state.has_won = false
	state.save_game()
	await discard_scene()
	state.player_kurtos = 1
	state.current_day = 2
	state.overall_trust = 3
	state.inventory.clear()
	title = title_screen()
	await settle()
	title.continue_btn.pressed.emit()
	world = await wait_main()
	check(state.player_kurtos == 777 and state.current_day == 12 and state.overall_trust == 67, "Continue restores currency, day and reputation")
	check(state.inventory == JSON.parse_string(JSON.stringify(saved_inventory)), "Continue restores complete inventory through the existing JSON save format")
	check(not state.is_game_over and not state.has_won and state.can_player_move, "Continue restores gameplay flags")
	check(world.has_node("NPC_Barnaby") and world.has_node("NPC_Marla") and world.has_node("NPC_Cedric") and world.has_node("NPC_Arthur"), "Continue preserves all conversational NPCs")
	await discard_scene()
	# This is exclusively the isolated fixture save, enforced at the start.
	DirAccess.remove_absolute("user://save_game.dat")
	title = title_screen()
	await settle()
	check(title.continue_btn.disabled, "No save disables Continue")
	title.start_btn.pressed.emit()
	await wait_main()
	check(state.player_kurtos == 50 and state.current_day == 1, "Start without save enters a new game")
	await discard_scene()
	print("Title/save/world: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
