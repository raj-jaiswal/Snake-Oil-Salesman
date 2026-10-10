extends SceneTree

var passed = 0
var failed = 0

func _init():
	print("▶ Testing Title Screen & Save/Load functionality...")
	
	# Test Title Screen Node
	var title_scene = load("res://scenes/title_screen.tscn")
	var title = title_scene.instantiate()
	
	if title != null:
		print("  ✅ PASS: Title screen instantiated successfully")
		passed += 1
	else:
		print("  ❌ FAIL: Title screen failed to instantiate")
		failed += 1
		quit(1)
		return
		
	var start_btn = title.get_node_or_null("Buttons/StartBtn")
	var continue_btn = title.get_node_or_null("Buttons/ContinueBtn")
	var confirm_panel = title.get_node_or_null("ConfirmPanel")
	
	if start_btn:
		print("  ✅ PASS: Start button exists")
		passed += 1
	else:
		print("  ❌ FAIL: Start button missing")
		failed += 1
	
	# Test GameState has_save, load, save
	var gs = load("res://scripts/game_state.gd").new()
	gs.player_kurtos = 999
	gs.save_game()
	
	if gs.has_save():
		print("  ✅ PASS: Save game created successfully")
		passed += 1
	else:
		print("  ❌ FAIL: Save game creation failed")
		failed += 1
		
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.load_game()
	if gs2.player_kurtos == 999:
		print("  ✅ PASS: Game state loaded successfully")
		passed += 1
	else:
		print("  ❌ FAIL: Game state load mismatch")
		failed += 1
		
	# Clean up test save
	var dir = DirAccess.open("user://")
	if dir.file_exists("save_game.dat"):
		dir.remove("save_game.dat")
		
	print("-------------------------------------------------------")
	print("🏁 TEST RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("-------------------------------------------------------")
	
	if failed > 0:
		quit(1)
	else:
		quit(0)
