class_name WorldGen
## Static class for procedural world generation
## Generates a 2D tile array with terrain, caves, ores, biomes (forest + corruption)
extends RefCounted


## Generate the world. Returns a Dictionary with:
##  - "tiles": 2D array of tile IDs [y][x]
##  - "wall_tiles": 2D array of wall tile IDs (background, behind tiles)
##  - "spawn": Vector2i spawn tile position
##  - "biomes": 2D array of biome IDs per tile [y][x]
##    0=forest, 1=corruption
##  - "surface_heights": array of surface y per x
##  - "corruption_zones": list of corruption zone dictionaries
static func generate_world(seed_val: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val

    var W: int = WorldData.WORLD_WIDTH
    var H: int = WorldData.WORLD_HEIGHT
    var SURFACE: int = WorldData.SURFACE_LEVEL

    # Initialize tile arrays
    var tiles: Array = []
    var wall_tiles: Array = []
    var biomes: Array = []
    for y in range(H):
        var row: Array = []
        var wrow: Array = []
        var brow: Array = []
        row.resize(W)
        wrow.resize(W)
        brow.resize(W)
        for x in range(W):
            row[x] = WorldData.Tile.AIR
            wrow[x] = WorldData.Tile.AIR
            brow[x] = 0  # forest by default
        tiles.append(row)
        wall_tiles.append(wrow)
        biomes.append(brow)

    # Surface noise - terrain height variation
    var surface_noise := FastNoiseLite.new()
    surface_noise.seed = seed_val
    surface_noise.frequency = 0.005
    surface_noise.noise_type = FastNoiseLite.TYPE_PERLIN

    var surface_noise2 := FastNoiseLite.new()
    surface_noise2.seed = seed_val + 1
    surface_noise2.frequency = 0.015
    surface_noise2.noise_type = FastNoiseLite.TYPE_PERLIN

    # Compute surface heights
    var surface_heights: Array = []
    surface_heights.resize(W)
    for x in range(W):
        var n: float = surface_noise.get_noise_2d(x, 0)  # -1..1
        var n2: float = surface_noise2.get_noise_2d(x, 0)
        # Base surface + variation
        var h: float = SURFACE + n * 18.0 + n2 * 6.0
        surface_heights[x] = int(h)

    # Determine biome layout: corruption chunks at certain x positions
    # Place corruption at 1/4 and 3/4 of world, with some width
    var corruption_zones: Array = []
    var corruption_width := 80
    # Random offset
    var corr_start1: int = W / 4 + rng.randi_range(-20, 20)
    var corr_start2: int = 3 * W / 4 + rng.randi_range(-20, 20)
    corruption_zones.append({"start": corr_start1 - corruption_width / 2, "end": corr_start1 + corruption_width / 2})
    corruption_zones.append({"start": corr_start2 - corruption_width / 2, "end": corr_start2 + corruption_width / 2})

    # Fill tiles
    for x in range(W):
        var surf_y: int = surface_heights[x]
        var biome_id := 0  # forest
        for zone in corruption_zones:
            # Smooth transition zone
            var center: int = (zone.start + zone.end) / 2
            var half_w: int = (zone.end - zone.start) / 2
            if abs(x - center) < half_w:
                biome_id = 1  # corruption

        for y in range(H):
            if y < surf_y:
                tiles[y][x] = WorldData.Tile.AIR
                continue

            var is_corrupt := (biome_id == 1)

            # Determine layer
            if y == surf_y:
                # Surface block
                if is_corrupt:
                    tiles[y][x] = WorldData.Tile.CORRUPT_GRASS
                else:
                    tiles[y][x] = WorldData.Tile.GRASS
                wall_tiles[y][x] = WorldData.Tile.DIRT
            elif y < surf_y + 5:
                # Just below surface - dirt
                if is_corrupt:
                    tiles[y][x] = WorldData.Tile.CORRUPT_DIRT
                else:
                    tiles[y][x] = WorldData.Tile.DIRT
                wall_tiles[y][x] = WorldData.Tile.DIRT
            elif y < WorldData.UNDERGROUND_LEVEL:
                # Dirt layer
                if is_corrupt:
                    tiles[y][x] = WorldData.Tile.CORRUPT_DIRT
                else:
                    tiles[y][x] = WorldData.Tile.DIRT
                wall_tiles[y][x] = WorldData.Tile.DIRT
            elif y < WorldData.CAVE_LEVEL:
                # Stone layer
                if is_corrupt:
                    tiles[y][x] = WorldData.Tile.CORRUPT_STONE
                else:
                    tiles[y][x] = WorldData.Tile.STONE
                wall_tiles[y][x] = WorldData.Tile.STONE
            else:
                # Deep stone layer
                if is_corrupt:
                    tiles[y][x] = WorldData.Tile.CORRUPT_STONE
                else:
                    tiles[y][x] = WorldData.Tile.STONE
                wall_tiles[y][x] = WorldData.Tile.STONE

            biomes[y][x] = biome_id

    # Carve caves using 2D noise
    var cave_noise := FastNoiseLite.new()
    cave_noise.seed = seed_val + 2
    cave_noise.frequency = 0.03
    cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN

    var cave_noise2 := FastNoiseLite.new()
    cave_noise2.seed = seed_val + 3
    cave_noise2.frequency = 0.06
    cave_noise2.noise_type = FastNoiseLite.TYPE_PERLIN

    var tunnel_noise := FastNoiseLite.new()
    tunnel_noise.seed = seed_val + 4
    tunnel_noise.frequency = 0.04
    tunnel_noise.noise_type = FastNoiseLite.TYPE_CELLULAR

    for x in range(W):
        var surf_y2: int = surface_heights[x]
        for y in range(surf_y2 + 4, H - 5):
            var n: float = cave_noise.get_noise_2d(x, y)
            var n2: float = cave_noise2.get_noise_2d(x, y)
            var tun: float = tunnel_noise.get_noise_2d(x, y)
            # Carve cave if combined noise > threshold
            # Deeper = larger caves
            var depth_factor: float = clamp((y - surf_y2) / 100.0, 0.0, 1.0)
            var threshold: float = 0.55 - depth_factor * 0.15
            if (n + n2 * 0.5) / 1.5 > threshold:
                tiles[y][x] = WorldData.Tile.AIR
            # Tunnels
            elif tun > 0.6:
                tiles[y][x] = WorldData.Tile.AIR

    # Add ores in stone layer using noise patches
    _place_ores(tiles, seed_val + 10, WorldData.Tile.COPPER_ORE, 0.20, 5, WorldData.Tile.STONE)
    _place_ores(tiles, seed_val + 11, WorldData.Tile.COPPER_ORE, 0.18, 4, WorldData.Tile.CORRUPT_STONE)
    _place_ores(tiles, seed_val + 12, WorldData.Tile.IRON_ORE, 0.15, 4, WorldData.Tile.STONE)
    _place_ores(tiles, seed_val + 13, WorldData.Tile.IRON_ORE, 0.13, 3, WorldData.Tile.CORRUPT_STONE)
    _place_ores(tiles, seed_val + 14, WorldData.Tile.SILVER_ORE, 0.08, 3, WorldData.Tile.STONE)
    _place_ores(tiles, seed_val + 15, WorldData.Tile.GOLD_ORE, 0.06, 3, WorldData.Tile.STONE)
    # Deeper ores
    _place_ores_deep(tiles, seed_val + 16, WorldData.Tile.SILVER_ORE, 0.10, 3)
    _place_ores_deep(tiles, seed_val + 17, WorldData.Tile.GOLD_ORE, 0.08, 3)

    # Place trees on grass surface (forest only)
    _place_trees(tiles, surface_heights, biomes, seed_val + 20)

    # Add a small starting cave/platform area at spawn (so player doesn't get stuck)
    var spawn_x: int = W / 2
    var spawn_y: int = int(surface_heights[spawn_x]) - 3
    # Clear a wider area (including any tree trunks)
    for dy in range(-5, 4):
        for dx in range(-3, 4):
            var tx: int = spawn_x + dx
            var ty: int = spawn_y + dy
            if tx >= 0 and tx < W and ty >= 0 and ty < H:
                tiles[ty][tx] = WorldData.Tile.AIR
    # Place a wood platform under spawn for safety
    var plat_y: int = spawn_y + 3
    for dx in range(-3, 4):
        var tx: int = spawn_x + dx
        if tx >= 0 and tx < W and plat_y >= 0 and plat_y < H:
            tiles[plat_y][tx] = WorldData.Tile.WOOD_PLATFORM

    # Ensure corruption chasms - vertical drops in corruption zones
    for zone in corruption_zones:
        var center: int = (zone.start + zone.end) / 2
        var width := 8
        for dx in range(-width, width + 1):
            var x: int = center + dx
            if x < 0 or x >= W:
                continue
            var depth: int = 60 - abs(dx) * 3  # Funnel shape
            depth = max(20, depth)
            var surf_y3: int = int(surface_heights[x])
            for y in range(surf_y3, min(surf_y3 + depth, H)):
                tiles[y][x] = WorldData.Tile.AIR
        # Place ebonstone around the chasm walls
        for dx in range(-width - 2, width + 3):
            var x: int = center + dx
            if x < 0 or x >= W:
                continue
            var depth: int = 60 - abs(dx) * 3
            depth = max(20, depth)
            var surf_y3: int = int(surface_heights[x])
            for y in range(surf_y3, min(surf_y3 + depth, H)):
                # Adjacent to air = wall
                if tiles[y][x] == WorldData.Tile.AIR:
                    continue
                # Check 4-neighbors
                var has_air := false
                for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                    var nx: int = x + dir.x
                    var ny: int = y + dir.y
                    if nx >= 0 and nx < W and ny >= 0 and ny < H:
                        if tiles[ny][nx] == WorldData.Tile.AIR:
                            has_air = true
                            break
                if has_air and tiles[y][x] != WorldData.Tile.CORRUPT_STONE:
                    tiles[y][x] = WorldData.Tile.CORRUPT_STONE

    return {
        "tiles": tiles,
        "wall_tiles": wall_tiles,
        "biomes": biomes,
        "surface_heights": surface_heights,
        "spawn": Vector2i(spawn_x, spawn_y),
        "corruption_zones": corruption_zones,
    }


static func _place_ores(tiles: Array, seed_val: int, ore_type: int, density: float, patch_size: int, host_tile: int) -> void:
    var W: int = tiles[0].size()
    var H: int = tiles.size()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    # Generate candidate ore positions
    var attempts: int = int(W * H * density * 0.001)
    for _i in range(attempts):
        var x: int = rng.randi_range(2, W - 3)
        var y: int = rng.randi_range(WorldData.SURFACE_LEVEL + 5, H - 5)
        if tiles[y][x] != host_tile:
            continue
        # Place a small patch
        var px: int = x
        var py: int = y
        for _j in range(patch_size):
            if px < 0 or px >= W or py < 0 or py >= H:
                break
            if tiles[py][px] == host_tile:
                tiles[py][px] = ore_type
            # Walk in random direction
            px += rng.randi_range(-1, 1)
            py += rng.randi_range(-1, 1)


static func _place_ores_deep(tiles: Array, seed_val: int, ore_type: int, density: float, patch_size: int) -> void:
    var W: int = tiles[0].size()
    var H: int = tiles.size()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var attempts: int = int(W * H * density * 0.0008)
    for _i in range(attempts):
        var x: int = rng.randi_range(2, W - 3)
        var y: int = rng.randi_range(WorldData.CAVE_LEVEL, H - 5)
        # Either stone or corrupt stone host
        if tiles[y][x] != WorldData.Tile.STONE and tiles[y][x] != WorldData.Tile.CORRUPT_STONE:
            continue
        var px: int = x
        var py: int = y
        for _j in range(patch_size):
            if px < 0 or px >= W or py < 0 or py >= H:
                break
            if tiles[py][px] == WorldData.Tile.STONE or tiles[py][px] == WorldData.Tile.CORRUPT_STONE:
                tiles[py][px] = ore_type
            px += rng.randi_range(-1, 1)
            py += rng.randi_range(-1, 1)


static func _place_trees(tiles: Array, surface_heights: Array, biomes: Array, seed_val: int) -> void:
    var W: int = tiles[0].size()
    var H: int = tiles.size()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var x := 5
    while x < W - 5:
        # Random spacing
        var spacing: int = rng.randi_range(4, 9)
        x += spacing
        if x >= W - 5:
            break
        var surf_y: int = int(surface_heights[x])
        # Only on grass
        if surf_y + 1 >= H:
            continue
        if tiles[surf_y][x] != WorldData.Tile.GRASS:
            continue
        # Don't place too close to corruption chasm
        var biome_at: int = biomes[surf_y][x]
        if biome_at != 0:
            continue
        # Tree height
        var height: int = rng.randi_range(4, 8)
        # Trunk
        for dy in range(1, height + 1):
            var ty: int = surf_y - dy
            if ty < 0:
                break
            tiles[ty][x] = WorldData.Tile.WOOD
        # Leaves canopy
        var canopy_y: int = surf_y - height
        var canopy_radius := 2
        for dy in range(-canopy_radius, canopy_radius + 1):
            for dx in range(-canopy_radius, canopy_radius + 1):
                if dx * dx + dy * dy > canopy_radius * canopy_radius + 1:
                    continue
                var tx: int = x + dx
                var ty: int = canopy_y + dy
                if tx < 0 or tx >= W or ty < 0 or ty >= H:
                    continue
                if tiles[ty][tx] == WorldData.Tile.AIR:
                    tiles[ty][tx] = WorldData.Tile.LEAVES
