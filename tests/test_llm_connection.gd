extends SceneTree
## Live inference through the actual ChatUI. Run only with isolated test saves.
## Transport assertions and small-model quality observations are separate.
const PROFILES := ["barnaby_merchant", "marla_baker", "cedric_aristocrat", "arthur_elder"]
const QUESTIONS := [
	"What matters most when choosing rare wares?",
	"What do you bake for the townsfolk?",
	"What makes a royal gathering worthy of your attendance?",
	"What omens concern you most?"
]
const VOICE_WORDS := [
	["coin", "profit", "ware", "trade", "rare", "curio", "merchant"],
	["bread", "bake", "loaf", "loaves", "pastr", "oven"],
	["royal", "nobl", "prestige", "exclusive", "aristoc", "king", "luxur"],
	["omen", "spirit", "curse", "shadow", "ancestor", "star", "ward"]
]
var chat: ChatUI
var llm: LocalLLM
var results: Array = []
var observations: Array = []
var checks := 0
var failures := 0
var deadline := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _process(_delta: float) -> bool:
	if deadline > 0 and Time.get_ticks_msec() > deadline:
		push_error("Live suite watchdog expired")
		quit(1)
	return false

func settle() -> void:
	for i in range(4): await process_frame

func run() -> void:
	deadline = Time.get_ticks_msec() + 300000
	chat = load("res://scenes/ui/chat_ui.tscn").instantiate()
	llm = chat.get_node("LocalLLM")
	llm.auto_probe = false
	root.add_child(chat)
	llm.response_generated.connect(func(result: Dictionary): results.append(result))
	llm.check_connection()
	var health_deadline := Time.get_ticks_msec() + 3000
	while is_instance_valid(llm._probe_http) and Time.get_ticks_msec() < health_deadline:
		await process_frame
	if not llm.is_connected:
		print("SKIPPED: no healthy llama.cpp server; no inference pass claimed.")
		chat.queue_free()
		await settle()
		quit(2)
		return
	for i in range(PROFILES.size()):
		var npc := TownNPC.new()
		npc.npc_data_file = "res://data/npcs/%s.json" % PROFILES[i]
		root.add_child(npc)
		chat.start_conversation(npc)
		var payload := llm.build_chat_payload(npc.get_full_profile(), "Hello", [])
		check(payload.messages[0].content.contains(npc.npc_name) and payload.messages[0].content.contains(npc.npc_profile.background), "Live authored persona " + npc.npc_name)
		await send(npc, "I'm selling a magical BLUE potion.", i, "introduction")
		payload = llm.build_chat_payload(npc.get_full_profile(), "What color was the potion I mentioned?", npc.conversation_history)
		check(payload.messages.size() == 4 and payload.messages[1].content.contains("BLUE"), "Live recall request contains own previous player turn")
		check(payload.messages[2].content == str(results.back().response).left(llm.max_turn_characters) if not results.is_empty() else false, "Live recall request contains own previous reply within configured character bound")
		await send(npc, "What color was the potion I mentioned?", i, "memory")
		await send(npc, QUESTIONS[i], i, "personality")
		check(npc.conversation_history.size() == 6, "Live three completed exchanges retained")
		chat.end_conversation()
		npc.queue_free()
		await settle()
	var memory_hits := 0
	var voice_hits := 0
	for entry in observations:
		if entry.kind == "memory" and entry.color_recalled: memory_hits += 1
		if entry.kind == "personality" and entry.voice_keyword_match: voice_hits += 1
	var report := {
		"transport_checks": checks, "transport_failures": failures,
		"memory_correct": memory_hits, "memory_total": 4,
		"personality_keyword_matches": voice_hits, "personality_total": 4,
		"quality_note": "Recall and keyword observations are model quality, not proof of a context bug.",
		"responses": observations
	}
	var file := FileAccess.open("res://.godot/llm-live-report.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	print("Live chat: %d checks, %d failures; BLUE recall %d/4; personality keyword matches %d/4" % [checks, failures, memory_hits, voice_hits])
	chat.queue_free()
	await settle()
	quit(0 if failures == 0 else 1)

func send(npc: TownNPC, message: String, index: int, kind: String) -> void:
	var before := results.size()
	chat.message_input.text = message
	chat.send_btn.pressed.emit()
	var id: int = chat._pending_request_id
	var request_deadline := Time.get_ticks_msec() + 32000
	while llm.is_busy() and Time.get_ticks_msec() < request_deadline: await process_frame
	await settle()
	check(not llm.is_busy() and not chat.send_btn.disabled, "Live input restored")
	if results.size() != before + 1:
		check(false, "Exactly one live completion for " + npc.npc_name)
		llm.cancel_request()
		return
	var result: Dictionary = results.back()
	var reply := str(result.get("response", ""))
	check(result.get("is_live_llm", false) and not reply.strip_edges().is_empty(), "Real generated response for " + npc.npc_name)
	check(result.get("request_id") == id and result.get("npc_id") == npc.npc_profile.id, "Live reply belongs to correct NPC/request")
	check(chat.dialogue_text.get_parsed_text().contains(reply), "Live reply reaches existing dialogue panel")
	var voice_match := false
	for word in VOICE_WORDS[index]:
		if reply.to_lower().contains(word): voice_match = true
	observations.append({
		"npc": npc.npc_name, "kind": kind, "player": message, "reply": reply,
		"live": result.get("is_live_llm", false),
		"color_recalled": reply.to_lower().contains("blue"),
		"voice_keyword_match": voice_match
	})
	print("LIVE %s (%s): %s" % [npc.npc_name, kind, reply])
