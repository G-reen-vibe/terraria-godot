extends Node2D

func _ready() -> void:
	print("=== TestBootstrap ===")
	print("GameManager time: ", GameManager.time_of_day)
	print("WorldData WORLD_WIDTH: ", WorldData.WORLD_WIDTH)
	print("ItemDB items count: ", ItemDB.ITEMS.size())
	print("RecipeDB recipes: ", RecipeDB.get_recipes().size())
	# Test recipe validation
	var bad_count := 0
	for r in RecipeDB.RECIPES:
		if typeof(r) != TYPE_DICTIONARY or not r.has("result") or not r.has("ingredients"):
			bad_count += 1
	print("Bad recipes in source: ", bad_count, " (should be 0)")
	# Test item lookup
	var wood := ItemDB.get_item("wood")
	print("Wood item: ", wood)
	# Test tile properties
	print("Dirt solid: ", WorldData.is_solid(WorldData.Tile.DIRT))
	print("Air solid: ", WorldData.is_solid(WorldData.Tile.AIR))
	# Test recipe crafting check
	var test_inv := [{"id": "wood", "count": 10}, null]
	var recipes := RecipeDB.get_available_recipes(test_inv, [])
	print("Available recipes with 10 wood, no station: ", recipes.size())
	for r in recipes:
		print("  - ", r.result, " x", r.count)
	print("=== TestBootstrap DONE ===")
	get_tree().quit()
