extends Node2D
## Test scene: load the world and print stats

var world: Node = null

func _ready() -> void:
    print("=== TestWorld ===")
    # Load world scene
    var world_scene := load("res://scenes/world/World.tscn")
    world = world_scene.instantiate()
    # Connect to signal BEFORE adding to scene tree
    world.world_loaded.connect(_on_world_loaded)
    add_child(world)


func _on_world_loaded() -> void:
    print("World loaded!")
    print("Spawn: ", world.spawn_point)
    # Sample some tiles
    var spawn_tile := WorldData.world_to_tile_pos(world.spawn_point)
    print("Spawn tile: ", spawn_tile)
    for dy in range(-5, 6):
        var row := ""
        for dx in range(-10, 11):
            var t: int = world.get_tile(spawn_tile.x + dx, spawn_tile.y + dy)
            row += str(t) + " "
        print(row)
    # Test that some ores exist
    var ore_counts := {1: 0, 2: 0, 3: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0}
    for y in range(WorldData.SURFACE_LEVEL, WorldData.WORLD_HEIGHT, 4):
        for x in range(0, WorldData.WORLD_WIDTH, 4):
            var t: int = world.get_tile(x, y)
            if ore_counts.has(t):
                ore_counts[t] += 1
    print("Ore counts (sampled): ", ore_counts)
    # Test lighting
    var light_sample: int = world.light_grid[10][10] if world.light_grid.size() > 10 else -1
    print("Light at (10,10): ", light_sample)
    print("=== TestWorld DONE ===")
    await get_tree().create_timer(0.5).timeout
    get_tree().quit()
