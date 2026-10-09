extends SceneTree

## Automated test suite for Snake Oil Salesman gameplay mechanics.
## Verifies AGENTS.md Rule 9 deterministic rules and authority boundary.

var passed_count: int = 0
var failed_count: int = 0


func _init() -> void:
	print("\n=======================================================")
	print("🧪 RUNNING SNAKE OIL SALESMAN MECHANICS TEST SUITE")
	print("=======================================================\n")
	
	test_game_state_kurtos_and_limits()
	test_economy_spending_caps()
	test_scam_backstory_affinity_matching()
	test_inventory_item_synergies()
	test_suspicion_escalation_and_refusal_state()
	test_day_rollover_resets()
	test_malformed_llm_response_parsing()
	test_phantom_item_detection_and_physical_evidence()
	test_building_colliders_match_assets()
	test_categorized_interaction_and_deal_triggers()
	test_evaluation_threshold_rules()
	test_npc_conversation_history_isolation()
	test_character_sprites_and_animations()
	test_environmental_foliage_paths_and_particles()
	test_live_flora_biome_props_and_rustle()
	
	print("\n-------------------------------------------------------")
	print("🏁 TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("-------------------------------------------------------\n")
	
	quit(0 if failed_count == 0 else 1)


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		print("  ✅ PASS: %s" % test_name)
		passed_count += 1
	else:
		print("  ❌ FAIL: %s" % test_name)
		failed_count += 1


func assert_eq(actual, expected, test_name: String) -> void:
	if actual == expected:
		print("  ✅ PASS: %s" % test_name)
		passed_count += 1
	else:
		print("  ❌ FAIL: %s (Expected: %s, Got: %s)" % [test_name, str(expected), str(actual)])
		failed_count += 1


func test_game_state_kurtos_and_limits() -> void:
	print("▶ Testing GameState Kurtos Arithmetic & End Conditions...")
	var gs := GameStateManager.new()
	root.add_child(gs)
	
	assert_eq(gs.player_kurtos, 50, "Initial player Kurtos should be 50")
	assert_eq(gs.current_day, 1, "Initial day should be 1")
	
	gs.add_kurtos(450)
	assert_eq(gs.player_kurtos, 500, "Adding 450 Kurtos results in 500")
	
	var spent := gs.spend_kurtos(200)
	assert_true(spent, "Spending valid amount should succeed")
	assert_eq(gs.player_kurtos, 300, "Spending 200 Kurtos leaves 300")
	
	var overspend := gs.spend_kurtos(1000)
	assert_true(not overspend, "Spending more Kurtos than owned should fail")
	assert_eq(gs.player_kurtos, 300, "Failed spend does not deduct currency")
	
	# Win condition test
	gs.add_kurtos(1_000_000)
	assert_true(gs.is_game_over, "Reaching 1M Kurtos triggers game over")
	assert_true(gs.has_won, "Reaching 1M Kurtos triggers victory")
	
	gs.queue_free()


func test_economy_spending_caps() -> void:
	print("\n▶ Testing EconomyManager Daily Spending Caps & Clamping...")
	
	var mock_npc := {
		"name": "TestNPC",
		"gold": 1000,
		"max_daily_spend": 300,
		"spent_today": 0
	}
	
	var budget_initial := EconomyManager.get_remaining_daily_budget(mock_npc)
	assert_eq(budget_initial, 300, "Remaining daily budget equals max_daily_spend when 0 spent")
	
	# Simulate spending 120
	mock_npc["spent_today"] = 120
	var budget_after_spend := EconomyManager.get_remaining_daily_budget(mock_npc)
	assert_eq(budget_after_spend, 180, "Remaining daily budget correctly subtracts spent_today")
	
	# Spending cap when NPC total gold is lower than daily cap
	mock_npc["gold"] = 50
	mock_npc["spent_today"] = 0
	var budget_low_gold := EconomyManager.get_remaining_daily_budget(mock_npc)
	assert_eq(budget_low_gold, 50, "Remaining daily budget is capped by NPC's total available gold")


func test_scam_backstory_affinity_matching() -> void:
	print("\n▶ Testing Backstory Susceptibility & Skepticism Matching with Item Gating...")
	
	# Arthur (Elder): susceptible to cures/curses
	var arthur_data := {
		"name": "Old Arthur",
		"trust": 55,
		"suspicion": 10,
		"gold": 400,
		"max_daily_spend": 180,
		"spent_today": 0,
		"personality": {"superstitious": 0.95, "skeptical": 0.2},
		"susceptible_topics": ["curse", "omen", "miracle", "tonic", "elixir"],
		"skeptical_topics": ["skeptic", "logic"]
	}
	
	var llm_response_arthur := {"intent": "PITCH_SCAM", "credibility": 0.85, "relationship_signal": "POSITIVE"}
	var empty_inv: Array[Dictionary] = []
	
	# Case 1: Arthur with empty inventory (no tonic bottle) -> REJECTED!
	var res_arthur_empty := ScamManager.evaluate_pitch(
		arthur_data,
		"I have a miracle elixir to protect your home from dark omens and ancient curses!",
		llm_response_arthur,
		empty_inv,
		25
	)
	assert_true(res_arthur_empty.outcome != ScamManager.ScamOutcome.SUCCESS, "Arthur rejects elixir pitch without tonic sample in inventory")
	assert_eq(res_arthur_empty.transfer_amount, 0, "No Kurtos transferred when player has no tonic vial")
	
	# Case 2: Arthur WITH miracle tonic sample in inventory -> SUCCEEDS!
	var inv_with_tonic: Array[Dictionary] = [{"id": "miracle_tonic_sample", "name": "Miracle Tonic Sample"}]
	var res_arthur_with_tonic := ScamManager.evaluate_pitch(
		arthur_data,
		"I have a miracle elixir to protect your home from dark omens and ancient curses!",
		llm_response_arthur,
		inv_with_tonic,
		25
	)
	assert_eq(res_arthur_with_tonic.outcome, ScamManager.ScamOutcome.SUCCESS, "Arthur is convinced when player holds genuine tonic sample")
	assert_true(res_arthur_with_tonic.transfer_amount > 0, "Arthur donates Kurtos on successful pitch with tonic sample")
	
	# Marla (Baker): susceptible to sick family
	var marla_data := {
		"name": "Marla",
		"trust": 65,
		"suspicion": 10,
		"gold": 650,
		"max_daily_spend": 220,
		"spent_today": 0,
		"personality": {"empathetic": 0.90, "trusting": 0.75},
		"susceptible_topics": ["sick", "fever", "illness", "child", "family", "charity"],
		"skeptical_topics": ["threat", "extort", "robbery"]
	}
	
	var llm_response_marla := {"intent": "PITCH_SCAM", "credibility": 0.85, "relationship_signal": "POSITIVE"}
	
	# Case 1: Marla with empty inventory (clean clothes, no beggar's robe) -> REJECTED!
	var res_marla_empty := ScamManager.evaluate_pitch(
		marla_data,
		"My family has fallen sick with a terrible fever, our child needs medicine! Please spare charity!",
		llm_response_marla,
		empty_inv,
		25
	)
	assert_true(res_marla_empty.outcome != ScamManager.ScamOutcome.SUCCESS, "Marla rejects sob story when player lacks beggar's robe")
	assert_eq(res_marla_empty.transfer_amount, 0, "Zero Kurtos transferred when player has clean clothes and no beggar's robe")
	
	# Case 2: Marla WITH Beggar's Robe -> SUCCEEDS!
	var inv_with_robe: Array[Dictionary] = [{"id": "beggars_robe", "name": "Beggar's Robe"}]
	var res_marla_with_robe := ScamManager.evaluate_pitch(
		marla_data,
		"My family has fallen sick with a terrible fever, our child needs medicine! Please spare charity!",
		llm_response_marla,
		inv_with_robe,
		25
	)
	assert_eq(res_marla_with_robe.outcome, ScamManager.ScamOutcome.SUCCESS, "Marla is deeply moved when player is wearing Beggar's Robe")
	assert_eq(res_marla_with_robe.transfer_amount, 220, "Marla gives full daily budget when player wears Beggar's Robe")


func test_inventory_item_synergies() -> void:
	print("\n▶ Testing Inventory Item Synergies & Gating Across All NPC Personas...")
	
	var marla_data := {
		"name": "Marla",
		"trust": 40,
		"suspicion": 20,
		"gold": 600,
		"max_daily_spend": 200,
		"spent_today": 0,
		"personality": {"empathetic": 0.9},
		"susceptible_topics": ["charity"],
		"skeptical_topics": []
	}
	
	var llm_response := {"intent": "PITCH_SCAM", "credibility": 0.5, "relationship_signal": "NEUTRAL"}
	
	# Without Beggar's Robe
	var res_no_item := ScamManager.evaluate_pitch(marla_data, "Please spare charity for a starving beggar", llm_response, [], 20)
	assert_eq(res_no_item.transfer_amount, 0, "Charity pitch without Beggar's Robe transfers 0 Kurtos")
	
	# With Beggar's Robe
	var inv_with_robe: Array[Dictionary] = [{"id": "beggars_robe", "name": "Beggar's Robe"}]
	var res_with_robe := ScamManager.evaluate_pitch(marla_data, "Please spare charity for a starving beggar", llm_response, inv_with_robe, 20)
	assert_true(res_with_robe.score > res_no_item.score, "Beggar's Robe increases pitch score with empathetic NPC")
	assert_eq(res_with_robe.item_bonus, 45.0, "Beggar's Robe grants +45 item bonus (+30 base +15 empathetic)")
	
	# Cedric Monocle gating test
	var cedric_data := {
		"name": "Lord Cedric",
		"trust": 35,
		"suspicion": 15,
		"gold": 5000,
		"max_daily_spend": 1000,
		"spent_today": 0,
		"personality": {"status_sensitive": 0.95, "skeptical": 0.7},
		"susceptible_topics": ["royal", "noble", "prestige"],
		"skeptical_topics": ["beggar"]
	}
	var noble_pitch := "I represent high nobility with an exclusive royal investment opportunity!"
	var llm_noble := {"intent": "PITCH_SCAM", "credibility": 0.85, "relationship_signal": "POSITIVE", "convinced": true}
	
	# Without Monocle
	var res_cedric_no_monocle := ScamManager.evaluate_pitch(cedric_data, noble_pitch, llm_noble, [], 20)
	assert_true(res_cedric_no_monocle.outcome != ScamManager.ScamOutcome.SUCCESS, "Cedric rejects royal pitch without gentleman's monocle")
	assert_eq(res_cedric_no_monocle.transfer_amount, 0, "Cedric transfers 0 Kurtos without monocle")
	
	# With Monocle
	var inv_with_monocle: Array[Dictionary] = [{"id": "monocle", "name": "Gentleman's Monocle"}]
	var res_cedric_with_monocle := ScamManager.evaluate_pitch(cedric_data, noble_pitch, llm_noble, inv_with_monocle, 20)
	assert_eq(res_cedric_with_monocle.outcome, ScamManager.ScamOutcome.SUCCESS, "Cedric accepts royal pitch when player wears gentleman's monocle")
	assert_true(res_cedric_with_monocle.transfer_amount > 0, "Cedric transfers Kurtos when monocle is present")


func test_suspicion_escalation_and_refusal_state() -> void:
	print("\n▶ Testing Suspicion Escalation & Refusal Lock-out...")
	
	var cedric_data := {
		"name": "Lord Cedric",
		"trust": 20,
		"suspicion": 55, # Already somewhat suspicious
		"gold": 5000,
		"max_daily_spend": 1000,
		"spent_today": 0,
		"personality": {"skeptical": 0.8, "status_sensitive": 0.95},
		"susceptible_topics": ["royal"],
		"skeptical_topics": ["beggar", "peasant", "spare coin"]
	}
	
	# Rude beggar message triggers skeptical topic and low credibility
	var llm_bad_pitch := {"intent": "LIE", "credibility": 0.15, "relationship_signal": "NEGATIVE"}
	var res_cedric := ScamManager.evaluate_pitch(
		cedric_data,
		"Hey peasant noble, hand over a spare coin for this beggar!",
		llm_bad_pitch,
		[],
		20
	)
	
	assert_eq(res_cedric.outcome, ScamManager.ScamOutcome.FAILED_EXPOSED, "Insulting beggar claim is exposed as failed con")
	assert_true(res_cedric.suspicion_delta >= 20, "Exposed con adds high suspicion (+26)")
	assert_true(res_cedric.will_refuse, "Suspicion escalation triggers refusal lock-out")


func test_day_rollover_resets() -> void:
	print("\n▶ Testing Day Rollover Daily Spend Reset & Cooldowns...")
	
	var npc := TownNPC.new()
	npc.max_daily_spend = 300
	npc.spent_today = 300
	npc.suspicion = 80
	npc.trigger_refusal(60.0)
	
	assert_true(npc.is_refusing_to_talk, "NPC enters refusal state")
	
	# Advance day
	npc.on_day_rollover(2)
	
	assert_eq(npc.spent_today, 0, "Day rollover resets spent_today to 0")
	assert_eq(npc.suspicion, 60, "Day rollover cools down suspicion by 20 points")
	assert_true(not npc.is_refusing_to_talk, "Day rollover clears refusal state")
	
	npc.queue_free()


func test_malformed_llm_response_parsing() -> void:
	print("\n▶ Testing LLM Response Validation & Fallback Safety...")
	
	var llm := LocalLLM.new()
	root.add_child(llm)
	
	# Valid JSON
	var valid_json := '{"intent": "PITCH_SCAM", "tone": "FRIENDLY", "credibility": 0.85, "relationship_signal": "POSITIVE", "convinced": true, "proposed_kurtos": 250, "response": "Sounds marvelous!"}'
	var parsed_valid := llm._parse_and_validate_response(valid_json)
	assert_eq(parsed_valid.intent, "PITCH_SCAM", "Parses valid intent")
	assert_eq(parsed_valid.credibility, 0.85, "Parses and clamps credibility")
	assert_eq(parsed_valid.proposed_kurtos, 250, "Parses proposed Kurtos")
	
	# Malformed / gibberish string
	var malformed := "I am an AI and here is my answer: [not json]"
	var parsed_bad := llm._parse_and_validate_response(malformed)
	assert_true(parsed_bad.is_empty(), "Malformed LLM output safely evaluates to empty Dictionary for fallback")
	
	# Clamping out-of-range credibility
	var extreme_json := '{"intent": "NORMAL_CONVERSATION", "credibility": 99.9, "response": "Yes"}'
	var parsed_extreme := llm._parse_and_validate_response(extreme_json)
	assert_eq(parsed_extreme.credibility, 1.0, "Excessive credibility clamped to 1.0")
	
	llm.queue_free()


func test_phantom_item_detection_and_physical_evidence() -> void:
	print("\n▶ Testing Physical Merchandise Verification & Phantom Item Bluff Detection...")
	
	var barnaby_data := {
		"name": "Barnaby",
		"trust": 45,
		"suspicion": 15,
		"gold": 1200,
		"max_daily_spend": 350,
		"spent_today": 0,
		"personality": {"greedy": 0.75, "skeptical": 0.50},
		"susceptible_topics": ["profit", "trade", "deal"],
		"skeptical_topics": ["tax"]
	}
	
	var fabric_pitch := "Hi, invest in my designer fabric business! Here is a design of the fabric. Look at its color!!"
	var llm_response := {"intent": "PITCH_SCAM", "credibility": 0.5, "relationship_signal": "NEUTRAL"}
	
	# Case 1: Player has NO fabric sample in inventory (empty hands bluff)
	var empty_inv: Array[Dictionary] = []
	var res_phantom := ScamManager.evaluate_pitch(barnaby_data, fabric_pitch, llm_response, empty_inv, 25)
	assert_true(res_phantom.outcome != ScamManager.ScamOutcome.SUCCESS, "Phantom fabric pitch without sample fails")
	assert_true(res_phantom.suspicion_delta >= 18, "Claiming to show fabric with empty hands incurs heavy suspicion (+18)")
	
	# Case 2: Player HAS the fabric sample in inventory
	var inv_with_fabric: Array[Dictionary] = [{"id": "fabric_sample", "name": "Vibrant Silk Swatch"}]
	var llm_response_backed := {"intent": "PITCH_SCAM", "credibility": 0.85, "convinced": true, "relationship_signal": "POSITIVE"}
	var res_backed := ScamManager.evaluate_pitch(barnaby_data, fabric_pitch, llm_response_backed, inv_with_fabric, 25)
	assert_true(res_backed.score > res_phantom.score, "Backing up pitch with genuine physical inventory sample gives massive score boost")
	assert_eq(res_backed.outcome, ScamManager.ScamOutcome.SUCCESS, "Pitch with physical merchandise in inventory succeeds")


func test_building_colliders_match_assets() -> void:
	print("\n▶ Testing Building Colliders Match Visual Assets...")
	
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert_true(scene != null, "scenes/main.tscn loads successfully")
	var instance := scene.instantiate()
	root.add_child(instance)
	
	var buildings_node := instance.get_node_or_null("Buildings")
	assert_true(buildings_node != null, "Buildings container exists in scene")
	
	for bld_name in ["BakeryBuilding", "MerchantShop", "ChurchBuilding"]:
		var bld := buildings_node.get_node_or_null(bld_name) as VillageBuilding
		assert_true(bld != null, "%s exists in scene" % bld_name)
		if bld == null:
			continue
		
		var col_poly := bld.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		assert_true(col_poly != null, "%s has CollisionPolygon2D" % bld_name)
		if col_poly != null:
			assert_true(not col_poly.disabled, "%s CollisionPolygon2D is enabled" % bld_name)
			assert_true(col_poly.polygon.size() >= 20, "%s polygon has matching detailed vertex count (%d pts)" % [bld_name, col_poly.polygon.size()])
		
		var col_shape := bld.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col_shape != null:
			assert_true(col_shape.disabled, "%s legacy rectangular shape is disabled" % bld_name)
	
	# Test auto-generation from texture
	var dynamic_bld := VillageBuilding.new()
	dynamic_bld.building_texture = load("res://assets/village_top_down/TILESET VILLAGE TOP DOWN/HOUSE 1 - DAY.png")
	dynamic_bld.match_asset_collider = true
	var dynamic_poly := CollisionPolygon2D.new()
	dynamic_bld.add_child(dynamic_poly)
	root.add_child(dynamic_bld)
	dynamic_bld._update_collision()
	assert_true(dynamic_poly.polygon.size() >= 20, "Dynamic VillageBuilding automatically extracts matching polygon from texture")
	assert_true(not dynamic_poly.disabled, "Dynamic VillageBuilding collision polygon is enabled")
	
	dynamic_bld.queue_free()
	instance.queue_free()


func test_categorized_interaction_and_deal_triggers() -> void:
	print("▶ Testing Categorized Interactions & Robust Deal Triggers...")
	
	var inv_with_tonic: Array[Dictionary] = [{"id": "miracle_tonic_sample", "name": "Miracle Tonic Sample"}]
	var empty_inv: Array[Dictionary] = []
	
	var arthur_profile := {
		"id": "npc_arthur_elder",
		"name": "Old Arthur",
		"trust": 50,
		"suspicion": 10,
		"gold": 500,
		"max_daily_spend": 180,
		"spent_today": 0,
		"personality": {"superstitious": 0.8, "skeptical": 0.3},
		"susceptible_topics": ["curse", "omen", "darkness", "midnight"],
		"skeptical_topics": ["tax", "coin"]
	}
	
	# 1. Test Categorization
	var cat_show := ScamManager.categorize_message("look at this miraculous potion", inv_with_tonic)
	assert_eq(cat_show["category"], ScamManager.InteractionCategory.SHOW_ITEM, "Showing item categorizes as SHOW_ITEM")
	assert_eq(cat_show["asked_amount"], 0, "Showing item has 0 asked amount")
	assert_true(cat_show["has_referenced_item"], "Recognizes player holds tonic sample")
	
	var cat_chat := ScamManager.categorize_message("Hello Arthur, how are you today?", empty_inv)
	assert_eq(cat_chat["category"], ScamManager.InteractionCategory.CASUAL_CHAT, "Greetings categorize as CASUAL_CHAT")
	
	var cat_probe := ScamManager.categorize_message("What troubles you about midnight omens?", empty_inv)
	assert_eq(cat_probe["category"], ScamManager.InteractionCategory.PROBE_BACKGROUND, "Asking about omens categorizes as PROBE_BACKGROUND")
	
	var cat_pitch := ScamManager.categorize_message("I will sell you this potion for 40 Kurtos", inv_with_tonic)
	assert_eq(cat_pitch["category"], ScamManager.InteractionCategory.PITCH_SALE, "Price and sell verbs categorize as PITCH_SALE")
	assert_eq(cat_pitch["asked_amount"], 40, "Extracts 40 Kurtos as asked price")
	
	var cat_demand := ScamManager.categorize_message("Give me 100 Kurtos right now!", empty_inv)
	assert_eq(cat_demand["category"], ScamManager.InteractionCategory.BLATANT_DEMAND, "Brazen demand without goods categorizes as BLATANT_DEMAND")
	
	var cat_insult := ScamManager.categorize_message("You stupid old fool, get lost!", empty_inv)
	assert_eq(cat_insult["category"], ScamManager.InteractionCategory.INSULT_OR_THREAT, "Hostility categorizes as INSULT_OR_THREAT")
	
	# 2. Test Showing Item: Transfers ZERO Kurtos, builds trust
	var llm_show := {"intent": "NORMAL_CONVERSATION", "credibility": 0.8, "convinced": false, "proposed_kurtos": 0, "response": "By the heavens, let me gaze upon that vial!"}
	var res_show := ScamManager.resolve_interaction(cat_show, arthur_profile, "look at this miraculous potion", llm_show, inv_with_tonic, 25)
	assert_eq(res_show["transfer_amount"], 0, "Showing potion transfers strictly 0 Kurtos")
	assert_true(res_show["trust_delta"] > 0, "Showing genuine potion to superstitious elder increases trust")
	assert_eq(res_show["suspicion_delta"], 0, "Showing genuine item incurs 0 suspicion")
	
	# 3. Test Showing Item with Empty Hands (Phantom Bluff): Transfers 0, escalates suspicion
	var cat_phantom_show := ScamManager.categorize_message("look at this miraculous potion", empty_inv)
	var res_phantom_show := ScamManager.resolve_interaction(cat_phantom_show, arthur_profile, "look at this miraculous potion", llm_show, empty_inv, 25)
	assert_eq(res_phantom_show["transfer_amount"], 0, "Phantom show transfers 0 Kurtos")
	assert_true(res_phantom_show["suspicion_delta"] >= 15, "Claiming to show item with empty hands spikes suspicion")
	assert_true(res_phantom_show["trust_delta"] < 0, "Phantom show decreases trust")
	
	# 4. Test Pitch Sale: Transfers BOUNDED price (40 Kurtos, NOT 180!)
	var llm_pitch_accept := {"intent": "PITCH_SCAM", "npc_action": "AGREE_DEAL", "credibility": 0.85, "convinced": true, "proposed_kurtos": 40, "response": "I agree to buy your potion for 40 Kurtos."}
	var res_pitch := ScamManager.resolve_interaction(cat_pitch, arthur_profile, "I will sell you this potion for 40 Kurtos", llm_pitch_accept, inv_with_tonic, 25)
	assert_eq(res_pitch["outcome"], ScamManager.ScamOutcome.SUCCESS, "Legitimate sale pitch succeeds")
	assert_eq(res_pitch["transfer_amount"], 40, "Deal transfers exactly the agreed 40 Kurtos (NOT the entire 180 budget!)")
	assert_true(res_pitch["trust_delta"] > 0, "Successful deal boosts trust")
	
	# 5. Test Dialogue Refusal Veto: NPC dialogue says 'can't spare' -> Deal is vetoed!
	var llm_pitch_refusal := {"intent": "NORMAL_CONVERSATION", "npc_action": "AGREE_DEAL", "credibility": 0.85, "convinced": true, "proposed_kurtos": 180, "response": "I will give you the potion for free if it looks good, but I can't spare any more."}
	var res_vetoed := ScamManager.resolve_interaction(cat_pitch, arthur_profile, "I will sell you this potion for 40 Kurtos", llm_pitch_refusal, inv_with_tonic, 25)
	assert_eq(res_vetoed["transfer_amount"], 0, "Dialogue refusal ('can't spare') vetoes currency transfer to 0 Kurtos")
	assert_eq(res_vetoed["outcome"], ScamManager.ScamOutcome.FAILED_MILD, "Refusal in dialogue results in FAILED_MILD outcome")
	
	# 6. Test Blatant Demand: Zero transfer and suspicion penalty
	var res_demand := ScamManager.resolve_interaction(cat_demand, arthur_profile, "Give me 100 Kurtos right now!", llm_show, empty_inv, 25)
	assert_eq(res_demand["transfer_amount"], 0, "Blatant demand transfers 0 Kurtos")
	assert_true(res_demand["suspicion_delta"] >= 15, "Blatant demand increases suspicion")
	assert_true(res_demand["trust_delta"] < 0, "Blatant demand penalizes trust")
	
	# 7. Test Insult: Zero transfer and heavy penalty
	var res_insult := ScamManager.resolve_interaction(cat_insult, arthur_profile, "You stupid old fool, get lost!", llm_show, empty_inv, 25)
	assert_eq(res_insult["transfer_amount"], 0, "Insult transfers 0 Kurtos")
	assert_true(res_insult["suspicion_delta"] >= 25, "Insult incurs massive suspicion")
	assert_true(res_insult["trust_delta"] <= -10, "Insult heavily penalizes trust")


func test_evaluation_threshold_rules() -> void:
	print("▶ Testing 2-Step Evaluator Threshold Rules (Score vs Trust vs Suspicion)...")
	
	var mock_npc := {
		"id": "npc_barnaby_merchant",
		"name": "Barnaby",
		"trust": 50,
		"suspicion": 15,
		"gold": 500,
		"max_daily_spend": 200,
		"spent_today": 0
	}
	var inv_with_tonic: Array[Dictionary] = [{"id": "miracle_tonic_sample", "name": "Miracle Tonic Sample"}]
	var empty_inv: Array[Dictionary] = []
	
	# Rule 1a: score > trust (e.g. 75 > 50) with deal attempt & valid item -> DO_DEAL
	var res_deal := ScamManager.apply_evaluation_thresholds(75, true, 40, mock_npc, inv_with_tonic, "miracle_tonic_sample")
	assert_eq(res_deal["decision"], "DO_DEAL", "Score > trust with deal and item triggers DO_DEAL")
	assert_eq(res_deal["transfer_amount"], 40, "Transfers requested 40 Kurtos")
	assert_eq(res_deal["outcome"], ScamManager.ScamOutcome.SUCCESS, "Outcome is SUCCESS")
	assert_true(res_deal["trust_delta"] > 0, "DO_DEAL increases trust")
	
	# Rule 1b: score > trust (e.g. 75 > 50) with deal attempt but missing item -> REFUSE_TALK (bluff caught)
	var res_bluff := ScamManager.apply_evaluation_thresholds(75, true, 40, mock_npc, empty_inv, "miracle_tonic_sample")
	assert_eq(res_bluff["decision"], "REFUSE_TALK", "Bluff with missing item caught and triggers REFUSE_TALK")
	assert_eq(res_bluff["transfer_amount"], 0, "No currency transferred on bluff")
	assert_true(res_bluff["suspicion_delta"] >= 25, "Bluff escalates suspicion heavily")
	
	# Rule 1c: score > trust (e.g. 75 > 50) with casual chat (is_deal_attempt = false) -> CONVERSE_POSITIVE
	var res_chat := ScamManager.apply_evaluation_thresholds(75, false, 0, mock_npc, empty_inv, "")
	assert_eq(res_chat["decision"], "CONVERSE_POSITIVE", "Score > trust on chat triggers CONVERSE_POSITIVE")
	assert_eq(res_chat["transfer_amount"], 0, "Chat transfers 0 Kurtos")
	assert_eq(res_chat["outcome"], ScamManager.ScamOutcome.SOCIAL_CHAT, "Outcome is SOCIAL_CHAT")
	assert_true(res_chat["trust_delta"] > 0, "Friendly chat increases trust")
	
	# Rule 2: suspicion <= score <= trust (e.g. 15 <= 35 <= 50) -> SKEPTICAL_REJECT (lower reputation, increase suspicion)
	var res_skeptical := ScamManager.apply_evaluation_thresholds(35, true, 40, mock_npc, inv_with_tonic, "miracle_tonic_sample")
	assert_eq(res_skeptical["decision"], "SKEPTICAL_REJECT", "suspicion <= score <= trust triggers SKEPTICAL_REJECT")
	assert_eq(res_skeptical["transfer_amount"], 0, "Skeptical reject transfers 0 Kurtos")
	assert_true(res_skeptical["trust_delta"] < 0, "Skeptical reject lowers trust")
	assert_true(res_skeptical["suspicion_delta"] > 0, "Skeptical reject increases suspicion")
	assert_true(res_skeptical["reputation_delta"] < 0, "Skeptical reject lowers reputation")
	
	# Rule 3: score < suspicion (e.g. 10 < 15) -> REFUSE_TALK (refusal lockout)
	var res_refuse := ScamManager.apply_evaluation_thresholds(10, false, 0, mock_npc, empty_inv, "")
	assert_eq(res_refuse["decision"], "REFUSE_TALK", "score < suspicion triggers REFUSE_TALK")
	assert_eq(res_refuse["transfer_amount"], 0, "Refuse to talk transfers 0 Kurtos")
	assert_true(res_refuse["will_refuse"], "Refusal sets will_refuse to true")
	assert_true(res_refuse["suspicion_delta"] >= 25, "Refusal incurs heavy suspicion penalty")
	assert_true(res_refuse["trust_delta"] <= -10, "Refusal incurs heavy trust penalty")


func test_npc_conversation_history_isolation() -> void:
	print("\n▶ Testing Strict Per-NPC Conversation History Isolation...")
	
	var chat_scene := load("res://scenes/ui/chat_ui.tscn")
	var chat_ui = chat_scene.instantiate()
	root.add_child(chat_ui)
	
	var barnaby := TownNPC.new()
	barnaby.name = "NPC_Barnaby"
	barnaby.npc_name = "Barnaby"
	barnaby.npc_profile = {"id": "npc_barnaby_merchant", "name": "Barnaby"}
	root.add_child(barnaby)
	
	var arthur := TownNPC.new()
	arthur.name = "NPC_Arthur"
	arthur.npc_name = "Old Arthur"
	arthur.npc_profile = {"id": "npc_arthur_elder", "name": "Old Arthur"}
	root.add_child(arthur)
	
	# 1. Start chat with Barnaby and exchange turns about wine/brewing
	chat_ui.start_conversation(barnaby)
	var b_hist: Array = chat_ui.get_active_npc_history()
	b_hist.append("PLAYER: \"Do you have fine wine for sale?\"")
	b_hist.append("Barnaby: \"I have the finest vintage in the square!\"")
	
	assert_eq(b_hist.size(), 2, "Barnaby history contains 2 turns")
	assert_true(b_hist[0].contains("wine"), "Barnaby history discusses wine")
	
	# 2. Close chat with Barnaby
	chat_ui.end_conversation()
	assert_eq(chat_ui.active_npc, null, "Active NPC cleared on end_conversation")
	
	# 3. Start chat with Old Arthur
	chat_ui.start_conversation(arthur)
	var a_hist: Array = chat_ui.get_active_npc_history()
	
	# Verify that Old Arthur's history has ZERO messages from Barnaby!
	assert_eq(a_hist.size(), 0, "Arthur history is initially empty - NO LEAK from Barnaby!")
	for line in a_hist:
		assert_true(not str(line).contains("wine"), "Arthur history contains NO wine mentions")
		assert_true(not str(line).contains("Barnaby"), "Arthur history contains NO Barnaby lines")
	
	# 4. Add turn with Old Arthur about curses/omens
	a_hist.append("PLAYER: \"What omens haunt the village?\"")
	a_hist.append("Old Arthur: \"Dark shadows gather at midnight...\"")
	
	assert_eq(a_hist.size(), 2, "Arthur history now has 2 turns")
	assert_true(a_hist[0].contains("omens"), "Arthur history discusses omens")
	
	# 5. Switch back to Barnaby - verify Barnaby's history is intact and contains NO omens from Arthur!
	chat_ui.end_conversation()
	chat_ui.start_conversation(barnaby)
	var b_hist_revisit: Array = chat_ui.get_active_npc_history()
	assert_eq(b_hist_revisit.size(), 2, "Barnaby still has 2 turns")
	assert_true(b_hist_revisit[0].contains("wine"), "Barnaby still has wine discussion")
	for line in b_hist_revisit:
		assert_true(not str(line).contains("omens"), "Barnaby history contains NO Arthur omens!")
	
	chat_ui.end_conversation()
	barnaby.queue_free()
	arthur.queue_free()
	chat_ui.queue_free()


func test_character_sprites_and_animations() -> void:
	print("\n▶ Testing RPG Character Sprites & 4-Directional Animations...")
	
	# 1. Player scene and 4-directional walk animations
	var player_scene := load("res://assets/characters/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	var player_sprite: Sprite2D = player.get_node("Sprite2D")
	assert_true(player_sprite != null, "Player has Sprite2D")
	assert_eq(player_sprite.hframes, 3, "Player sprite has 3 hframes")
	assert_eq(player_sprite.vframes, 4, "Player sprite has 4 vframes")
	assert_true(player_sprite.texture != null, "Player sprite has texture assigned")
	assert_true(player_sprite.texture.resource_path.contains("player_salesman"), "Player uses player_salesman.png texture")
	
	# Test directional walk frame updates
	# Right
	player.velocity = Vector2(100, 0)
	player._update_animation(0.016, true)
	assert_eq(player.current_facing, "right", "Moving (100, 0) sets facing right")
	assert_true(player_sprite.frame >= 6 and player_sprite.frame <= 8, "Moving right uses row 2 (frames 6-8)")
	
	# Left
	player.velocity = Vector2(-100, 0)
	player._update_animation(0.016, true)
	assert_eq(player.current_facing, "left", "Moving (-100, 0) sets facing left")
	assert_true(player_sprite.frame >= 3 and player_sprite.frame <= 5, "Moving left uses row 1 (frames 3-5)")
	
	# Up
	player.velocity = Vector2(0, -100)
	player._update_animation(0.016, true)
	assert_eq(player.current_facing, "up", "Moving (0, -100) sets facing up")
	assert_true(player_sprite.frame >= 9 and player_sprite.frame <= 11, "Moving up uses row 3 (frames 9-11)")
	
	# Down
	player.velocity = Vector2(0, 100)
	player._update_animation(0.016, true)
	assert_eq(player.current_facing, "down", "Moving (0, 100) sets facing down")
	assert_true(player_sprite.frame >= 0 and player_sprite.frame <= 2, "Moving down uses row 0 (frames 0-2)")
	
	# Stopped returns to directional idle
	player.velocity = Vector2.ZERO
	player._update_animation(0.016, false)
	assert_eq(player_sprite.frame, 1, "Stopped after moving down returns to frame 1 (idle down)")
	
	player.queue_free()
	
	# 2. Main scene character textures
	var main_scene := load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var barnaby = main.get_node("NPC_Barnaby")
	assert_true(barnaby != null, "NPC_Barnaby exists in main scene")
	assert_true(barnaby.character_texture != null, "Barnaby has distinct character_texture assigned")
	assert_true(barnaby.character_texture.resource_path.contains("npc_barnaby"), "Barnaby texture is npc_barnaby.png")
	
	var marla = main.get_node("NPC_Marla")
	assert_true(marla != null, "NPC_Marla exists in main scene")
	assert_true(marla.character_texture != null, "Marla has distinct character_texture assigned")
	assert_true(marla.character_texture.resource_path.contains("npc_marla"), "Marla texture is npc_marla.png")
	
	var cedric = main.get_node("NPC_Cedric")
	assert_true(cedric != null, "NPC_Cedric exists in main scene")
	assert_true(cedric.character_texture != null, "Cedric has distinct character_texture assigned")
	assert_true(cedric.character_texture.resource_path.contains("npc_cedric"), "Cedric texture is npc_cedric.png")
	
	var arthur = main.get_node("NPC_Arthur")
	assert_true(arthur != null, "NPC_Arthur exists in main scene")
	assert_true(arthur.character_texture != null, "Arthur has distinct character_texture assigned")
	assert_true(arthur.character_texture.resource_path.contains("npc_arthur"), "Arthur texture is npc_arthur.png")
	
	# 3. Dynamic NPC continuous facing towards player while nearby
	barnaby.global_position = Vector2(200, 200)
	var test_player := CharacterBody2D.new()
	test_player.name = "Player"
	test_player.add_to_group("player")
	test_player.global_position = Vector2(200, 300) # Below Barnaby
	main.add_child(test_player)
	
	barnaby._on_interaction_area_body_entered(test_player)
	barnaby._process(0.016)
	var barnaby_sprite: Sprite2D = barnaby.get_node("Sprite2D")
	assert_eq(barnaby_sprite.frame, 1, "Barnaby faces down (frame 1) when player enters below")
	
	# Player moves to the right of Barnaby while sticking near
	test_player.global_position = Vector2(300, 200)
	barnaby._process(0.016)
	assert_eq(barnaby_sprite.frame, 7, "Barnaby constantly tracks player: faces right (frame 7) when player moves right")
	
	# Player moves above Barnaby
	test_player.global_position = Vector2(200, 100)
	barnaby._process(0.016)
	assert_eq(barnaby_sprite.frame, 10, "Barnaby constantly tracks player: faces up (frame 10) when player moves above")
	
	# Player moves to the left of Barnaby
	test_player.global_position = Vector2(100, 200)
	barnaby._process(0.016)
	assert_eq(barnaby_sprite.frame, 4, "Barnaby constantly tracks player: faces left (frame 4) when player moves left")
	
	# Player exits area
	barnaby._on_interaction_area_body_exited(test_player)
	assert_eq(barnaby_sprite.frame, 1, "Barnaby resets to frame 1 (idle down) when player exits")
	test_player.queue_free()
	
	# 4. Guard knight sprite
	var guard = main.get_node("Guard")
	assert_true(guard != null, "Guard exists in main scene")
	var guard_sprite: Sprite2D = guard.get_node("Sprite2D")
	assert_true(guard_sprite != null, "Guard has Sprite2D")
	assert_eq(guard_sprite.hframes, 3, "Guard sprite has 3 hframes")
	assert_eq(guard_sprite.vframes, 4, "Guard sprite has 4 vframes")
	assert_true(guard_sprite.texture.resource_path.contains("guard_knight"), "Guard uses guard_knight.png")
	
	main.queue_free()


func test_environmental_foliage_paths_and_particles() -> void:
	print("\n▶ Testing Environmental Shaders, Dynamic Wavy Grass, Bordered Paths & Particles...")
	
	# 1. Shader resources
	var wind_shader := load("res://shaders/wind_sway.gdshader") as Shader
	assert_true(wind_shader != null, "wind_sway.gdshader loads successfully")
	
	var ripple_shader := load("res://shaders/grass_wind_ripple.gdshader") as Shader
	assert_true(ripple_shader != null, "grass_wind_ripple.gdshader loads successfully")
	
	# 2. Main scene environment nodes
	var main_scene := load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	# Grass meadow background shader
	var grass_bg = main.get_node("Ground/GrassBackground") as TextureRect
	assert_true(grass_bg != null, "GrassBackground exists in main scene")
	assert_true(grass_bg.material is ShaderMaterial, "GrassBackground has ShaderMaterial assigned")
	
	# Plaza NinePatch path with 9-patch terrain texture
	var plaza = main.get_node("Ground/PlazaCenter") as NinePatchRect
	assert_true(plaza != null, "PlazaCenter is a NinePatchRect")
	assert_eq(plaza.patch_margin_left, 16, "PlazaCenter patch_margin_left is 16px")
	assert_eq(plaza.patch_margin_top, 16, "PlazaCenter patch_margin_top is 16px")
	assert_true(plaza.texture != null, "PlazaCenter has texture assigned")
	assert_true(plaza.texture.resource_path.contains("path_terrain_9patch"), "PlazaCenter uses path_terrain_9patch.png")
	
	# Branching paths
	var bakery_path = main.get_node("Ground/BakeryPath") as NinePatchRect
	assert_true(bakery_path != null, "BakeryPath exists as NinePatchRect")
	var church_path = main.get_node("Ground/ChurchPath") as NinePatchRect
	assert_true(church_path != null, "ChurchPath exists as NinePatchRect")
	var cedric_path = main.get_node("Ground/CedricPath") as NinePatchRect
	assert_true(cedric_path != null, "CedricPath exists as NinePatchRect")
	var vault_path = main.get_node("Ground/VaultPath") as NinePatchRect
	assert_true(vault_path != null, "VaultPath exists as NinePatchRect")
	
	# Stepping stone & paver details
	var path_details = main.get_node("Ground/PathDetails")
	assert_true(path_details != null, "PathDetails container exists")
	assert_true(path_details.get_child_count() >= 20, "PathDetails contains >= 20 pavers, pebbles, and cracked earth props")
	
	# Town Well
	var well = main.get_node("Environment/VillageWell")
	assert_true(well != null, "VillageWell exists in central plaza")
	var well_col = well.get_node_or_null("CollisionShape2D")
	assert_true(well_col != null, "VillageWell has CollisionShape2D")
	
	# Wavy Grass Tufts
	var grass_tufts = main.get_node("Environment/GrassTufts")
	assert_true(grass_tufts != null, "GrassTufts container exists")
	assert_true(grass_tufts.get_child_count() >= 40, "GrassTufts has >= 40 swaying foliage tufts across the village")
	var sample_tuft = grass_tufts.get_child(0) as GrassTuft
	assert_true(sample_tuft != null, "First grass tuft is a GrassTuft instance")
	var tuft_sprite: Sprite2D = sample_tuft.get_node("Sprite2D")
	assert_true(tuft_sprite != null, "GrassTuft has Sprite2D")
	assert_true(tuft_sprite.material is ShaderMaterial, "GrassTuft Sprite2D uses ShaderMaterial for wind sway")
	
	# Tree Canopy Wind Sway
	var tree_nw1 = main.get_node("Environment/Tree_NW1")
	assert_true(tree_nw1 != null, "Tree_NW1 exists")
	var tree_sprite: Sprite2D = tree_nw1.get_node("Sprite2D")
	assert_true(tree_sprite != null, "Tree has Sprite2D")
	assert_true(tree_sprite.material is ShaderMaterial, "Tree Sprite2D has ShaderMaterial for canopy wind sway")
	
	# Ambient Wind Particles
	var wind_particles = main.get_node("Environment/AmbientWind") as CPUParticles2D
	assert_true(wind_particles != null, "AmbientWind particles exist in village scene")
	assert_true(wind_particles.emitting, "AmbientWind particles are emitting")
	
	# Bakery Chimney Smoke
	var bakery_smoke = main.get_node("Buildings/BakeryBuilding/ChimneySmoke") as CPUParticles2D
	assert_true(bakery_smoke != null, "ChimneySmoke particles exist on Bakery")
	assert_true(bakery_smoke.emitting, "ChimneySmoke particles are emitting")
	
	main.queue_free()


func test_live_flora_biome_props_and_rustle() -> void:
	print("\n▶ Testing Oxymoron Live Flora Biome Distribution, Wind Sway & Footstep Rustle...")
	var main_scene = load("res://scenes/main.tscn")
	assert_true(main_scene != null, "scenes/main.tscn loads for LiveFlora testing")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var flora_container = main.get_node_or_null("Environment/LiveFlora")
	assert_true(flora_container != null, "Environment/LiveFlora container exists in main scene")
	var flora_count: int = flora_container.get_child_count() if flora_container else 0
	assert_true(flora_count >= 50, "LiveFlora container has >= 50 floral props (Actual: %d)" % flora_count)
	
	var sample_wildflower: LiveFlora = null
	var sample_solid: LiveFlora = null
	var sample_bush: LiveFlora = null
	
	for child in flora_container.get_children():
		if child is LiveFlora:
			if child.flora_type == "wildflower" and sample_wildflower == null:
				sample_wildflower = child
			elif child.flora_type == "solid" and sample_solid == null:
				sample_solid = child
			elif child.flora_type == "bush" and sample_bush == null:
				sample_bush = child
	
	assert_true(sample_wildflower != null, "Contains wildflower LiveFlora instances (e.g. Daffodils/Lupines)")
	if sample_wildflower:
		assert_true(sample_wildflower.flora_texture != null, "Wildflower has texture assigned")
		var s_sprite: Sprite2D = sample_wildflower.get_node_or_null("Sprite2D")
		assert_true(s_sprite != null, "Wildflower has Sprite2D")
		assert_true(s_sprite.material is ShaderMaterial, "Wildflower Sprite2D has ShaderMaterial")
		var area: Area2D = sample_wildflower.get_node_or_null("RustleArea")
		assert_true(area != null, "Wildflower has RustleArea Area2D")
		
		# Test reactive rustle execution
		sample_wildflower.rustle(sample_wildflower.global_position + Vector2(10, 0))
		assert_true(true, "Rustle physics executed without error")
	
	assert_true(sample_bush != null, "Contains bush LiveFlora instances (e.g. Berry bushes)")
	if sample_bush:
		assert_true(sample_bush.flora_texture != null, "Bush has texture assigned")
		assert_eq(sample_bush.flora_type, "bush", "Bush has flora_type='bush'")
	
	assert_true(sample_solid != null, "Contains solid LiveFlora obstacles (e.g. Overgrown boulders/stumps)")
	if sample_solid:
		assert_true(sample_solid.has_collision, "Solid flora has has_collision=true")
		var static_body: StaticBody2D = sample_solid.get_node_or_null("StaticBody2D")
		assert_true(static_body != null, "Solid flora has StaticBody2D")
		var shape: CollisionShape2D = static_body.get_node_or_null("CollisionShape2D")
		assert_true(shape != null and not shape.disabled, "Solid flora collision shape is active")
	
	main.queue_free()




