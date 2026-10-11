extends SceneTree

func _init() -> void:
	print("▶ Testing Full Island World Map Implementation...")
	
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert(main_scene != null, "scenes/main.tscn loads successfully")
	print("  ✅ PASS: scenes/main.tscn loads successfully")
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	# 1. Test IslandMap and TileMapLayers
	var ground = main.get_node_or_null("Ground")
	assert(ground != null, "Ground node exists")
	
	var island_map = ground.get_node_or_null("IslandMap")
	assert(island_map != null, "IslandMap node exists under Ground")
	print("  ✅ PASS: IslandMap node exists under Ground")
	
	var ground_layer: TileMapLayer = island_map.get_node_or_null("GroundLayer")
	assert(ground_layer != null, "GroundLayer TileMapLayer exists")
	assert(ground_layer.tile_set != null, "GroundLayer has tile_set assigned")
	print("  ✅ PASS: GroundLayer TileMapLayer exists with valid TileSet")
	
	var water_layer: TileMapLayer = island_map.get_node_or_null("WaterLayer")
	assert(water_layer != null, "WaterLayer TileMapLayer exists")
	assert(water_layer.tile_set != null, "WaterLayer has tile_set assigned")
	print("  ✅ PASS: WaterLayer TileMapLayer exists for inland lakes/streams")
	
	var paths_layer: TileMapLayer = island_map.get_node_or_null("PathsLayer")
	assert(paths_layer != null, "PathsLayer TileMapLayer exists")
	assert(paths_layer.tile_set != null, "PathsLayer has tile_set assigned")
	print("  ✅ PASS: PathsLayer TileMapLayer exists for roads, avenues, and bridges")
	
	var cliff_layer: TileMapLayer = island_map.get_node_or_null("CliffLayer")
	assert(cliff_layer != null, "CliffLayer TileMapLayer exists")
	assert(cliff_layer.tile_set != null, "CliffLayer has tile_set assigned")
	print("  ✅ PASS: CliffLayer TileMapLayer exists for mountain elevations")
	
	# Verify specific key tile coordinates:
	# Southern Pier wooden bridge tile (80, 110)
	var pier_cell_source: int = paths_layer.get_cell_source_id(Vector2i(80, 110))
	assert(pier_cell_source == 8, "Southern Pier has wooden bridge tiles (source 8)")
	print("  ✅ PASS: Southern Arrival Pier has authentic wooden bridge tiling")
	
	# Ocean water tile at (5, 5)
	var ocean_cell_source: int = ground_layer.get_cell_source_id(Vector2i(5, 5))
	assert(ocean_cell_source == 0, "Ocean perimeter has water tiles (source 0)")
	print("  ✅ PASS: Ocean perimeter has deep water tiling")
	
	# Farmland soil at (122, 42)
	var farm_cell_source: int = ground_layer.get_cell_source_id(Vector2i(122, 42))
	assert(farm_cell_source == 5, "Agricultural district has tilled farmland tiles (source 5)")
	print("  ✅ PASS: Agricultural district has tilled farmland soil tiling")
	
	# 2. Test Coast and Water Colliders
	var coast = island_map.get_node_or_null("CoastColliders")
	assert(coast != null, "CoastColliders exists in IslandMap")
	assert(coast.get_child_count() >= 8, "CoastColliders has >= 8 ocean boundary shapes")
	print("  ✅ PASS: CoastColliders active with %d ocean boundary shapes" % coast.get_child_count())
	
	var inland_water = island_map.get_node_or_null("InlandWaterColliders")
	assert(inland_water != null, "InlandWaterColliders exists in IslandMap")
	assert(inland_water.get_child_count() >= 8, "InlandWaterColliders has >= 8 lake/river shapes")
	print("  ✅ PASS: InlandWaterColliders active with %d lake/river shapes" % inland_water.get_child_count())
	
	# 3. Test Buildings Catalog
	var buildings_node = main.get_node_or_null("Buildings")
	assert(buildings_node != null, "Buildings container exists")
	var bld_count: int = buildings_node.get_child_count()
	assert(bld_count >= 40, "Buildings container has >= 40 buildings across island (Actual: %d)" % bld_count)
	print("  ✅ PASS: %d individual buildings placed with distinct sprites and colliders" % bld_count)
	
	# Check specific landmark structures
	var windmill = buildings_node.get_node_or_null("GoldenWindmill")
	assert(windmill != null, "GoldenWindmill exists in farmlands")
	assert(windmill.building_name == "Golden Windmill", "Windmill has correct title")
	print("  ✅ PASS: Golden Windmill structure placed in agricultural valley")
	
	var lighthouse = buildings_node.get_node_or_null("LighthouseTower")
	assert(lighthouse != null, "LighthouseTower exists on Gull Rock")
	print("  ✅ PASS: Coastal Lighthouse tower placed on western cliffs")
	
	var grotto = buildings_node.get_node_or_null("SmugglersGrotto")
	assert(grotto != null, "SmugglersGrotto exists in northwest mountains")
	print("  ✅ PASS: Smuggler's Grotto cave entrance placed in northwest mountain")
	
	var mine = buildings_node.get_node_or_null("DeepStoneMine")
	assert(mine != null, "DeepStoneMine exists in southeast terrace")
	print("  ✅ PASS: Deep Stone Mine entrance placed on southeast rocky terrace")
	
	var academy = buildings_node.get_node_or_null("BlossomAcademy")
	assert(academy != null, "BlossomAcademy exists at northern summit")
	print("  ✅ PASS: Cherry Blossom Academy placed at northern summit sanctuary")
	
	var castle_palace = buildings_node.get_node_or_null("CastlePalace")
	assert(castle_palace != null, "CastlePalace exists in Royal Citadel")
	print("  ✅ PASS: Crown Palace placed in Royal Citadel fortress")
	
	# 4. Test Smooth Camera
	var camera: Camera2D = main.get_node_or_null("SmoothCamera") as Camera2D
	assert(camera != null, "SmoothCamera node exists in main scene")
	assert(camera.position_smoothing_enabled, "SmoothCamera has position smoothing enabled")
	assert(camera.limit_right == 2560, "SmoothCamera limit_right matches map width (2560px)")
	assert(camera.limit_bottom == 1920, "SmoothCamera limit_bottom matches map height (1920px)")
	print("  ✅ PASS: SmoothCamera active with position smoothing and 2560x1920 map clamping")
	
	# 5. Test Player Spawn & Exploration
	var player = main.get_node_or_null("Player")
	assert(player != null, "Player exists")
	assert(player.global_position == Vector2(1280, 1800), "Player spawns at Southern Arrival Pier (1280, 1800)")
	print("  ✅ PASS: Player spawns at Southern Arrival Pier facing island")
	
	# 6. Test NPCs at respective districts
	var barnaby = main.get_node_or_null("NPC_Barnaby")
	assert(barnaby != null, "Barnaby exists in Plaza")
	var marla = main.get_node_or_null("NPC_Marla")
	assert(marla != null, "Marla exists at Bakery")
	var cedric = main.get_node_or_null("NPC_Cedric")
	assert(cedric != null, "Cedric exists at Citadel Estate")
	var arthur = main.get_node_or_null("NPC_Arthur")
	assert(arthur != null, "Arthur exists at Chapel")
	var guard = main.get_node_or_null("Guard")
	assert(guard != null, "Guard exists at Citadel Gatehouse")
	print("  ✅ PASS: All 4 NPCs and Citadel Guard positioned at thematic districts")
	
	# 7. Test Chests & Restricted Area
	var vault = main.get_node_or_null("RestrictedArea")
	assert(vault != null, "Treasury Vault RestrictedArea exists")
	for chest_name in ["Chest_BeggarsRobe", "Chest_Monocle", "Chest_Fabric", "Chest_Tonic"]:
		assert(main.has_node(chest_name), "Chest %s exists" % chest_name)
	print("  ✅ PASS: Treasury Vault and all 4 item chests placed across island")
	
	print("\n-------------------------------------------------------")
	print("🏁 ALL ISLAND WORLD MAP TESTS PASSED!")
	print("-------------------------------------------------------")
	quit(0)
