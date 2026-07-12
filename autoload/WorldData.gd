extends Node
## WorldData autoload - global constants and helpers for world layout

# World size (in tiles)
const WORLD_WIDTH := 1200
const WORLD_HEIGHT := 400
const TILE_SIZE := 16

# Surface level (y coord where surface starts)
const SURFACE_LEVEL := 120

# Underground level (dirt layer transitions to stone)
const UNDERGROUND_LEVEL := 180

# Cave level (deeper, more dangerous)
const CAVE_LEVEL := 240

# Layer depths
const HELL_LEVEL := 380  # Not implemented fully, just boundary

# Tile type IDs (must match TileType.gd enum)
enum Tile {
	AIR = 0,
	DIRT = 1,
	GRASS = 2,
	STONE = 3,
	WOOD = 4,  # tree trunk
	LEAVES = 5,
	COPPER_ORE = 6,
	IRON_ORE = 7,
	SILVER_ORE = 8,
	GOLD_ORE = 9,
	CORRUPT_GRASS = 10,
	CORRUPT_STONE = 11,  # ebonstone
	CORRUPT_DIRT = 12,  # ebonsand-like dirt
	EBONSTONE_BRICK = 13,
	WOOD_PLATFORM = 14,
	WORKBENCH = 15,
	TORCH = 16,
	CHEST = 17,
	SAND = 18,
	ASH = 19,
	PLATFORM = 14,  # alias
}

# Tile properties: solid, mineable, light source, etc.
# This will be queried by ItemDB and WorldGen
const TILE_PROPERTIES := {
	Tile.AIR: {"solid": false, "mineable": false, "hardness": 0, "light": 0, "name": "Air"},
	Tile.DIRT: {"solid": true, "mineable": true, "hardness": 0.5, "light": 0, "name": "Dirt", "tool": "pickaxe", "min_tier": 0},
	Tile.GRASS: {"solid": true, "mineable": true, "hardness": 0.5, "light": 0, "name": "Grass", "tool": "pickaxe", "min_tier": 0},
	Tile.STONE: {"solid": true, "mineable": true, "hardness": 1.5, "light": 0, "name": "Stone", "tool": "pickaxe", "min_tier": 0},
	Tile.WOOD: {"solid": true, "mineable": true, "hardness": 1.0, "light": 0, "name": "Wood", "tool": "axe", "min_tier": 0},
	Tile.LEAVES: {"solid": false, "mineable": true, "hardness": 0.3, "light": 0, "name": "Leaves", "tool": "any"},
	Tile.COPPER_ORE: {"solid": true, "mineable": true, "hardness": 2.0, "light": 0, "name": "Copper Ore", "tool": "pickaxe", "min_tier": 0},
	Tile.IRON_ORE: {"solid": true, "mineable": true, "hardness": 3.0, "light": 0, "name": "Iron Ore", "tool": "pickaxe", "min_tier": 0},
	Tile.SILVER_ORE: {"solid": true, "mineable": true, "hardness": 4.0, "light": 0, "name": "Silver Ore", "tool": "pickaxe", "min_tier": 1},
	Tile.GOLD_ORE: {"solid": true, "mineable": true, "hardness": 5.0, "light": 0, "name": "Gold Ore", "tool": "pickaxe", "min_tier": 1},
	Tile.CORRUPT_GRASS: {"solid": true, "mineable": true, "hardness": 0.6, "light": 0, "name": "Corrupt Grass", "tool": "pickaxe", "min_tier": 0},
	Tile.CORRUPT_STONE: {"solid": true, "mineable": true, "hardness": 3.0, "light": 0, "name": "Ebonstone", "tool": "pickaxe", "min_tier": 1},
	Tile.CORRUPT_DIRT: {"solid": true, "mineable": true, "hardness": 0.7, "light": 0, "name": "Corrupt Dirt", "tool": "pickaxe", "min_tier": 0},
	Tile.EBONSTONE_BRICK: {"solid": true, "mineable": true, "hardness": 3.5, "light": 0, "name": "Ebonstone Brick", "tool": "pickaxe", "min_tier": 1},
	Tile.WOOD_PLATFORM: {"solid": false, "mineable": true, "hardness": 0.5, "light": 0, "name": "Wood Platform", "tool": "any", "platform": true},
	Tile.WORKBENCH: {"solid": true, "mineable": true, "hardness": 1.0, "light": 0, "name": "Workbench", "tool": "axe", "min_tier": 0, "furniture": true},
	Tile.TORCH: {"solid": false, "mineable": true, "hardness": 0.1, "light": 12, "name": "Torch", "tool": "any", "placeable_on": true},
	Tile.CHEST: {"solid": true, "mineable": true, "hardness": 1.0, "light": 0, "name": "Chest", "tool": "any", "furniture": true},
	Tile.SAND: {"solid": true, "mineable": true, "hardness": 0.5, "light": 0, "name": "Sand", "tool": "pickaxe", "min_tier": 0},
	Tile.ASH: {"solid": true, "mineable": true, "hardness": 1.0, "light": 0, "name": "Ash", "tool": "pickaxe", "min_tier": 0},
}


func is_solid(tile_id: int) -> bool:
	var props: Dictionary = TILE_PROPERTIES.get(tile_id, {})
	return props.get("solid", false)


func is_mineable(tile_id: int) -> bool:
	var props: Dictionary = TILE_PROPERTIES.get(tile_id, {})
	return props.get("mineable", false)


func is_platform(tile_id: int) -> bool:
	var props: Dictionary = TILE_PROPERTIES.get(tile_id, {})
	return props.get("platform", false)


func tile_light(tile_id: int) -> int:
	var props: Dictionary = TILE_PROPERTIES.get(tile_id, {})
	return props.get("light", 0)


func tile_name(tile_id: int) -> String:
	var props: Dictionary = TILE_PROPERTIES.get(tile_id, {})
	return props.get("name", "Unknown")


func tile_hardness(tile_id: int) -> float:
	var props: Dictionary = TILE_PROPERTIES.get(tile_id, {})
	return props.get("hardness", 1.0)


func tile_to_world_pos(tile_x: int, tile_y: int) -> Vector2:
	return Vector2(tile_x * TILE_SIZE, tile_y * TILE_SIZE)


func world_to_tile_pos(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)
