class_name GameStateManager
extends Node

## Central authoritative GameState for Snake Oil Salesman.
## Tracks player currency, 30-day timeline, overall reputation, and inventory items.

signal kurtos_changed(new_amount: int, delta: int)
signal day_changed(new_day: int)
signal overall_trust_changed(new_value: int, delta: int)
signal item_added(item: Dictionary)
signal game_ended(won: bool, message: String)

@export var player_kurtos: int = 50
@export var goal_kurtos: int = 1_000_000
@export var current_day: int = 1
@export var max_days: int = 30
@export var overall_trust: int = 25 # 0 to 100
@export var can_player_move: bool = true

var inventory: Array[Dictionary] = []
var is_game_over: bool = false
var has_won: bool = false

const ITEMS: Dictionary = {
	"miracle_tonic_sample": {"name": "Miracle Tonic", "region": Rect2(0, 0, 32, 32), "rarity": "Common", "desc": "A sugary concoction praised in every marketplace and trusted in none.", "effect": "trust_up", "effect_val": 7, "duration": 0, "consumable": true},
	"coin_purse": {"name": "Coin Purse", "region": Rect2(32, 0, 32, 32), "rarity": "Legendary", "desc": "Heavy enough to impress, light enough to be a disappointment.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"beggars_robe": {"name": "Beggar's Robe", "region": Rect2(64, 0, 32, 32), "rarity": "Common", "desc": "Smells faintly of desperation and perfectly crafted pity.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"monocle": {"name": "Gentleman's Monocle", "region": Rect2(96, 0, 32, 32), "rarity": "Common", "desc": "Worn by men who value appearances far more than honesty.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"fabric_sample": {"name": "Vibrant Silk Swatch", "region": Rect2(128, 0, 32, 32), "rarity": "Common", "desc": "Bright enough to impress nobles and distract fools from the price.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"prism_of_persuasion": {"name": "Prism of Persuasion", "region": Rect2(160, 0, 32, 32), "rarity": "Epic", "desc": "Fractures light in a way that makes bad deals look brilliant.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"frostglass_elixir": {"name": "Frostglass Elixir", "region": Rect2(192, 0, 32, 32), "rarity": "Epic", "desc": "Cold to the touch, and even colder on the poor buyer's stomach.", "effect": "trust_up", "effect_val": 5, "duration": 0, "consumable": true},
	"moonfrost_orb": {"name": "Moonfrost Orb", "region": Rect2(224, 0, 32, 32), "rarity": "Uncommon", "desc": "Glows with the eerie luminescence of a hundred false promises.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"wax-sealed_letter": {"name": "Wax-Sealed Letter", "region": Rect2(256, 0, 32, 32), "rarity": "Rare", "desc": "An authentic forgery guaranteeing entry to exclusive nowhere.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"herbal_remedy": {"name": "Herbal Remedy", "region": Rect2(288, 0, 32, 32), "rarity": "Rare", "desc": "A pungent mix of weeds that cures everything except gullibility.", "effect": "trust_up", "effect_val": 10, "duration": 0, "consumable": true},
	"verdant_draught": {"name": "Verdant Draught", "region": Rect2(0, 32, 32, 32), "rarity": "Common", "desc": "Looks like pond water, tastes like pond water. Sold as a miracle.", "effect": "trust_up", "effect_val": 12, "duration": 0, "consumable": true},
	"sunbrew_elixir": {"name": "Sunbrew Elixir", "region": Rect2(32, 32, 32, 32), "rarity": "Rare", "desc": "Warm and golden. Mostly honey, water, and theatrical lighting.", "effect": "trust_up", "effect_val": 13, "duration": 0, "consumable": true},
	"merchants_ledger": {"name": "Merchant's Ledger", "region": Rect2(64, 32, 32, 32), "rarity": "Epic", "desc": "Contains two sets of numbers: the real ones, and the ones for the guard.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"whispering_grimoire": {"name": "Whispering Grimoire", "region": Rect2(96, 32, 32, 32), "rarity": "Legendary", "desc": "A book of profound secrets, mostly detailing the best tavern deals.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"glacial_tear": {"name": "Glacial Tear", "region": Rect2(128, 32, 32, 32), "rarity": "Uncommon", "desc": "A perfectly shaped glass bead sold as the sorrow of a frost giant.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"duskring_signet": {"name": "Duskring Signet", "region": Rect2(160, 32, 32, 32), "rarity": "Rare", "desc": "Bears the crest of a noble house that conveniently went extinct yesterday.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"sunspire_medallion": {"name": "Sunspire Medallion", "region": Rect2(192, 32, 32, 32), "rarity": "Uncommon", "desc": "A gaudy trinket that commands respect from anyone with poor eyesight.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"brass_market_key": {"name": "Brass Market Key", "region": Rect2(224, 32, 32, 32), "rarity": "Legendary", "desc": "Opens exactly one lock, which was destroyed three centuries ago.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"sandglass_charm": {"name": "Sandglass Charm", "region": Rect2(256, 32, 32, 32), "rarity": "Rare", "desc": "Time waits for no man, but this charm makes them think it might.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"nightshade_vial": {"name": "Nightshade Vial", "region": Rect2(288, 32, 32, 32), "rarity": "Rare", "desc": "A deeply suspicious liquid. Best not ask where it was brewed.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"rosewax_candle": {"name": "Rosewax Candle", "region": Rect2(0, 64, 32, 32), "rarity": "Uncommon", "desc": "Burns with the sweet scent of plausible deniability.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"hollowskull_relic": {"name": "Hollowskull Relic", "region": Rect2(32, 64, 32, 32), "rarity": "Epic", "desc": "A sacred artifact, provided you don't look too closely at the papier-mâché.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"traders_bell": {"name": "Trader's Bell", "region": Rect2(64, 64, 32, 32), "rarity": "Epic", "desc": "Rings with a clear tone that signals another successful swindle.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"seers_orb": {"name": "Seer's Orb", "region": Rect2(96, 64, 32, 32), "rarity": "Common", "desc": "Gazes into a future where the buyer has significantly less money.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"writ_of_rumors": {"name": "Writ of Rumors", "region": Rect2(128, 64, 32, 32), "rarity": "Rare", "desc": "A highly official-looking document filled with absolute nonsense.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"silver_quill": {"name": "Silver Quill", "region": Rect2(160, 64, 32, 32), "rarity": "Legendary", "desc": "Writes beautiful lies that look remarkably like the truth.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"stormspark_phial": {"name": "Stormspark Phial", "region": Rect2(192, 64, 32, 32), "rarity": "Uncommon", "desc": "Contains genuine lightning! (Actually just a really angry firefly).", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"honeydrop_preserve": {"name": "Honeydrop Preserve", "region": Rect2(224, 64, 32, 32), "rarity": "Rare", "desc": "Sweet, sticky, and excellent for bribing minor officials.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"frostward_tablet": {"name": "Frostward Tablet", "region": Rect2(256, 64, 32, 32), "rarity": "Epic", "desc": "Carved with ancient runes that roughly translate to 'No Refunds'.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"mothwing_brooch": {"name": "Mothwing Brooch", "region": Rect2(288, 64, 32, 32), "rarity": "Uncommon", "desc": "Delicate, fragile, and guaranteed to break as soon as it's paid for.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"codex_of_rumors": {"name": "Codex of Rumors", "region": Rect2(0, 96, 32, 32), "rarity": "Uncommon", "desc": "An encyclopedia of blackmail, gossip, and highly profitable fabrications.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"sands_of_fortune": {"name": "Sands of Fortune", "region": Rect2(32, 96, 32, 32), "rarity": "Uncommon", "desc": "Ordinary beach sand, marketed as the dust of crushed shooting stars.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"midnight_ink": {"name": "Midnight Ink", "region": Rect2(64, 96, 32, 32), "rarity": "Common", "desc": "Perfect for writing contracts you intend to have disappear by morning.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"crimson_crook_key": {"name": "Crimson Crook Key", "region": Rect2(96, 96, 32, 32), "rarity": "Rare", "desc": "Unlocks the back door of a tavern that burned down last week.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"whisperdust_sachet": {"name": "Whisperdust Sachet", "region": Rect2(128, 96, 32, 32), "rarity": "Epic", "desc": "A pouch of sneezing powder sold as a mystical silencing agent.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"tidecaller_shell": {"name": "Tidecaller Shell", "region": Rect2(160, 96, 32, 32), "rarity": "Epic", "desc": "If you listen closely, you can hear the sound of a scam approaching.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"weathered_plank": {"name": "Weathered Plank", "region": Rect2(192, 96, 32, 32), "rarity": "Rare", "desc": "A piece of driftwood claimed to be from the King's first flagship.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"wayfinder_compass": {"name": "Wayfinder Compass", "region": Rect2(224, 96, 32, 32), "rarity": "Common", "desc": "Always points toward the nearest person with a loose purse string.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"dreamshade_tonic": {"name": "Dreamshade Tonic", "region": Rect2(256, 96, 32, 32), "rarity": "Rare", "desc": "Guarantees a good night's sleep, mostly due to the high alcohol content.", "effect": "trust_up", "effect_val": 7, "duration": 0, "consumable": true},
	"sunoil_flask": {"name": "Sunoil Flask", "region": Rect2(288, 96, 32, 32), "rarity": "Legendary", "desc": "A greasy ointment that makes everything slightly more slippery.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"goldleaf_elixir": {"name": "Goldleaf Elixir", "region": Rect2(0, 128, 32, 32), "rarity": "Epic", "desc": "Contains real gold flakes! Ignore the strange metallic aftertaste.", "effect": "trust_up", "effect_val": 13, "duration": 0, "consumable": true},
	"sealed_curio_parcel": {"name": "Sealed Curio Parcel", "region": Rect2(32, 128, 32, 32), "rarity": "Uncommon", "desc": "A mysterious box that loses all its value the moment you open it.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"skyglass_relic": {"name": "Skyglass Relic", "region": Rect2(64, 128, 32, 32), "rarity": "Common", "desc": "A chunk of blue glass sold as a fallen tear of the heavens.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"bitterbrew_cup": {"name": "Bitterbrew Cup", "region": Rect2(96, 128, 32, 32), "rarity": "Rare", "desc": "Makes any drink taste awful, ensuring nobody asks for a sip.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"amethyst_charm": {"name": "Amethyst Charm", "region": Rect2(128, 128, 32, 32), "rarity": "Rare", "desc": "A painted rock that supposedly wards off bad investments.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"sunwheel_sigil": {"name": "Sunwheel Sigil", "region": Rect2(160, 128, 32, 32), "rarity": "Epic", "desc": "An ancient emblem of power, currently on sale for half price.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"scarlet_hood": {"name": "Scarlet Hood", "region": Rect2(192, 128, 32, 32), "rarity": "Epic", "desc": "A bright cloak perfect for making a dramatic, highly visible exit.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"merchants_docket": {"name": "Merchant's Docket", "region": Rect2(224, 128, 32, 32), "rarity": "Uncommon", "desc": "A list of fake clients used to artificially inflate demand.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"scales_of_equilibrium": {"name": "Scales of Equilibrium", "region": Rect2(256, 128, 32, 32), "rarity": "Legendary", "desc": "Perfectly balanced, assuming you know which side is rigged.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
	"witchs_simmerpot": {"name": "Witch's Simmerpot", "region": Rect2(288, 128, 32, 32), "rarity": "Legendary", "desc": "Bubbles menacingly, but is mostly just used for brewing cheap tea.", "effect": "none", "effect_val": 0, "duration": 0, "consumable": false},
}

func get_item_icon(item_id: String) -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = load("res://assets/items/fantasy_inventory/FantasyInventorySpritesheet.png")
	if ITEMS.has(item_id):
		tex.region = ITEMS[item_id].region
	else:
		tex.region = Rect2(0, 0, 32, 32)
	return tex




func use_item(item_id: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			var item = inventory[i]
			if item.get("consumable", false):
				# Apply effect
				var eff = item.get("effect", "none")
				var val = item.get("effect_val", 0)
				if eff == "trust_up":
					modify_overall_trust(val)
				elif eff == "kurtos_up":
					add_kurtos(val)
				
				var qty = item.get("quantity", 1) - 1
				if qty <= 0:
					inventory.remove_at(i)
				else:
					item["quantity"] = qty
				emit_signal("item_added", item) # just to trigger ui refresh
				return true
	return false

func _ready() -> void:
	if OS.has_feature("debug"):
		for id in ITEMS.keys():
			var q = randi() % 10 + 1
			add_item(id, "", "", q, true)



func add_kurtos(amount: int) -> void:
	if amount <= 0:
		return
	player_kurtos += amount
	emit_signal("kurtos_changed", player_kurtos, amount)
	_check_win_condition()


func spend_kurtos(amount: int) -> bool:
	if amount <= 0:
		return false
	if player_kurtos >= amount:
		player_kurtos -= amount
		emit_signal("kurtos_changed", player_kurtos, -amount)
		return true
	return false


func modify_overall_trust(delta: int) -> void:
	var prev := overall_trust
	overall_trust = clampi(overall_trust + delta, 0, 100)
	if overall_trust != prev:
		emit_signal("overall_trust_changed", overall_trust, overall_trust - prev)


func advance_day() -> void:
	if is_game_over:
		return
	
	current_day += 1
	emit_signal("day_changed", current_day)
	
	# Notify all NPCs in the town about day rollover (resets daily spend & cools down anger)
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("on_day_rollover"):
			npc.on_day_rollover(current_day)
	
	# Check 30-day limit
	if current_day > max_days:
		_evaluate_ending()


func has_item(item_id: String) -> bool:
	for item in inventory:
		if item.get("id", "") == item_id and not item.get("is_debug", false):
			return true
	return false


func add_item(item_id: String, item_name: String = "", description: String = "", quantity: int = 1, is_debug: bool = false) -> void:
	for item in inventory:
		if item.get("id", "") == item_id:
			if ITEMS.has(item_id) and ITEMS[item_id].consumable:
				item["quantity"] = item.get("quantity", 1) + quantity
			if not is_debug and item.get("is_debug", false):
				item["is_debug"] = false
			emit_signal("item_added", item)
			return

	var item_dict := {
		"id": item_id,
		"name": item_name,
		"description": description,
		"quantity": quantity,
		"is_debug": is_debug
	}
	if ITEMS.has(item_id):
		item_dict["name"] = ITEMS[item_id].name
		item_dict["description"] = ITEMS[item_id].desc
		item_dict["rarity"] = ITEMS[item_id].rarity
		item_dict["effect"] = ITEMS[item_id].effect
		item_dict["effect_val"] = ITEMS[item_id].effect_val
		item_dict["duration"] = ITEMS[item_id].duration
		item_dict["consumable"] = ITEMS[item_id].consumable

	inventory.append(item_dict)
	emit_signal("item_added", item_dict)


func remove_item(item_id: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			inventory.remove_at(i)
			return true
	return false


func _check_win_condition() -> void:
	if player_kurtos >= goal_kurtos and not is_game_over:
		is_game_over = true
		has_won = true
		var msg := "You accumulated 1,000,000 Kurtos in %d days! You approach the King to claim the Princess's hand in marriage..." % current_day
		emit_signal("game_ended", true, msg)


func _evaluate_ending() -> void:
	is_game_over = true
	if player_kurtos >= goal_kurtos:
		has_won = true
		var msg := "Day 30 has arrived! You amassed %d Kurtos! The King summons you to court..." % player_kurtos
		emit_signal("game_ended", true, msg)
	else:
		has_won = false
		var msg := "Day 30 has elapsed. You only collected %d / %d Kurtos. The King's guards arrest you for being an impoverished pretender!" % [player_kurtos, goal_kurtos]
		emit_signal("game_ended", false, msg)


func reset_game() -> void:
	player_kurtos = 50
	current_day = 1
	overall_trust = 25
	is_game_over = false
	has_won = false
	inventory.clear()
	add_item("miracle_tonic_sample", "Miracle Tonic Sample", "A small bottle of colored sugar water.")
	emit_signal("kurtos_changed", player_kurtos, 0)
	emit_signal("day_changed", current_day)
	emit_signal("overall_trust_changed", overall_trust, 0)
