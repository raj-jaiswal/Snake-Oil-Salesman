extends SceneTree

const Layout = preload("res://scripts/mobile_ui_layout.gd")
var failures := 0
var safe: Rect2
var available: Rect2
var keyboard_px := 0

class ReplyRecorder extends Node:
	var requests := 0
	var message := ""
	var chat_ui: ChatUI
	func request_reply(_profile: Dictionary, text: String, _history: Array, _category = 0) -> void:
		requests += 1
		message = text
		# Networking now owns an explicit busy interval; the UI fixture completes
		# it asynchronously without running gameplay rules in a layout test.
		chat_ui.call_deferred("_on_llm_response_generated", {"response": "Test reply.",
			"threshold_decision": {"transfer_amount": 0, "trust_delta": 0,
				"suspicion_delta": 0, "outcome": ScamManager.ScamOutcome.SOCIAL_CHAT}})

func _init() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func settle() -> void:
	for i in range(8):
		await process_frame

func capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/ui_review/" + label + ".png")

func metrics() -> Array:
	return [safe, available, keyboard_px]

func run() -> void:
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await settle()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var layout = world.get_node("UI/MobileUILayout")
	var chat = world.get_node("UI/ChatUI")
	var hud = world.get_node("UI/HUD")
	var joy = world.get_node("UI/VirtualJoystick")
	var npc: Node2D = get_nodes_in_group("npcs")[0]
	var recorder := ReplyRecorder.new()
	world.add_child(recorder)
	chat.local_llm = recorder
	recorder.chat_ui = chat
	layout.metrics_source = metrics
	check(joy.base_texture == null and joy.tip_texture == null and joy.show_direction_line, "Original procedural joystick")
	check(joy.base_radius == 50 and joy.tip_radius == 20 and joy.clamp_zone == 50 and joy.deadzone == 0.05, "Original joystick geometry and deadzone")
	for physical in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)]:
		root.size = physical
		root.content_scale_size = Vector2i(1152, 648)
		await settle()
		safe = Rect2(Vector2.ZERO, chat.size)
		available = safe
		keyboard_px = 0
		layout.mobile = false
		chat.mobile_input = false
		chat.start_conversation(npc)
		layout.refresh()
		await settle()
		check(safe.encloses(chat.chat_window.get_global_rect()), "Desktop dialogue " + str(physical))
		check(chat.message_input.has_focus(), "Desktop initial focus")
		chat.message_input.text = "Desktop Enter submission"
		var previous: int = recorder.requests
		chat.message_input.text_submitted.emit(chat.message_input.text)
		check(recorder.requests == previous + 1 and recorder.message == "Desktop Enter submission", "Enter submits once")
		await settle()
		chat.message_input.text = "Desktop mouse submission"
		chat.send_btn.pressed.emit()
		check(recorder.requests == previous + 2 and recorder.message == "Desktop mouse submission", "Send submits once")
		chat.end_conversation()
		await settle()
		check(hud.visible and joy.visible, "Desktop original controls restored")
	for physical in [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(1600, 720)]:
		# Two physical pixels per UI unit exercises conversion, not just subtraction.
		var logical := Vector2(physical) / 2.0
		root.size = Vector2i(logical)
		root.content_scale_size = Vector2i(logical)
		await settle()
		var bounds := Rect2(Vector2.ZERO, logical)
		var screen := Rect2(Vector2.ZERO, Vector2(physical))
		var safe_pixels := Rect2(Vector2(64, 24), Vector2(physical) - Vector2(96, 48))
		var conversion := Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), Vector2.ZERO)
		safe = Layout.unobscured_rect(bounds, conversion, screen, safe_pixels, 0)
		available = safe
		layout.mobile = true
		chat.mobile_input = true
		layout.queue_refresh()
		await settle()
		check(safe.encloses(joy.get_global_rect()), "Joystick safe area " + str(physical))
		check(not joy.get_global_rect().intersects(hud.get_node("TopPanel").get_global_rect()), "Joystick avoids HUD")
		# First finger controls movement, unrelated second finger must not steal it.
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = true
		touch.position = joy.size / 2 + Vector2(40, 0)
		joy._gui_input(touch)
		check(joy.is_active() and joy.get_output().x > 0.7, "Touch moves original joystick")
		var other := InputEventScreenTouch.new()
		other.index = 1
		other.pressed = false
		joy._gui_input(other)
		check(joy.is_active(), "Second finger does not release joystick")
		# Opening NPC UI with second finger cancels held movement safely.
		chat.start_conversation(npc)
		await settle()
		check(not joy.is_active() and not Input.is_action_pressed("move_right"), "Dialogue releases held joystick")
		check(not joy.visible and not chat.message_input.has_focus(), "Mobile opens dialogue without forcing keyboard")
		check(chat.chat_window.get_global_rect().end.y <= hud.get_node("TopPanel").position.y, "Closed-keyboard dialogue above HUD")
		await capture("mobile_%d_closed" % physical.x)
		for fraction in [0.4, 0.6]:
			keyboard_px = int(physical.y * fraction)
			available = Layout.unobscured_rect(bounds, conversion, screen, safe_pixels, keyboard_px)
			chat.message_input.grab_focus()
			chat.message_input.text = "A visible pitch above the keyboard"
			layout.queue_refresh()
			await settle()
			for control in [chat.message_input, chat.send_btn, chat.pitch_btn]:
				check(available.encloses(control.get_global_rect()), "%s above %d%% keyboard at %s" % [control.name, fraction * 100, physical])
			check(not hud.visible, "Low-priority HUD hidden while typing")
			check(chat.message_input.text == "A visible pitch above the keyboard", "Typed text survives relayout")
			await capture("mobile_%d_keyboard_%d" % [physical.x, fraction * 100])
			# Release focus via a tap on the conversation area, without consuming it.
			var outside := InputEventScreenTouch.new()
			outside.pressed = true
			outside.position = chat.chat_window.position + Vector2(20, 20)
			chat._input(outside)
			check(not chat.message_input.has_focus(), "Outside tap dismisses input focus")
			chat.message_input.grab_focus()
			var previous: int = recorder.requests
			chat.send_btn.pressed.emit()
			check(recorder.requests == previous + 1 and recorder.message == "A visible pitch above the keyboard", "Mobile sends visible text exactly once")
			check(not chat.message_input.has_focus(), "Send releases mobile keyboard focus")
			await settle()
			# Exercise one late reply after the final layout case; repeated replies
			# would intentionally change NPC suspicion and contaminate UI fixtures.
			if physical.x == 1600 and fraction == 0.6:
				chat._on_llm_response_generated({"response": "Good day, traveler."})
				check(not chat.message_input.has_focus(), "Late reply does not reopen mobile keyboard")
			keyboard_px = 0
			available = safe
			layout.queue_refresh()
			await settle()
			check(hud.visible, "HUD returns when keyboard closes")
		chat.end_conversation()
		await settle()
		check(joy.visible and hud.visible, "Mobile gameplay restored")
	# Already-resized surface: only intersect; never subtract keyboard twice.
	var resized := Rect2(0, 0, 1200, 300)
	var identity_scale := Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), Vector2.ZERO)
	var clipped := Layout.unobscured_rect(resized, identity_scale, Rect2(0, 0, 2400, 1080), Rect2(0, 0, 2400, 1080), 480)
	check(clipped == resized, "OS resized surface is not inset twice")
	print("Mobile/desktop presentation checks: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
