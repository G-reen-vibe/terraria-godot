extends Node
## RecipeDB autoload - registry of all crafting recipes

# Each recipe: {result_id, result_count, ingredients: [{id, count}], requires: [] (station tiles)}
const RECIPES := [
        # Basic tools - no station needed
        {"result": "wood_pickaxe", "count": 1, "ingredients": [{"id": "wood", "count": 3}], "requires": []},
        {"result": "wood_axe", "count": 1, "ingredients": [{"id": "wood", "count": 3}], "requires": []},
        {"result": "wood_sword", "count": 1, "ingredients": [{"id": "wood", "count": 4}], "requires": []},
        {"result": "wood_bow", "count": 1, "ingredients": [{"id": "wood", "count": 5}], "requires": []},
        {"result": "torch", "count": 4, "ingredients": [{"id": "wood", "count": 1}, {"id": "gel", "count": 1}], "requires": []},
        {"result": "wood_platform", "count": 2, "ingredients": [{"id": "wood", "count": 1}], "requires": []},
        
        # Workbench recipes (require workbench nearby)
        {"result": "workbench", "count": 1, "ingredients": [{"id": "wood", "count": 10}], "requires": []},
        {"result": "chest", "count": 1, "ingredients": [{"id": "wood", "count": 8}, {"id": "iron_bar", "count": 2}], "requires": []},
        {"result": "wood_arrow", "count": 5, "ingredients": [{"id": "wood", "count": 1}], "requires": ["workbench"]},
        
        # Copper tools - need workbench
        {"result": "copper_pickaxe", "count": 1, "ingredients": [{"id": "copper_bar", "count": 5}, {"id": "wood", "count": 2}], "requires": ["workbench"]},
        {"result": "copper_axe", "count": 1, "ingredients": [{"id": "copper_bar", "count": 4}, {"id": "wood", "count": 2}], "requires": ["workbench"]},
        {"result": "copper_sword", "count": 1, "ingredients": [{"id": "copper_bar", "count": 6}, {"id": "wood", "count": 1}], "requires": ["workbench"]},
        {"result": "copper_helmet", "count": 1, "ingredients": [{"id": "copper_bar", "count": 5}], "requires": ["workbench"]},
        {"result": "copper_chestplate", "count": 1, "ingredients": [{"id": "copper_bar", "count": 8}], "requires": ["workbench"]},
        {"result": "copper_greaves", "count": 1, "ingredients": [{"id": "copper_bar", "count": 6}], "requires": ["workbench"]},
        
        # Iron tools - need workbench
        {"result": "iron_pickaxe", "count": 1, "ingredients": [{"id": "iron_bar", "count": 5}, {"id": "wood", "count": 2}], "requires": ["workbench"]},
        {"result": "iron_axe", "count": 1, "ingredients": [{"id": "iron_bar", "count": 4}, {"id": "wood", "count": 2}], "requires": ["workbench"]},
        {"result": "iron_sword", "count": 1, "ingredients": [{"id": "iron_bar", "count": 6}, {"id": "wood", "count": 1}], "requires": ["workbench"]},
        {"result": "iron_helmet", "count": 1, "ingredients": [{"id": "iron_bar", "count": 5}], "requires": ["workbench"]},
        {"result": "iron_chestplate", "count": 1, "ingredients": [{"id": "iron_bar", "count": 8}], "requires": ["workbench"]},
        {"result": "iron_greaves", "count": 1, "ingredients": [{"id": "iron_bar", "count": 6}], "requires": ["workbench"]},
        
        # Silver tools - need workbench
        {"result": "silver_pickaxe", "count": 1, "ingredients": [{"id": "silver_bar", "count": 5}, {"id": "wood", "count": 2}], "requires": ["workbench"]},
        {"result": "silver_sword", "count": 1, "ingredients": [{"id": "silver_bar", "count": 6}, {"id": "wood", "count": 1}], "requires": ["workbench"]},
        
        # Gold tools - need workbench
        {"result": "gold_pickaxe", "count": 1, "ingredients": [{"id": "gold_bar", "count": 5}, {"id": "wood", "count": 2}], "requires": ["workbench"]},
        {"result": "gold_sword", "count": 1, "ingredients": [{"id": "gold_bar", "count": 6}, {"id": "wood", "count": 1}], "requires": ["workbench"]},
        
        # Bars (need to smelt - simplified to just need workbench for now)
        {"result": "copper_bar", "count": 1, "ingredients": [{"id": "copper_ore", "count": 3}], "requires": ["workbench"]},
        {"result": "iron_bar", "count": 1, "ingredients": [{"id": "iron_ore", "count": 3}], "requires": ["workbench"]},
        {"result": "silver_bar", "count": 1, "ingredients": [{"id": "silver_ore", "count": 4}], "requires": ["workbench"]},
        {"result": "gold_bar", "count": 1, "ingredients": [{"id": "gold_ore", "count": 4}], "requires": ["workbench"]},
        
        # Consumables
        {"result": "lesser_healing_potion", "count": 2, "ingredients": [{"id": "gel", "count": 2}, {"id": "mushroom", "count": 1}], "requires": ["workbench"]},
        
        # Boss summoner
        {"result": "worm_food", "count": 1, "ingredients": [{"id": "rotten_chunk", "count": 5}, {"id": "vile_mushroom", "count": 1}], "requires": ["workbench"]},
        
        # Ebonstone brick from ebonstone
        {"result": "ebonstone_brick", "count": 1, "ingredients": [{"id": "ebonstone", "count": 1}], "requires": ["workbench"]},
]


# Validate recipes at startup (defensive: catches malformed entries)
var _valid_recipes: Array = []


func _ready() -> void:
        _valid_recipes = []
        for recipe in RECIPES:
                if typeof(recipe) != TYPE_DICTIONARY:
                        push_warning("RecipeDB: skipping non-dict recipe: %s" % str(recipe))
                        continue
                if not recipe.has("result") or not recipe.has("ingredients"):
                        push_warning("RecipeDB: skipping malformed recipe: %s" % str(recipe))
                        continue
                _valid_recipes.append(recipe)


func get_recipes() -> Array:
        return _valid_recipes


## Returns recipes that can be crafted given the player's inventory and nearby stations
func get_available_recipes(inventory: Array, nearby_stations: Array) -> Array:
        var available := []
        for recipe in _valid_recipes:
                if not _has_ingredients(recipe, inventory):
                        continue
                if not _has_stations(recipe, nearby_stations):
                        continue
                available.append(recipe)
        return available


func _has_ingredients(recipe: Dictionary, inventory: Array) -> bool:
        for ingredient in recipe.get("ingredients", []):
                var needed: int = ingredient.get("count", 0)
                var have := _count_item(inventory, ingredient.get("id", ""))
                if have < needed:
                        return false
        return true


func _has_stations(recipe: Dictionary, nearby_stations: Array) -> bool:
        var requires: Array = recipe.get("requires", [])
        for station in requires:
                if not nearby_stations.has(station):
                        return false
        return true


func _count_item(inventory: Array, item_id: String) -> int:
        var total := 0
        for slot in inventory:
                if slot == null:
                        continue
                if typeof(slot) == TYPE_DICTIONARY and slot.get("id", "") == item_id:
                        total += slot.get("count", 0)
        return total


## Returns true if the recipe can be crafted (ingredients available and stations met)
func can_craft(recipe: Dictionary, inventory: Array, nearby_stations: Array) -> bool:
        return _has_ingredients(recipe, inventory) and _has_stations(recipe, nearby_stations)


## Consumes ingredients from inventory (returns modified copy). Assumes can_craft returned true.
func consume_ingredients(inventory: Array, recipe: Dictionary) -> Array:
        # Work on a copy
        var inv: Array = inventory.duplicate(true)
        for ingredient in recipe.get("ingredients", []):
                var needed: int = ingredient.get("count", 0)
                var item_id: String = ingredient.get("id", "")
                for i in range(inv.size()):
                        if needed <= 0:
                                break
                        if inv[i] == null or typeof(inv[i]) != TYPE_DICTIONARY:
                                continue
                        if inv[i].get("id", "") == item_id:
                                var take: int = min(needed, inv[i].get("count", 0))
                                inv[i]["count"] = inv[i].get("count", 0) - take
                                needed -= take
                                if inv[i]["count"] <= 0:
                                        inv[i] = null
        return inv
