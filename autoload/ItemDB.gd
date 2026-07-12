extends Node
## ItemDB autoload - registry of all items in the game

enum ItemCategory {
	BLOCK,
	PICKAXE,
	AXE,
	SWORD,
	BOW,
	MATERIAL,
	CONSUMABLE,
	PLACEABLE,
	ARMOR,
	ACCESSORY,
	TOOL,
}

# Item IDs
const ITEMS := {
	# Blocks
	"dirt": {"id": "dirt", "name": "Dirt", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 1, "icon_color": Color(0.45, 0.30, 0.20)},
	"stone": {"id": "stone", "name": "Stone", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 3, "icon_color": Color(0.45, 0.45, 0.50)},
	"grass": {"id": "grass", "name": "Grass", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 2, "icon_color": Color(0.35, 0.55, 0.20)},
	"wood": {"id": "wood", "name": "Wood", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 4, "icon_color": Color(0.50, 0.35, 0.20)},
	"leaves": {"id": "leaves", "name": "Leaves", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 5, "icon_color": Color(0.25, 0.55, 0.20)},
	"copper_ore": {"id": "copper_ore", "name": "Copper Ore", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 6, "icon_color": Color(0.65, 0.40, 0.25)},
	"iron_ore": {"id": "iron_ore", "name": "Iron Ore", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 7, "icon_color": Color(0.70, 0.65, 0.60)},
	"silver_ore": {"id": "silver_ore", "name": "Silver Ore", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 8, "icon_color": Color(0.85, 0.85, 0.90)},
	"gold_ore": {"id": "gold_ore", "name": "Gold Ore", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 9, "icon_color": Color(0.95, 0.85, 0.30)},
	"corrupt_grass": {"id": "corrupt_grass", "name": "Corrupt Grass", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 10, "icon_color": Color(0.35, 0.30, 0.45)},
	"ebonstone": {"id": "ebonstone", "name": "Ebonstone", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 11, "icon_color": Color(0.30, 0.25, 0.40)},
	"corrupt_dirt": {"id": "corrupt_dirt", "name": "Corrupt Dirt", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 12, "icon_color": Color(0.35, 0.25, 0.30)},
	"ebonstone_brick": {"id": "ebonstone_brick", "name": "Ebonstone Brick", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 13, "icon_color": Color(0.25, 0.20, 0.35)},
	"wood_platform": {"id": "wood_platform", "name": "Wood Platform", "category": ItemCategory.PLACEABLE, "max_stack": 99, "tile": 14, "icon_color": Color(0.60, 0.45, 0.30)},
	"workbench": {"id": "workbench", "name": "Workbench", "category": ItemCategory.PLACEABLE, "max_stack": 99, "tile": 15, "icon_color": Color(0.55, 0.40, 0.25)},
	"torch": {"id": "torch", "name": "Torch", "category": ItemCategory.PLACEABLE, "max_stack": 99, "tile": 16, "icon_color": Color(1.0, 0.80, 0.30)},
	"chest": {"id": "chest", "name": "Chest", "category": ItemCategory.PLACEABLE, "max_stack": 99, "tile": 17, "icon_color": Color(0.70, 0.55, 0.30)},
	"sand": {"id": "sand", "name": "Sand", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 18, "icon_color": Color(0.85, 0.80, 0.55)},
	"ash": {"id": "ash", "name": "Ash", "category": ItemCategory.BLOCK, "max_stack": 99, "tile": 19, "icon_color": Color(0.30, 0.25, 0.20)},
	
	# Materials
	"gel": {"id": "gel", "name": "Gel", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.40, 0.50, 0.80, 0.6)},
	"wood_arrow": {"id": "wood_arrow", "name": "Wooden Arrow", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.55, 0.40, 0.20)},
	"copper_bar": {"id": "copper_bar", "name": "Copper Bar", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.75, 0.45, 0.30)},
	"iron_bar": {"id": "iron_bar", "name": "Iron Bar", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.80, 0.75, 0.70)},
	"silver_bar": {"id": "silver_bar", "name": "Silver Bar", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.90, 0.90, 0.95)},
	"gold_bar": {"id": "gold_bar", "name": "Gold Bar", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.95, 0.85, 0.30)},
	"rotten_chunk": {"id": "rotten_chunk", "name": "Rotten Chunk", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.40, 0.35, 0.30)},
	"vile_mushroom": {"id": "vile_mushroom", "name": "Vile Mushroom", "category": ItemCategory.MATERIAL, "max_stack": 99, "icon_color": Color(0.45, 0.30, 0.50)},
	"worm_food": {"id": "worm_food", "name": "Worm Food", "category": ItemCategory.CONSUMABLE, "max_stack": 20, "icon_color": Color(0.30, 0.20, 0.40), "use": "summon_eow"},
	"mushroom": {"id": "mushroom", "name": "Mushroom", "category": ItemCategory.CONSUMABLE, "max_stack": 99, "icon_color": Color(0.55, 0.50, 0.40), "heal": 15},
	"lesser_healing_potion": {"id": "lesser_healing_potion", "name": "Lesser Healing Potion", "category": ItemCategory.CONSUMABLE, "max_stack": 30, "icon_color": Color(0.80, 0.20, 0.30), "heal": 50},
	"lesser_mana_potion": {"id": "lesser_mana_potion", "name": "Lesser Mana Potion", "category": ItemCategory.CONSUMABLE, "max_stack": 30, "icon_color": Color(0.30, 0.30, 0.90), "mana": 50},
	
	# Tools - Pickaxes (tier 0..4)
	"wood_pickaxe": {"id": "wood_pickaxe", "name": "Wooden Pickaxe", "category": ItemCategory.PICKAXE, "max_stack": 1, "tier": 0, "power": 35, "speed": 1.0, "icon_color": Color(0.55, 0.40, 0.25)},
	"copper_pickaxe": {"id": "copper_pickaxe", "name": "Copper Pickaxe", "category": ItemCategory.PICKAXE, "max_stack": 1, "tier": 1, "power": 40, "speed": 1.1, "icon_color": Color(0.75, 0.45, 0.30)},
	"iron_pickaxe": {"id": "iron_pickaxe", "name": "Iron Pickaxe", "category": ItemCategory.PICKAXE, "max_stack": 1, "tier": 2, "power": 55, "speed": 1.2, "icon_color": Color(0.80, 0.75, 0.70)},
	"silver_pickaxe": {"id": "silver_pickaxe", "name": "Silver Pickaxe", "category": ItemCategory.PICKAXE, "max_stack": 1, "tier": 3, "power": 65, "speed": 1.3, "icon_color": Color(0.90, 0.90, 0.95)},
	"gold_pickaxe": {"id": "gold_pickaxe", "name": "Gold Pickaxe", "category": ItemCategory.PICKAXE, "max_stack": 1, "tier": 4, "power": 80, "speed": 1.4, "icon_color": Color(0.95, 0.85, 0.30)},
	
	# Tools - Axes
	"wood_axe": {"id": "wood_axe", "name": "Wooden Axe", "category": ItemCategory.AXE, "max_stack": 1, "tier": 0, "power": 25, "speed": 1.0, "icon_color": Color(0.55, 0.40, 0.25)},
	"copper_axe": {"id": "copper_axe", "name": "Copper Axe", "category": ItemCategory.AXE, "max_stack": 1, "tier": 1, "power": 30, "speed": 1.1, "icon_color": Color(0.75, 0.45, 0.30)},
	"iron_axe": {"id": "iron_axe", "name": "Iron Axe", "category": ItemCategory.AXE, "max_stack": 1, "tier": 2, "power": 40, "speed": 1.2, "icon_color": Color(0.80, 0.75, 0.70)},
	
	# Weapons - Swords
	"wood_sword": {"id": "wood_sword", "name": "Wooden Sword", "category": ItemCategory.SWORD, "max_stack": 1, "damage": 5, "knockback": 4.0, "speed": 0.4, "range": 32, "icon_color": Color(0.55, 0.40, 0.25)},
	"copper_sword": {"id": "copper_sword", "name": "Copper Sword", "category": ItemCategory.SWORD, "max_stack": 1, "damage": 8, "knockback": 5.0, "speed": 0.4, "range": 36, "icon_color": Color(0.75, 0.45, 0.30)},
	"iron_sword": {"id": "iron_sword", "name": "Iron Sword", "category": ItemCategory.SWORD, "max_stack": 1, "damage": 11, "knockback": 5.5, "speed": 0.4, "range": 40, "icon_color": Color(0.80, 0.75, 0.70)},
	"silver_sword": {"id": "silver_sword", "name": "Silver Sword", "category": ItemCategory.SWORD, "max_stack": 1, "damage": 14, "knockback": 6.0, "speed": 0.4, "range": 42, "icon_color": Color(0.90, 0.90, 0.95)},
	"gold_sword": {"id": "gold_sword", "name": "Gold Sword", "category": ItemCategory.SWORD, "max_stack": 1, "damage": 17, "knockback": 6.5, "speed": 0.4, "range": 44, "icon_color": Color(0.95, 0.85, 0.30)},
	
	# Weapons - Bows
	"wood_bow": {"id": "wood_bow", "name": "Wooden Bow", "category": ItemCategory.BOW, "max_stack": 1, "damage": 6, "speed": 0.6, "icon_color": Color(0.55, 0.40, 0.25)},
	
	# Armor (chestplates, helmets, leggings - simplified to single piece)
	"copper_helmet": {"id": "copper_helmet", "name": "Copper Helmet", "category": ItemCategory.ARMOR, "max_stack": 1, "defense": 1, "slot": "head", "icon_color": Color(0.75, 0.45, 0.30)},
	"copper_chestplate": {"id": "copper_chestplate", "name": "Copper Chestplate", "category": ItemCategory.ARMOR, "max_stack": 1, "defense": 2, "slot": "chest", "icon_color": Color(0.75, 0.45, 0.30)},
	"copper_greaves": {"id": "copper_greaves", "name": "Copper Greaves", "category": ItemCategory.ARMOR, "max_stack": 1, "defense": 1, "slot": "legs", "icon_color": Color(0.75, 0.45, 0.30)},
	"iron_helmet": {"id": "iron_helmet", "name": "Iron Helmet", "category": ItemCategory.ARMOR, "max_stack": 1, "defense": 2, "slot": "head", "icon_color": Color(0.80, 0.75, 0.70)},
	"iron_chestplate": {"id": "iron_chestplate", "name": "Iron Chestplate", "category": ItemCategory.ARMOR, "max_stack": 1, "defense": 3, "slot": "chest", "icon_color": Color(0.80, 0.75, 0.70)},
	"iron_greaves": {"id": "iron_greaves", "name": "Iron Greaves", "category": ItemCategory.ARMOR, "max_stack": 1, "defense": 2, "slot": "legs", "icon_color": Color(0.80, 0.75, 0.70)},
	
	# Accessories
	"band_of_regeneration": {"id": "band_of_regeneration", "name": "Band of Regeneration", "category": ItemCategory.ACCESSORY, "max_stack": 1, "regen_bonus": 1.0, "icon_color": Color(0.90, 0.40, 0.40)},
}


func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


func item_exists(item_id: String) -> bool:
	return ITEMS.has(item_id)


func all_item_ids() -> Array:
	return ITEMS.keys()


func get_category_name(cat: int) -> String:
	match cat:
		ItemCategory.BLOCK: return "Block"
		ItemCategory.PICKAXE: return "Pickaxe"
		ItemCategory.AXE: return "Axe"
		ItemCategory.SWORD: return "Sword"
		ItemCategory.BOW: return "Bow"
		ItemCategory.MATERIAL: return "Material"
		ItemCategory.CONSUMABLE: return "Consumable"
		ItemCategory.PLACEABLE: return "Placeable"
		ItemCategory.ARMOR: return "Armor"
		ItemCategory.ACCESSORY: return "Accessory"
		ItemCategory.TOOL: return "Tool"
		_: return "Unknown"
