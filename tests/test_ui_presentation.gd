extends SceneTree

## Run headless for layout/connection checks. Add -- --capture with a renderer
## to write review PNGs into .godot/ui_review (never touches save data).
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for i in range(5):
		await process_frame

func capture(filename: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/ui_review/" + filename + ".png")

func inside(control: Control, description: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	check(bounds.encloses(control.get_global_rect()), description + " fits viewport")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/ui_review")
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await settle()
	# Freeze the world for repeatable UI review; no game code is altered.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = world.get_node("UI/HUD")
	var chat = world.get_node("UI/ChatUI")
	var joystick = world.get_node("UI/VirtualJoystick")
	check(joystick.base_texture == null and joystick.tip_texture == null, "Original joystick visuals restored")
	check(hud.advance_day_btn.pressed.is_connected(hud._on_advance_day_pressed), "Advance day connection preserved")
	check(chat.send_btn.pressed.is_connected(chat._on_send_pressed), "Send connection preserved")
	check(chat.close_btn.pressed.is_connected(chat._on_close_pressed), "Close connection preserved")
	check(chat.pitch_btn.pressed.is_connected(chat._on_pitch_pressed), "Pitch connection preserved")
	check(chat.message_input.text_submitted.is_connected(chat._on_message_submitted), "Submit connection preserved")
	check(hud.get_theme_stylebox("panel", "PanelContainer") is StyleBoxTexture, "Shared textured panel loads")
	for viewport_size in [Vector2i(1152, 648), Vector2i(960, 540), Vector2i(640, 480)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await settle()
		inside(hud.get_node("TopPanel"), "HUD at " + str(viewport_size))
		hud.show_toast("A merchant's good fortune: received 250 Kurtos.", true)
		await settle()
		inside(hud.toast_panel, "Toast")
		await capture("hud_%d" % viewport_size.x)
		chat.start_conversation(get_nodes_in_group("npcs")[0])
		await settle()
		inside(chat.chat_window, "Dialogue at " + str(viewport_size))
		for control in [chat.target_label, chat.npc_stats_label, chat.message_input, chat.pitch_btn, chat.send_btn, chat.close_btn]:
			inside(control, control.name)
		check(chat.dialogue_scroll.size.y >= 64, "Dialogue retains readable text area")
		chat._on_pitch_pressed()
		check(not chat.message_input.text.is_empty(), "Suggested pitch still populates input")
		await capture("dialogue_%d" % viewport_size.x)
		chat.end_conversation()
		hud.toast_panel.hide()
	hud._on_game_ended(false, "The thirty days are over. Your audience with the king awaits.")
	await settle()
	await capture("ending_inventory_640")
	print("UI presentation checks: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
