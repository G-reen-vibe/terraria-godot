class_name World
extends Node2D
## The main world node - holds the tilemap, lighting, spawning, etc.

@onready var tile_map: TileMap2D = $TileMap2D

var world_data: Dictionary = {}
var spawn_point: Vector2 = Vector2.ZERO
var corruption_zones: Array = []
var surface_heights: Array = []

# Active entities
var enemies: Array = []  # list of enemy nodes
var item_drops: Array = []  # list of item drop nodes
var projectiles: Array = []
var npcs: Array = []

# Lighting grid (low-res darkness map)
var light_grid: Array = []  # [ly][lx] = light level 0..15
var light_grid_w: int = 0
var light_grid_h: int = 0
const LIGHT_CELL_SIZE := 8  # 8x8 tile cells for lighting

# Lighting overlay node (set by scene)
@onready var lighting_overlay: Node2D = $LightingOverlay

# Spawn tracking
var spawn_timer: float = 0.0
const SPAWN_CHECK_INTERVAL := 2.0
const MAX_ENEMIES := 25

# Boss
var boss_active: bool = false
var boss: Node = null

signal world_loaded
signal tile_modified(tx: int, ty: int, tile_id: int)


func _ready() -> void:
        # Generate world
        var seed_val := randi() % 1000000
        print("[World] Generating world with seed ", seed_val)
        world_data = WorldGen.generate_world(seed_val)
        tile_map.load_world(world_data)
        spawn_point = WorldData.tile_to_world_pos(world_data.spawn.x, world_data.spawn.y)
        corruption_zones = world_data.get("corruption_zones", [])
        surface_heights = world_data.get("surface_heights", [])

        # Setup lighting grid
        light_grid_w = ceil(WorldData.WORLD_WIDTH / float(LIGHT_CELL_SIZE))
        light_grid_h = ceil(WorldData.WORLD_HEIGHT / float(LIGHT_CELL_SIZE))
        light_grid.resize(light_grid_h)
        for y in range(light_grid_h):
                var row: Array = []
                row.resize(light_grid_w)
                for x in range(light_grid_w):
                        row[x] = 0
                light_grid[y] = row

        # Connect tile change signal to update lighting
        tile_map.tile_changed.connect(_on_tile_changed)

        # Connect day/night transitions to recompute lighting
        GameManager.day_started.connect(_on_day_night_transition)
        GameManager.night_started.connect(_on_day_night_transition)

        # Compute initial lighting
        _recompute_lighting_full()

        # Set world reference in GameManager
        GameManager.world = self

        world_loaded.emit()
        print("[World] World loaded. Spawn: ", spawn_point)


func _on_tile_changed(tx: int, ty: int, old_id: int, new_id: int) -> void:
        tile_modified.emit(tx, ty, new_id)
        # Recompute lighting in a small area around the change
        _recompute_lighting_area(tx - 16, ty - 16, tx + 16, ty + 16)


func _on_day_night_transition() -> void:
        # Full recompute on day/night transition (expensive but rare)
        print("[World] Day/night transition, recomputing lighting...")
        _recompute_lighting_full()


# === Lighting system ===
# Light level: 0 = full bright (sky), 15 = full dark
# Sky light is 0 above ground at day, decreases underground
# Tile light sources (torches) emit light that propagates and decays

func _sky_light_at(tx: int, ty: int) -> int:
        # Returns the sky light contribution at this tile (0..15)
        # Sky light is full (0) if there's no solid block above
        if ty < 0:
                return 0
        if ty >= WorldData.WORLD_HEIGHT:
                return 15
        # Check if any block above is solid
        for y in range(0, ty):
                if y >= WorldData.WORLD_HEIGHT:
                        break
                if tile_map.get_tile(tx, y) != WorldData.Tile.AIR and not WorldData.is_platform(tile_map.get_tile(tx, y)):
                        return 14  # Underground, but not pitch black
        # Sky visible - depends on time of day
        if GameManager.is_day():
                return 0  # Full daylight
        else:
                return 8  # Night is dimmer


func _tile_light_source(tx: int, ty: int) -> int:
        var t: int = tile_map.get_tile(tx, ty)
        return WorldData.tile_light(t)


func _recompute_lighting_full() -> void:
        # Recompute lighting for the entire world
        # Use BFS-based flood fill: start with sky light tiles and tile light sources,
        # propagate light outward, decreasing by 1 per tile (and more for solid tiles)
        # Result: light_grid[y][x] holds the darkness level (0 = full bright)
        # Performance: this is O(N) for the world - run once on load and incrementally after
        print("[World] Computing initial lighting...")
        var W := WorldData.WORLD_WIDTH
        var H := WorldData.WORLD_HEIGHT

        # Initialize: sky light = 15 (full dark, will be reduced)
        # We'll use BFS from light sources
        # Light value: 0 = no light (full dark = 15 in light_grid), 15 = max light (light_grid = 0)

        # Create a temp light array (raw light values, 0..15)
        var raw_light: Array = []
        raw_light.resize(H)
        for y in range(H):
                var row: Array = []
                row.resize(W)
                for x in range(W):
                        row[x] = 0
                raw_light[y] = row

        # Compute sky light per column (going down from top until we hit a solid block)
        # Sky brightness depends on time of day
        var sky_brightness := 15 if GameManager.is_day() else 7

        # BFS queue: Vector2i positions
        var queue: Array[Vector2i] = []

        for x in range(W):
                var sky_b := sky_brightness
                for y in range(H):
                        var t: int = tile_map.get_tile(x, y)
                        if WorldData.is_solid(t) and not WorldData.is_platform(t):
                                # Block sky light once we hit solid
                                sky_b = max(0, sky_b - 4)
                        if sky_b <= 0:
                                break
                        if sky_b > raw_light[y][x]:
                                raw_light[y][x] = sky_b
                                queue.append(Vector2i(x, y))

        # Add tile light sources (torches, etc.)
        for y in range(H):
                for x in range(W):
                        var tl: int = _tile_light_source(x, y)
                        if tl > 0 and tl > raw_light[y][x]:
                                raw_light[y][x] = tl
                                queue.append(Vector2i(x, y))

        # BFS propagation
        var idx := 0
        while idx < queue.size():
                var pos: Vector2i = queue[idx]
                idx += 1
                var cur: int = raw_light[pos.y][pos.x]
                if cur <= 1:
                        continue
                # Propagate to 4 neighbors
                for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                        var nx: int = pos.x + dir.x
                        var ny: int = pos.y + dir.y
                        if nx < 0 or nx >= W or ny < 0 or ny >= H:
                                continue
                        # Light decreases by 1 in air, by more in solid
                        var t: int = tile_map.get_tile(nx, ny)
                        var decrease := 1
                        if WorldData.is_solid(t) and not WorldData.is_platform(t):
                                decrease = 2
                        var new_light: int = cur - decrease
                        if new_light > raw_light[ny][nx]:
                                raw_light[ny][nx] = new_light
                                queue.append(Vector2i(nx, ny))

        # Convert raw_light (0..15, where 15=bright) to light_grid (0..15, where 15=dark)
        for y in range(H):
                for x in range(W):
                        # Light grid stores darkness = 15 - raw_light
                        # But we want it per-cell, not per-tile, so we sample at cell resolution
                        pass

        # Map to light_grid (downsample to light cell resolution)
        for ly in range(light_grid_h):
                for lx in range(light_grid_w):
                        # Average darkness over the cell
                        var total := 0
                        var count := 0
                        var max_dark := 0
                        for dy in range(LIGHT_CELL_SIZE):
                                for dx in range(LIGHT_CELL_SIZE):
                                        var tx := lx * LIGHT_CELL_SIZE + dx
                                        var ty := ly * LIGHT_CELL_SIZE + dy
                                        if tx >= W or ty >= H:
                                                continue
                                        var dark: int = 15 - raw_light[ty][tx]
                                        total += dark
                                        count += 1
                                        if dark > max_dark:
                                                max_dark = dark
                        if count > 0:
                                # Use max for sharper dark areas
                                light_grid[ly][lx] = max_dark


func _recompute_lighting_area(x0: int, y0: int, x1: int, y1: int) -> void:
        # Recompute lighting in a small area around a tile change.
        # Clears the area's darkness first, then recomputes from nearby light sources.
        var W := WorldData.WORLD_WIDTH
        var H := WorldData.WORLD_HEIGHT
        x0 = max(0, x0)
        y0 = max(0, y0)
        x1 = min(W - 1, x1)
        y1 = min(H - 1, y1)

        # Expand area to account for light propagation (light travels ~12 tiles)
        var margin := 16
        var ax0: int = max(0, x0 - margin)
        var ay0: int = max(0, y0 - margin)
        var ax1: int = min(W - 1, x1 + margin)
        var ay1: int = min(H - 1, y1 + margin)

        # Clear light_grid in the expanded area (set to max dark first, will be reduced)
        var lg_x0: int = max(0, ax0 / LIGHT_CELL_SIZE)
        var lg_y0: int = max(0, ay0 / LIGHT_CELL_SIZE)
        var lg_x1: int = min(light_grid_w - 1, ax1 / LIGHT_CELL_SIZE)
        var lg_y1: int = min(light_grid_h - 1, ay1 / LIGHT_CELL_SIZE)
        for ly in range(lg_y0, lg_y1 + 1):
                for lx in range(lg_x0, lg_x1 + 1):
                        light_grid[ly][lx] = 15  # max dark, will be reduced

        # Collect light sources in expanded area
        var sources: Array = []
        for y in range(ay0, ay1 + 1):
                for x in range(ax0, ax1 + 1):
                        var tl: int = _tile_light_source(x, y)
                        if tl > 0:
                                sources.append({"pos": Vector2i(x, y), "light": tl})

        var sky_brightness := 15 if GameManager.is_day() else 7

        # Recompute raw light in the area
        var raw_light: Dictionary = {}  # Vector2i -> int
        var queue: Array = []

        # Sky light in area
        for y in range(ay0, ay1 + 1):
                for x in range(ax0, ax1 + 1):
                        # Compute sky brightness at this tile
                        var sky_b := sky_brightness
                        for yy in range(0, y):
                                if yy >= H:
                                        break
                                var t: int = tile_map.get_tile(x, yy)
                                if WorldData.is_solid(t) and not WorldData.is_platform(t):
                                        sky_b = max(0, sky_b - 4)
                                if sky_b <= 0:
                                        break
                        if sky_b > 0:
                                raw_light[Vector2i(x, y)] = sky_b
                                queue.append(Vector2i(x, y))

        # Add tile light sources
        for s in sources:
                var pos: Vector2i = s.pos
                var l: int = s.light
                if l > raw_light.get(pos, 0):
                        raw_light[pos] = l
                        queue.append(pos)

        # BFS propagation
        var idx := 0
        while idx < queue.size():
                var pos: Vector2i = queue[idx]
                idx += 1
                var cur: int = raw_light[pos]
                if cur <= 1:
                        continue
                for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                        var nx: int = pos.x + dir.x
                        var ny: int = pos.y + dir.y
                        if nx < ax0 or nx > ax1 or ny < ay0 or ny > ay1:
                                continue
                        var t: int = tile_map.get_tile(nx, ny)
                        var decrease := 1
                        if WorldData.is_solid(t) and not WorldData.is_platform(t):
                                decrease = 2
                        var new_light: int = cur - decrease
                        var cur_n: int = raw_light.get(Vector2i(nx, ny), 0)
                        if new_light > cur_n:
                                raw_light[Vector2i(nx, ny)] = new_light
                                queue.append(Vector2i(nx, ny))

        # Update light_grid from raw_light (set value, don't just increase)
        for pos in raw_light:
                var lx := int(pos.x / LIGHT_CELL_SIZE)
                var ly := int(pos.y / LIGHT_CELL_SIZE)
                if lx < 0 or lx >= light_grid_w or ly < 0 or ly >= light_grid_h:
                        continue
                var dark: int = 15 - raw_light[pos]
                if dark < light_grid[ly][lx]:
                        light_grid[ly][lx] = dark



# === Public tile API ===
func get_tile(tx: int, ty: int) -> int:
        return tile_map.get_tile(tx, ty)


func set_tile(tx: int, ty: int, tile_id: int) -> void:
        tile_map.set_tile(tx, ty, tile_id)


func get_wall(tx: int, ty: int) -> int:
        return tile_map.get_wall(tx, ty)


func set_wall(tx: int, ty: int, wall_id: int) -> void:
        tile_map.set_wall(tx, ty, wall_id)


func is_solid_at_tile(tx: int, ty: int) -> bool:
        return tile_map.is_solid_at(tx, ty)


func is_platform_at_tile(tx: int, ty: int) -> bool:
        return tile_map.is_platform_at(tx, ty)


## Check if a world-space AABB collides with solid tiles
func check_aabb_collision(world_rect: Rect2, ignore_platforms: bool = false) -> bool:
        var tx0 := int(world_rect.position.x / WorldData.TILE_SIZE)
        var ty0 := int(world_rect.position.y / WorldData.TILE_SIZE)
        var tx1 := int((world_rect.position.x + world_rect.size.x) / WorldData.TILE_SIZE)
        var ty1 := int((world_rect.position.y + world_rect.size.y) / WorldData.TILE_SIZE)
        for ty in range(ty0, ty1 + 1):
                for tx in range(tx0, tx1 + 1):
                        if tile_map.is_solid_at(tx, ty):
                                return true
                        if not ignore_platforms and tile_map.is_platform_at(tx, ty):
                                return true
        return false


## Returns the hardness (mine time divisor) of the tile at the given position
func get_tile_hardness_at(tx: int, ty: int) -> float:
        return WorldData.tile_hardness(get_tile(tx, ty))


## Returns true if the tile is mineable with the given tool type and tier
func can_mine_tile(tile_id: int, tool_type: String, tool_tier: int) -> bool:
        var props: Dictionary = WorldData.TILE_PROPERTIES.get(tile_id, {})
        if not props.get("mineable", false):
                return false
        var required_tool: String = props.get("tool", "any")
        if required_tool == "any":
                return true
        if required_tool != tool_type and tool_type != "any":
                return false
        var min_tier: int = props.get("min_tier", 0)
        return tool_tier >= min_tier


## Check for nearby crafting stations
func get_nearby_stations(world_pos: Vector2, radius: float = 80.0) -> Array:
        var stations: Array = []
        var center_tx := int(world_pos.x / WorldData.TILE_SIZE)
        var center_ty := int(world_pos.y / WorldData.TILE_SIZE)
        var r := int(radius / WorldData.TILE_SIZE) + 1
        for ty in range(center_ty - r, center_ty + r + 1):
                for tx in range(center_tx - r, center_tx + r + 1):
                        var t: int = get_tile(tx, ty)
                        match t:
                                WorldData.Tile.WORKBENCH:
                                        if not stations.has("workbench"):
                                                stations.append("workbench")
                                WorldData.Tile.CHEST:
                                        if not stations.has("chest"):
                                                stations.append("chest")
        return stations


func _process(delta: float) -> void:
        # Redraw sky background
        queue_redraw()
        # Spawn enemies
        _spawn_check(delta)


func _draw() -> void:
        # Draw sky background (changes with time of day)
        var sky_color: Color = Color(0.45, 0.65, 0.95)  # Day sky
        if GameManager:
                var darkness := GameManager.darkness_factor()
                sky_color = sky_color.lerp(Color(0.05, 0.05, 0.15), darkness)
        # Draw a large rect covering the visible area
        var view_rect: Rect2 = get_viewport_rect()
        var canvas_transform := get_canvas_transform()
        var origin := canvas_transform.get_origin()
        var scale_v := canvas_transform.get_scale()
        view_rect = Rect2(-origin / scale_v, view_rect.size / scale_v)
        draw_rect(view_rect, sky_color)


# === Spawn enemies ===
func _spawn_check(delta: float) -> void:
        if boss_active:
                return  # Don't spawn regular enemies during boss fight
        spawn_timer += delta
        if spawn_timer < SPAWN_CHECK_INTERVAL:
                return
        spawn_timer = 0.0

        if enemies.size() >= MAX_ENEMIES:
                return

        if not GameManager.player:
                return

        var player: Node = GameManager.player
        var ppos: Vector2 = player.global_position

        # Determine spawn position - offscreen but near player
        var angle := randf() * TAU
        var dist := 350.0 + randf() * 150.0  # Offscreen
        var spawn_pos := ppos + Vector2(cos(angle), sin(angle) * 0.5) * dist

        # For surface spawning, prefer above ground
        var tile_x := int(spawn_pos.x / WorldData.TILE_SIZE)
        if tile_x < 5 or tile_x >= WorldData.WORLD_WIDTH - 5:
                return

        # Find a valid spawn tile
        var spawn_y := -1
        # Try surface first
        if GameManager.is_night():
                # At night, spawn surface enemies (zombies, demon eyes)
                for ty in range(max(0, WorldData.SURFACE_LEVEL - 30), min(WorldData.WORLD_HEIGHT, WorldData.SURFACE_LEVEL + 5)):
                        if tile_map.is_solid_at(tile_x, ty) and not tile_map.is_solid_at(tile_x, ty - 1) and not tile_map.is_solid_at(tile_x, ty - 2):
                                spawn_y = ty - 2
                                break
                if spawn_y >= 0:
                        # Pick enemy based on biome
                        var biome := _get_biome_at(tile_x, spawn_y)
                        var enemy_type := "zombie"
                        if randf() < 0.4:
                                enemy_type = "demon_eye"
                        if biome == 1 and randf() < 0.5:
                                enemy_type = "eater_of_souls"
                        _spawn_enemy(enemy_type, Vector2(tile_x * WorldData.TILE_SIZE, spawn_y * WorldData.TILE_SIZE))
        else:
                # Day - spawn slimes on surface, or underground enemies
                if randf() < 0.5:
                        # Surface slime
                        for ty in range(max(0, WorldData.SURFACE_LEVEL - 30), min(WorldData.WORLD_HEIGHT, WorldData.SURFACE_LEVEL + 5)):
                                if tile_map.is_solid_at(tile_x, ty) and not tile_map.is_solid_at(tile_x, ty - 1) and not tile_map.is_solid_at(tile_x, ty - 2):
                                        spawn_y = ty - 2
                                        break
                        if spawn_y >= 0:
                                var enemy_type := "blue_slime"
                                var r := randf()
                                if r < 0.7:
                                        enemy_type = "blue_slime"
                                else:
                                        enemy_type = "green_slime"
                                _spawn_enemy(enemy_type, Vector2(tile_x * WorldData.TILE_SIZE, spawn_y * WorldData.TILE_SIZE))
                else:
                        # Underground - spawn near player if underground
                        if ppos.y > WorldData.SURFACE_LEVEL * WorldData.TILE_SIZE:
                                var uty := int(ppos.y / WorldData.TILE_SIZE) + randi_range(-10, 10)
                                var utx := int(ppos.x / WorldData.TILE_SIZE) + randi_range(-15, 15)
                                if utx > 5 and utx < WorldData.WORLD_WIDTH - 5 and uty > WorldData.UNDERGROUND_LEVEL and uty < WorldData.WORLD_HEIGHT - 5:
                                        # Find air pocket
                                        for dy in range(-5, 6):
                                                if not tile_map.is_solid_at(utx, uty + dy) and tile_map.is_solid_at(utx, uty + dy + 1):
                                                        spawn_y = uty + dy
                                                        break
                                        if spawn_y >= 0:
                                                var biome := _get_biome_at(utx, spawn_y)
                                                var enemy_type := "blue_slime"
                                                if biome == 1:
                                                        enemy_type = "eater_of_souls"
                                                _spawn_enemy(enemy_type, Vector2(utx * WorldData.TILE_SIZE, spawn_y * WorldData.TILE_SIZE))


func _get_biome_at(tx: int, ty: int) -> int:
        if world_data.has("biomes") and ty >= 0 and ty < world_data.biomes.size():
                var row: Array = world_data.biomes[ty]
                if tx >= 0 and tx < row.size():
                        return row[tx]
        return 0


func _spawn_enemy(enemy_type: String, pos: Vector2) -> void:
        # Load enemy scene and spawn
        var scene_path := "res://scenes/enemies/%s.tscn" % enemy_type
        if not ResourceLoader.exists(scene_path):
                print("[World] Enemy scene not found: ", scene_path)
                return
        var scene := load(scene_path)
        var enemy: Node = scene.instantiate()
        enemy.global_position = pos
        add_child(enemy)
        enemies.append(enemy)
        # Connect to death signal to remove from list
        if enemy.has_signal("died"):
                enemy.died.connect(func(): enemies.erase(enemy))
        print("[World] Spawned ", enemy_type, " at ", pos)


# === Boss ===
func summon_boss(boss_type: String, pos: Vector2) -> void:
        if boss_active:
                return
        var scene_path := "res://scenes/enemies/%s.tscn" % boss_type
        if not ResourceLoader.exists(scene_path):
                print("[World] Boss scene not found: ", scene_path)
                return
        var scene := load(scene_path)
        boss = scene.instantiate()
        boss.global_position = pos
        add_child(boss)
        boss_active = true
        if boss.has_signal("died"):
                boss.died.connect(func(): 
                        boss_active = false
                        boss = null
                        print("[World] Boss defeated!")
                )
        print("[World] Boss summoned: ", boss_type)


# === Item drops ===
func spawn_item_drop(item_id: String, count: int, pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
        var scene: Resource = load("res://scenes/world/ItemDrop.tscn")
        var drop: Node = scene.instantiate()
        drop.item_id = item_id
        drop.count = count
        drop.global_position = pos
        if drop.has_method("set_initial_velocity"):
                drop.set_initial_velocity(velocity)
        add_child(drop)
        item_drops.append(drop)
        if drop.has_signal("picked_up"):
                drop.picked_up.connect(func(): item_drops.erase(drop))
