class_name TileMap2D
extends Node2D
## A custom 2D tilemap that uses Godot's TileMap node for rendering
## and a 2D array for fast lookup/modification.
##
## We use a single TileSet with multiple tile sources (one per tile type),
## so each tile type can have its own color/texture.

var tile_map: TileMap
var wall_tile_map: TileMap  # Background tiles, rendered behind

var tiles: Array = []  # [y][x] = tile_id
var wall_tiles: Array = []  # [y][x] = wall_id
var width: int = 0
var height: int = 0

# Track modified tiles that need re-rendering
var _dirty_tiles: Array[Vector2i] = []

# Callbacks for tile changes (used by lighting, etc.)
signal tile_changed(tx: int, ty: int, old_id: int, new_id: int)


func _ready() -> void:
        tile_map = TileMap.new()
        tile_map.name = "Foreground"
        tile_map.tile_set = _build_tileset()
        add_child(tile_map)

        wall_tile_map = TileMap.new()
        wall_tile_map.name = "Background"
        wall_tile_map.tile_set = _build_tileset()
        # Render walls slightly darker
        wall_tile_map.modulate = Color(0.45, 0.45, 0.55, 1.0)
        add_child(wall_tile_map)

        # Move wall behind foreground
        wall_tile_map.z_index = -1


func _build_tileset() -> TileSet:
        # Build a TileSet programmatically with colored tiles
        var ts := TileSet.new()
        ts.tile_size = Vector2i(WorldData.TILE_SIZE, WorldData.TILE_SIZE)
        # Create a single atlas source with one tile per tile type
        var atlas := TileSetAtlasSource.new()
        atlas.texture = _build_atlas_texture()
        var cols := 4
        # Create tiles in the atlas - up to 32 (4 cols x 8 rows)
        for tile_id in range(32):
                var ax: int = tile_id % cols
                var ay: int = tile_id / cols
                atlas.create_tile(Vector2i(ax, ay))
        var _source_id: int = ts.add_source(atlas)
        # Source 0 is the atlas; tile_id maps to atlas coords (tile_id % 4, tile_id / 4)
        return ts


func _build_atlas_texture() -> ImageTexture:
        # Create a 4x8 atlas of 16x16 colored tiles
        var cols := 4
        var rows := 8
        var img := Image.create_empty(WorldData.TILE_SIZE * cols, WorldData.TILE_SIZE * rows, false, Image.FORMAT_RGBA8)
        # Fill each tile with its color
        for tile_id in range(cols * rows):
                var ax := tile_id % cols
                var ay := tile_id / cols
                var color := _tile_color(tile_id)
                # Fill the tile with a slight pattern for variety
                for py in range(WorldData.TILE_SIZE):
                        for px in range(WorldData.TILE_SIZE):
                                var c := color
                                # Add edge darkening for solid tiles
                                if px == 0 or px == WorldData.TILE_SIZE - 1 or py == 0 or py == WorldData.TILE_SIZE - 1:
                                        if WorldData.is_solid(tile_id):
                                                c = color.darkened(0.15)
                                # Add slight noise
                                var noise_val := (px * 7 + py * 13 + tile_id * 17) % 16
                                c = c.lightened((noise_val - 8) * 0.01)
                                img.set_pixel(ax * WorldData.TILE_SIZE + px, ay * WorldData.TILE_SIZE + py, c)
        return ImageTexture.create_from_image(img)


func _tile_color(tile_id: int) -> Color:
        match tile_id:
                WorldData.Tile.AIR: return Color(0, 0, 0, 0)
                WorldData.Tile.DIRT: return Color(0.45, 0.30, 0.20)
                WorldData.Tile.GRASS: return Color(0.30, 0.55, 0.20)
                WorldData.Tile.STONE: return Color(0.45, 0.45, 0.50)
                WorldData.Tile.WOOD: return Color(0.50, 0.35, 0.20)
                WorldData.Tile.LEAVES: return Color(0.25, 0.55, 0.20)
                WorldData.Tile.COPPER_ORE: return Color(0.65, 0.40, 0.25)
                WorldData.Tile.IRON_ORE: return Color(0.70, 0.65, 0.60)
                WorldData.Tile.SILVER_ORE: return Color(0.85, 0.85, 0.90)
                WorldData.Tile.GOLD_ORE: return Color(0.95, 0.85, 0.30)
                WorldData.Tile.CORRUPT_GRASS: return Color(0.30, 0.30, 0.45)
                WorldData.Tile.CORRUPT_STONE: return Color(0.30, 0.25, 0.40)
                WorldData.Tile.CORRUPT_DIRT: return Color(0.35, 0.25, 0.30)
                WorldData.Tile.EBONSTONE_BRICK: return Color(0.25, 0.20, 0.35)
                WorldData.Tile.WOOD_PLATFORM: return Color(0.60, 0.45, 0.30)
                WorldData.Tile.WORKBENCH: return Color(0.55, 0.40, 0.25)
                WorldData.Tile.TORCH: return Color(1.0, 0.80, 0.30)
                WorldData.Tile.CHEST: return Color(0.70, 0.55, 0.30)
                WorldData.Tile.SAND: return Color(0.85, 0.80, 0.55)
                WorldData.Tile.ASH: return Color(0.30, 0.25, 0.20)
                _: return Color.MAGENTA


func load_world(data: Dictionary) -> void:
        tiles = data.get("tiles", [])
        wall_tiles = data.get("wall_tiles", [])
        width = tiles[0].size() if tiles.size() > 0 else 0
        height = tiles.size()
        # Render all tiles - we use set_cell for each non-air tile
        # To speed this up, we render in batches
        print("[TileMap2D] Loading world %dx%d" % [width, height])
        tile_map.clear()
        wall_tile_map.clear()
        var rendered := 0
        for y in range(height):
                for x in range(width):
                        var t: int = tiles[y][x]
                        if t != WorldData.Tile.AIR:
                                _set_tile(x, y, t, false)
                                rendered += 1
                        var wt: int = wall_tiles[y][x]
                        if wt != WorldData.Tile.AIR:
                                _set_wall(x, y, wt)
        print("[TileMap2D] Rendered %d foreground tiles" % rendered)


func _set_tile(x: int, y: int, tile_id: int, update_neighbors: bool = true) -> void:
        if x < 0 or x >= width or y < 0 or y >= height:
                return
        if tile_id == WorldData.Tile.AIR:
                tile_map.set_cell(0, Vector2i(x, y), -1)  # erase
        else:
                var ax := tile_id % 4
                var ay := tile_id / 4
                tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(ax, ay))
        if update_neighbors:
                # Could update neighbor autotiling here if needed
                pass


func _set_wall(x: int, y: int, wall_id: int) -> void:
        if x < 0 or x >= width or y < 0 or y >= height:
                return
        if wall_id == WorldData.Tile.AIR:
                wall_tile_map.set_cell(0, Vector2i(x, y), -1)
        else:
                var ax := wall_id % 4
                var ay := wall_id / 4
                wall_tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(ax, ay))


func get_tile(x: int, y: int) -> int:
        if x < 0 or x >= width or y < 0 or y >= height:
                return WorldData.Tile.STONE  # Treat out-of-bounds as solid stone
        return tiles[y][x]


func get_wall(x: int, y: int) -> int:
        if x < 0 or x >= width or y < 0 or y >= height:
                return WorldData.Tile.AIR
        return wall_tiles[y][x]


func set_tile(x: int, y: int, tile_id: int, emit_signal: bool = true) -> void:
        if x < 0 or x >= width or y < 0 or y >= height:
                return
        var old: int = tiles[y][x]
        if old == tile_id:
                return
        tiles[y][x] = tile_id
        _set_tile(x, y, tile_id, true)
        if emit_signal:
                tile_changed.emit(x, y, old, tile_id)


func set_wall(x: int, y: int, wall_id: int) -> void:
        if x < 0 or x >= width or y < 0 or y >= height:
                return
        wall_tiles[y][x] = wall_id
        _set_wall(x, y, wall_id)


func is_solid_at(x: int, y: int) -> bool:
        return WorldData.is_solid(get_tile(x, y))


func is_platform_at(x: int, y: int) -> bool:
        return WorldData.is_platform(get_tile(x, y))
