class_name ChatUI
extends Control

## In-game Chat interface for interacting with NPCs.
## Features bottom dialogue window with persistent conversation log,
## live social & wallet stats, scam pitching, and refusal checks.

signal conversation_started(npc: Node2D)
signal conversation_ended(npc: Node2D)

@onready var chat_prompt_btn: Button = %ChatPromptBtn
@onready var chat_window: PanelContainer = %ChatWindow
@onready var npc_avatar: ColorRect = %NPCAvatar
@onready var target_label: Label = %TargetLabel
@onready var npc_stats_label: Label = %NPCStatsLabel
@onready var dialogue_scroll: ScrollContainer = %DialogueScroll
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var message_input: LineEdit = %MessageInput
@onready var pitch_btn: Button = %PitchBtn
@onready var send_btn: Button = %SendBtn
@onready var close_btn: Button = %CloseBtn
@onready var local_llm: Node = %LocalLLM
@onready var llm_status_btn: Button = get_node_or_null("%LLMStatusBtn") as Button

var active_npc: Node2D = null
var is_chatting: bool = false
var conversation_histories_by_npc: Dictionary = {} # npc_id (String) -> Array[String]
var _last_sent_text: String = ""
var _last_sent_category: Dictionary = {}
var mobile_input: bool = false
var _waiting_for_reply := false
var _pending_request_id := 0
var _pending_npc: Node2D
var _pending_history: Array = []


func get_npc_id(npc: Node2D) -> String:
	if npc == null:
		return "unknown"
	if npc.has_method("get_full_profile"):
		var id_val: String = str(npc.get_full_profile().get("id", ""))
		if not id_val.is_empty():
			return id_val
	if "npc_name" in npc:
		return str(npc.get("npc_name"))
	return "npc_default"


func get_active_npc_history() -> Array:
	if active_npc == null:
		return []
	var npc_id := get_npc_id(active_npc)
	if "conversation_history" in active_npc and active_npc.conversation_history is Array:
		# Reuse the NPC-owned array so its existing day-reset rules apply here too.
		conversation_histories_by_npc[npc_id] = active_npc.conversation_history
	if not conversation_histories_by_npc.get(npc_id) is Array:
		conversation_histories_by_npc[npc_id] = []
	return conversation_histories_by_npc[npc_id]


## Backward-compatibility accessor exposing the active NPC's isolated history
var conversation_history: Array:
	get:
		return get_active_npc_history()
	set(val):
		if active_npc:
			var npc_id := get_npc_id(active_npc)
			conversation_histories_by_npc[npc_id] = val
			if "conversation_history" in active_npc:
				active_npc.conversation_history = val


func _ensure_ui_nodes() -> void:
	if chat_prompt_btn == null and has_node("%ChatPromptBtn"):
		chat_prompt_btn = get_node_or_null("%ChatPromptBtn") as Button
	if chat_window == null and has_node("%ChatWindow"):
		chat_window = get_node_or_null("%ChatWindow") as PanelContainer
	if npc_avatar == null and has_node("%NPCAvatar"):
		npc_avatar = get_node_or_null("%NPCAvatar") as ColorRect
	if target_label == null and has_node("%TargetLabel"):
		target_label = get_node_or_null("%TargetLabel") as Label
	if npc_stats_label == null and has_node("%NPCStatsLabel"):
		npc_stats_label = get_node_or_null("%NPCStatsLabel") as Label
	if dialogue_scroll == null and has_node("%DialogueScroll"):
		dialogue_scroll = get_node_or_null("%DialogueScroll") as ScrollContainer
	if dialogue_text == null and has_node("%DialogueText"):
		dialogue_text = get_node_or_null("%DialogueText") as RichTextLabel
	if message_input == null and has_node("%MessageInput"):
		message_input = get_node_or_null("%MessageInput") as LineEdit
	if pitch_btn == null and has_node("%PitchBtn"):
		pitch_btn = get_node_or_null("%PitchBtn") as Button
	if send_btn == null and has_node("%SendBtn"):
		send_btn = get_node_or_null("%SendBtn") as Button
	if close_btn == null and has_node("%CloseBtn"):
		close_btn = get_node_or_null("%CloseBtn") as Button
	if local_llm == null and has_node("%LocalLLM"):
		local_llm = get_node_or_null("%LocalLLM")
	if llm_status_btn == null and has_node("%LLMStatusBtn"):
		llm_status_btn = get_node_or_null("%LLMStatusBtn") as Button


func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	return null


func _ready() -> void:
	_ensure_ui_nodes()
	if chat_window:
		chat_window.visible = false
	if chat_prompt_btn:
		chat_prompt_btn.visible = false
		chat_prompt_btn.pressed.connect(_on_chat_prompt_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	if pitch_btn:
		pitch_btn.pressed.connect(_on_pitch_pressed)
	if message_input:
		message_input.text_submitted.connect(_on_message_submitted)
		message_input.focus_exited.connect(_hide_mobile_keyboard)
	
	if llm_status_btn:
		llm_status_btn.pressed.connect(_on_llm_status_btn_pressed)
	
	if local_llm:
		local_llm.connect("response_generated", Callable(self, "_on_llm_response_generated"))
		local_llm.connect("response_error", Callable(self, "_on_llm_response_error"))
		if local_llm.has_signal("connection_status_changed"):
			local_llm.connect("connection_status_changed", Callable(self, "_on_llm_status_changed"))
		if "is_connected" in local_llm and "active_backend_name" in local_llm:
			_update_llm_status_ui(bool(local_llm.get("is_connected")), str(local_llm.get("active_backend_name")))
	
	_connect_npc_signals()


func _connect_npc_signals() -> void:
	for node in get_tree().get_nodes_in_group("npcs"):
		_bind_npc(node)


func _bind_npc(npc: Node2D) -> void:
	if npc.has_signal("player_entered_interaction"):
		if not npc.is_connected("player_entered_interaction", Callable(self, "_on_npc_range_entered")):
			npc.connect("player_entered_interaction", Callable(self, "_on_npc_range_entered"))
	if npc.has_signal("player_exited_interaction"):
		if not npc.is_connected("player_exited_interaction", Callable(self, "_on_npc_range_exited")):
			npc.connect("player_exited_interaction", Callable(self, "_on_npc_range_exited"))
	if npc.has_signal("social_state_changed"):
		if not npc.is_connected("social_state_changed", Callable(self, "_on_npc_social_state_changed")):
			npc.connect("social_state_changed", Callable(self, "_on_npc_social_state_changed"))


func _input(event: InputEvent) -> void:
	if not mobile_input or not message_input.has_focus():
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed and not message_input.get_global_rect().has_point(event.position):
		# Leave the event available to the button/scroll control being tapped.
		message_input.release_focus()


func _hide_mobile_keyboard() -> void:
	if mobile_input and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_chatting:
		if mobile_input and message_input.has_focus():
			message_input.release_focus()
		else:
			end_conversation()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and active_npc != null and not is_chatting:
			start_conversation(active_npc)


func _on_npc_range_entered(npc: Node2D) -> void:
	active_npc = npc
	if not is_chatting:
		_update_prompt_button()


func _on_npc_range_exited(npc: Node2D) -> void:
	if active_npc == npc:
		if is_chatting:
			end_conversation()
		active_npc = null
		chat_prompt_btn.visible = false


func _on_npc_social_state_changed(npc: Node2D) -> void:
	if active_npc == npc:
		if is_chatting:
			_update_header_stats()
		else:
			_update_prompt_button()


func _update_prompt_button() -> void:
	_ensure_ui_nodes()
	if chat_prompt_btn == null:
		return
	if active_npc == null:
		chat_prompt_btn.visible = false
		return
	
	var name_str: String = str(active_npc.get("npc_name")) if "npc_name" in active_npc else "Resident"
	var is_refusing: bool = bool(active_npc.get("is_refusing_to_talk")) if "is_refusing_to_talk" in active_npc else false
	
	if is_refusing:
		var timer_sec: int = int(ceil(float(active_npc.get("refusal_timer")))) if "refusal_timer" in active_npc else 0
		chat_prompt_btn.text = "%s refuses to talk (%ds)" % [name_str, timer_sec]
	else:
		chat_prompt_btn.text = "Chat with %s" % name_str
	chat_prompt_btn.visible = true


func _on_chat_prompt_pressed() -> void:
	if active_npc:
		start_conversation(active_npc)


func start_conversation(npc: Node2D) -> void:
	_ensure_ui_nodes()
	_cancel_pending_reply()
	active_npc = npc
	
	# Check refusal lock-out
	var is_refusing: bool = bool(npc.get("is_refusing_to_talk")) if "is_refusing_to_talk" in npc else false
	if is_refusing:
		var name_str: String = str(npc.get("npc_name")) if "npc_name" in npc else "Resident"
		if npc.has_method("show_speech"):
			npc.show_speech("I told you to leave me alone, swindler!", name_str)
		return
	
	is_chatting = true
	if chat_prompt_btn:
		chat_prompt_btn.visible = false
	
	# Disable player movement during dialogue
	var game_state = _get_game_state()
	if game_state:
		game_state.can_player_move = false
	
	# Hide virtual joystick to avoid overlapping dialogue box
	if is_inside_tree() and get_tree():
		for joy in get_tree().get_nodes_in_group("virtual_joystick"):
			if joy is CanvasItem:
				joy.visible = false
	
	var name_str: String = str(npc.get("npc_name")) if "npc_name" in npc else "Resident"
	var occ_str: String = str(npc.get("npc_title")) if "npc_title" in npc else "Townsperson"
	if target_label:
		target_label.text = "%s (%s)" % [name_str, occ_str]
	
	if npc_avatar and "npc_color" in npc:
		npc_avatar.color = npc.get("npc_color")
		
	_update_header_stats()
	
	# Determine initial in-character greeting
	var greeting := "Hello traveler. What can I do for you today?"
	var npc_id: String = get_npc_id(npc)
	
	match npc_id:
		"npc_marla_baker":
			greeting = "Welcome to the bakery! The morning loaves are fresh out of the oven. What brings you to our square?"
		"npc_cedric_aristocrat":
			greeting = "Yes? Be brief. A gentleman of my standing has pressing affairs."
		"npc_arthur_elder":
			greeting = "Mind your step, traveler. Dark omens linger in the wind today... what do you seek?"
		"npc_barnaby_merchant", _:
			greeting = "Good day, traveler! Barnaby's Curiosities has the finest oddities in the realm. Looking for a bargain?"
	
	# Show dialogue log specific to THIS NPC ONLY
	var history := get_active_npc_history()
	if dialogue_text:
		dialogue_text.text = "" if not history.is_empty() else "[color=#f5d76e][b]%s[/b]:[/color] \"%s\"" % [_display_text(name_str), _display_text(greeting)]
		for entry in history:
			var line_str := str(entry)
			if line_str.begins_with("PLAYER: "):
				var p_text = line_str.substr(8).trim_prefix("\"").trim_suffix("\"")
				dialogue_text.text += "\n\n[color=#d8ba83][b]You:[/b][/color] \"%s\"" % _display_text(p_text)
			else:
				var colon_idx = line_str.find(": ")
				if colon_idx != -1:
					var spkr = line_str.substr(0, colon_idx)
					var r_text = line_str.substr(colon_idx + 2).trim_prefix("\"").trim_suffix("\"")
					dialogue_text.text += "\n\n[color=#f5d76e][b]%s:[/b][/color] \"%s\"" % [_display_text(spkr), _display_text(r_text)]
	
	if message_input:
		message_input.text = ""
		message_input.placeholder_text = "Type your message or pitch a con to %s..." % name_str
	if chat_window:
		chat_window.visible = true
	if not mobile_input and message_input and is_inside_tree():
		message_input.grab_focus()
	
	if npc.has_method("show_speech"):
		npc.show_speech(greeting, name_str)
	emit_signal("conversation_started", npc)


func _update_header_stats() -> void:
	if active_npc == null:
		return
	var trust: int = int(active_npc.get("trust")) if "trust" in active_npc else 50
	var susp: int = int(active_npc.get("suspicion")) if "suspicion" in active_npc else 10
	var max_spend: int = int(active_npc.get("max_daily_spend")) if "max_daily_spend" in active_npc else 200
	var spent: int = int(active_npc.get("spent_today")) if "spent_today" in active_npc else 0
	var gold: int = int(active_npc.get("gold")) if "gold" in active_npc else 500
	var remaining := mini(maxi(0, max_spend - spent), gold)
	
	if npc_stats_label:
		npc_stats_label.text = "Trust: %d%% | Suspicion: %d%% | Daily Budget: %d / %d Kurtos" % [
			trust, susp, remaining, max_spend
		]


func end_conversation() -> void:
	_ensure_ui_nodes()
	_cancel_pending_reply()
	is_chatting = false
	if chat_window:
		chat_window.visible = false
	if message_input and is_inside_tree():
		message_input.release_focus()
	if send_btn:
		send_btn.disabled = false
	if pitch_btn:
		pitch_btn.disabled = false
	
	var game_state = _get_game_state()
	if game_state:
		game_state.can_player_move = true
	
	# Restore virtual joystick
	if is_inside_tree() and get_tree():
		for joy in get_tree().get_nodes_in_group("virtual_joystick"):
			if joy is CanvasItem:
				joy.visible = true
	
	if active_npc:
		var ended_npc = active_npc
		if active_npc.has_method("hide_speech"):
			active_npc.hide_speech()
		if bool(active_npc.get("is_player_in_range")):
			_update_prompt_button()
		else:
			active_npc = null
		emit_signal("conversation_ended", ended_npc)


func _on_close_pressed() -> void:
	end_conversation()


func _on_message_submitted(_text: String) -> void:
	_on_send_pressed()


## Suggested pitch button tailored to the active NPC's identity & player items
func _on_pitch_pressed() -> void:
	if active_npc == null:
		return
	
	var npc_id := get_npc_id(active_npc)
	var game_state = _get_game_state()
	var has_tonic: bool = (game_state != null and game_state.has_item("miracle_tonic_sample"))
	var has_fabric: bool = (game_state != null and game_state.has_item("fabric_sample"))
	var has_robe: bool = (game_state != null and game_state.has_item("beggars_robe"))
	var has_monocle: bool = (game_state != null and (game_state.has_item("monocle") or game_state.has_item("forged_patent")))
	
	var suggested := ""
	match npc_id:
		"npc_marla_baker":
			if has_robe:
				suggested = "My family is stricken with terrible illness and fever! Could you spare some Kurtos for medicine?"
			elif has_fabric:
				suggested = "I have a lovely silk swatch for fine aprons and dresses! Would you buy it for 40 Kurtos?"
			else:
				suggested = "Good morning, baker Marla! What fresh delicacies are you baking in the town square today?"
		"npc_arthur_elder":
			if has_tonic:
				suggested = "I will sell you this miracle tonic sample to cure ancient curses and ward off midnight omens for 40 Kurtos!"
			elif has_robe:
				suggested = "Poor and weary traveler here, Elder Arthur. The spirits warned me of cold nights ahead."
			else:
				suggested = "What ancient omens and curses have you witnessed troubling our village, Elder?"
		"npc_cedric_aristocrat":
			if has_monocle:
				suggested = "Greetings, my Lord. I represent a prestigious royal investment society with exclusive privileges."
			elif has_fabric:
				suggested = "My Lord Cedric, I bring an imported royal silk swatch fit for court regalia, for 60 Kurtos!"
			else:
				suggested = "Good day, Lord Cedric. How fare the noble houses and high society in these lands?"
		"npc_barnaby_merchant", _:
			if has_tonic:
				suggested = "I have a rare miracle tonic sample with high resale value for your shop, for 40 Kurtos!"
			elif has_fabric:
				suggested = "I have a vibrant silk swatch for fine tailoring—I'll sell it to your shop for 40 Kurtos!"
			else:
				suggested = "Greetings Barnaby! What rare curiosities and wares are trading best in the market today?"
	
	if message_input:
		message_input.text = suggested
		if is_inside_tree():
			message_input.grab_focus()


func _on_send_pressed() -> void:
	if _waiting_for_reply or not is_chatting:
		return
	var text := message_input.text.strip_edges()
	if text.is_empty() or active_npc == null:
		return
	
	# Block message if NPC is refusing to talk
	if bool(active_npc.get("is_refusing_to_talk")):
		end_conversation()
		return
	
	_last_sent_text = text
	var game_state = _get_game_state()
	var inv: Array[Dictionary] = game_state.inventory if game_state else []
	_last_sent_category = ScamManager.categorize_message(text, inv)
	
	if mobile_input and message_input and is_inside_tree():
		message_input.release_focus()
	
	var cur_history := get_active_npc_history()
	var request_history := cur_history.duplicate()
	_pending_history = request_history
	if active_npc and active_npc.has_method("add_conversation_turn"):
		active_npc.add_conversation_turn("PLAYER", text)
	else:
		cur_history.append("PLAYER: \"%s\"" % text)
	
	message_input.text = ""
	
	# Disable inputs while awaiting AI response
	if send_btn:
		send_btn.disabled = true
	if pitch_btn:
		pitch_btn.disabled = true
	_waiting_for_reply = true
	_pending_npc = active_npc
	
	var name_str: String = str(active_npc.get("npc_name")) if "npc_name" in active_npc else "Resident"
	
	# Append player message into the visible chatbox log
	dialogue_text.text += "\n\n[color=#d8ba83][b]You:[/b][/color] \"%s\"" % _display_text(text)
	dialogue_text.text += "\n[color=#b8aa93][i]%s is considering your words...[/i][/color]" % name_str
	_scroll_dialogue_to_bottom()
	
	if active_npc.has_method("show_thinking"):
		active_npc.show_thinking()
	
	var profile: Dictionary = active_npc.get_full_profile() if active_npc.has_method("get_full_profile") else {}
	if local_llm and local_llm.has_method("request_reply"):
		var id: Variant = local_llm.call("request_reply", profile, text, request_history, _last_sent_category)
		_pending_request_id = int(id) if id is int else -1
		if _pending_request_id == 0:
			_on_llm_response_error("Local chat is busy; please retry.")
	else:
		_on_llm_response_error("Local chat is unavailable.")


func _on_llm_response_generated(result: Dictionary) -> void:
	if not _waiting_for_reply or not is_chatting or active_npc != _pending_npc:
		return
	if _pending_request_id > 0 and (int(result.get("request_id", 0)) != _pending_request_id or str(result.get("npc_id", "")) != get_npc_id(active_npc)):
		return
	_waiting_for_reply = false
	_pending_request_id = 0
	_pending_npc = null
	_pending_history = []
	var replying_npc := active_npc
	var cur_history := get_active_npc_history()
	if send_btn:
		send_btn.disabled = false
	if pitch_btn:
		pitch_btn.disabled = false
	
	if active_npc == null:
		return
	
	# Execute deterministic scam resolution through ScamManager & EconomyManager FIRST
	var eval_res := _resolve_interaction(result)
	var transferred: int = int(eval_res.get("actual_transferred", 0))
	var outcome = eval_res.get("outcome")
	
	var reply: String = str(result.get("response", "..."))
	var proposed: int = int(result.get("proposed_kurtos", 0))
	
	# Synchronize dialogue text with the actual transferred money
	if proposed > 0 and transferred != proposed:
		if transferred > 0:
			reply = reply.replace("%d Kurtos" % proposed, "%d Kurtos" % transferred)
			reply = reply.replace(str(proposed) + " Kurtos", str(transferred) + " Kurtos")
		else:
			reply = "I cannot spare any Kurtos right now."
	
	var name_str: String = str(replying_npc.get("npc_name")) if "npc_name" in replying_npc else "Resident"
	
	# Strip temporary "is considering your words..." text
	var thinking_tag := "\n[color=#b8aa93][i]%s is considering your words...[/i][/color]" % name_str
	dialogue_text.text = dialogue_text.text.replace(thinking_tag, "")
	
	# Display reply in the chatbox log
	dialogue_text.text += "\n\n[color=#f5d76e][b]%s:[/b][/color] \"%s\"" % [_display_text(name_str), _display_text(reply)]
	
	var feedback: String = str(eval_res.get("feedback_message", ""))
	if not feedback.is_empty():
		if transferred > 0:
			dialogue_text.text += "\n[color=#b6d18b]%s[/color]" % feedback
		elif outcome == ScamManager.ScamOutcome.FAILED_EXPOSED:
			dialogue_text.text += "\n[color=#f0a080]%s[/color]" % feedback
		elif outcome == ScamManager.ScamOutcome.SOCIAL_CHAT:
			dialogue_text.text += "\n[color=#9ad1d4]%s[/color]" % feedback
		else:
			dialogue_text.text += "\n[color=#e0a96d]%s[/color]" % feedback
	
	_scroll_dialogue_to_bottom()
	
	# Also update world-space speech bubble if visible
	if replying_npc.has_method("show_speech"):
		replying_npc.show_speech(reply, name_str)
	
	if replying_npc.has_method("add_conversation_turn"):
		replying_npc.add_conversation_turn(name_str, reply)
	else:
		cur_history.append("%s: \"%s\"" % [name_str, reply])
	var turns: int = clampi(local_llm.history_exchanges, 1, 5) * 2 if local_llm is LocalLLM else 10
	while cur_history.size() > turns:
		cur_history.pop_front()
	
	if is_chatting:
		_update_header_stats()
		if not mobile_input and message_input and is_inside_tree():
			message_input.grab_focus()


func _resolve_interaction(llm_result: Dictionary) -> Dictionary:
	if active_npc == null:
		return {}
	
	var game_state = _get_game_state()
	var inventory: Array[Dictionary] = game_state.inventory if game_state else []
	var overall_trust: int = game_state.overall_trust if game_state else 25
	
	var profile: Dictionary = active_npc.get_full_profile() if active_npc.has_method("get_full_profile") else {}
	var cat_data := _last_sent_category
	if cat_data.is_empty():
		cat_data = ScamManager.categorize_message(_last_sent_text, inventory)
	
	var eval_res: Dictionary
	if llm_result.has("threshold_decision") and not (llm_result["threshold_decision"] as Dictionary).is_empty():
		eval_res = (llm_result["threshold_decision"] as Dictionary).duplicate()
	else:
		eval_res = ScamManager.resolve_interaction(cat_data, profile, _last_sent_text, llm_result, inventory, overall_trust)
	
	var transfer_amount: int = int(eval_res.get("transfer_amount", 0))
	var trust_delta: int = int(eval_res.get("trust_delta", 0))
	var susp_delta: int = int(eval_res.get("suspicion_delta", 0))
	var rep_delta: int = int(eval_res.get("reputation_delta", 0))
	var will_refuse: bool = bool(eval_res.get("will_refuse", false))
	var outcome = eval_res.get("outcome")
	
	# Update authoritative trust and suspicion
	var cur_trust: int = int(active_npc.get("trust")) if "trust" in active_npc else 50
	var cur_susp: int = int(active_npc.get("suspicion")) if "suspicion" in active_npc else 10
	active_npc.set("trust", clampi(cur_trust + trust_delta, 0, 100))
	active_npc.set("suspicion", clampi(cur_susp + susp_delta, 0, 100))
	
	if game_state and rep_delta != 0 and game_state.has_method("modify_overall_trust"):
		game_state.modify_overall_trust(rep_delta)
	
	var actual_transferred := 0
	# Money transfer execution
	if transfer_amount > 0:
		actual_transferred = EconomyManager.transfer_kurtos_from_npc(active_npc, transfer_amount, str(eval_res.get("reason", "Scam")))
		if actual_transferred > 0:
			if "successful_scam_count" in active_npc:
				active_npc.set("successful_scam_count", int(active_npc.get("successful_scam_count")) + 1)
			if active_npc.has_method("add_memory"):
				active_npc.add_memory("Agreed to deal and paid %d Kurtos." % actual_transferred)
	else:
		if outcome == ScamManager.ScamOutcome.FAILED_EXPOSED:
			if "failed_scam_count" in active_npc:
				active_npc.set("failed_scam_count", int(active_npc.get("failed_scam_count")) + 1)
			if active_npc.has_method("add_memory"):
				active_npc.add_memory("Caught player attempting deception.")
	
	eval_res["actual_transferred"] = actual_transferred
	
	# Trigger refusal if suspicion reached lock-out threshold
	if will_refuse:
		if active_npc.has_method("trigger_refusal"):
			active_npc.trigger_refusal(35.0)
		end_conversation()
	
	return eval_res


func _scroll_dialogue_to_bottom() -> void:
	if dialogue_scroll and is_inside_tree() and get_tree():
		await get_tree().process_frame
		var v_bar := dialogue_scroll.get_v_scroll_bar()
		if v_bar:
			dialogue_scroll.scroll_vertical = int(v_bar.max_value)


func _on_llm_response_error(err: String) -> void:
	if not _waiting_for_reply:
		return
	_cancel_pending_reply()
	if send_btn:
		send_btn.disabled = false
	if pitch_btn:
		pitch_btn.disabled = false
	if active_npc:
		var name_str: String = str(active_npc.get("npc_name")) if "npc_name" in active_npc else "Resident"
		var thinking_tag := "\n[color=#b8aa93][i]%s is considering your words...[/i][/color]" % name_str
		dialogue_text.text = dialogue_text.text.replace(thinking_tag, "")
		if active_npc.has_method("show_speech"):
			active_npc.show_speech("...", name_str)
	print("[ChatUI] LLM Error: ", err)


func _on_llm_status_btn_pressed() -> void:
	if local_llm and local_llm.has_method("check_connection"):
		if llm_status_btn:
			llm_status_btn.text = "🔄 AI: Checking..."
		local_llm.check_connection()


func _on_llm_status_changed(connected: bool, status_text: String) -> void:
	_update_llm_status_ui(connected, status_text)


func _update_llm_status_ui(connected: bool, status_text: String) -> void:
	if llm_status_btn == null:
		return
	if connected:
		var label := status_text
		if label.begins_with("Ollama: "):
			var mod_name := label.substr(8)
			if ":" in mod_name:
				mod_name = mod_name.split(":")[0]
			label = "Ollama (%s)" % mod_name
		elif label.length() > 16:
			label = label.substr(0, 14) + ".."
		llm_status_btn.text = "🟢 %s" % label
		llm_status_btn.tooltip_text = "AI Connected (%s)\nClick to recheck status." % status_text
	else:
		llm_status_btn.text = "🟠 AI: Offline"
		llm_status_btn.tooltip_text = "Local chat uses canned replies while offline.\nStart llama-server separately, then click to retry."


func _display_text(text: String) -> String:
	# Player/model brackets are rendered literally, never as BBCode/images/URLs.
	return text.replace("[", "[lb]")


func _cancel_pending_reply() -> void:
	if _waiting_for_reply and is_instance_valid(_pending_npc):
		var history := get_active_npc_history()
		if not history.is_empty() and str(history.back()) == "PLAYER: \"%s\"" % _last_sent_text:
			# NPC.add_conversation_turn may have evicted the oldest turn at its cap.
			# Restore the complete pre-request history, unless a day reset cleared it.
			history.assign(_pending_history)
	if local_llm and local_llm.has_method("cancel_request"):
		local_llm.cancel_request()
	_waiting_for_reply = false
	_pending_request_id = 0
	_pending_npc = null
	_pending_history = []
	if send_btn:
		send_btn.disabled = false
	if pitch_btn:
		pitch_btn.disabled = false

