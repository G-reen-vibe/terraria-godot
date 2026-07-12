extends Node2D
## Test scene: spawn player in world and run for a few seconds

var world: Node = null
var player: Node = null
var test_step: int = 0
var test_timer: float = 0.0

func _ready() -> void:
    print("=== TestPlayer ===")
    var world_scene := load("res://scenes/world/World.tscn")
    world = world_scene.instantiate()
    world.world_loaded.connect(_on_world_loaded)
    add_child(world)


func _on_world_loaded() -> void:
    print("World loaded, spawning player...")
    var player_scene := load("res://scenes/player/Player.tscn")
    player = player_scene.instantiate()
    player.global_position = world.spawn_point
    world.add_child(player)  # Add to world so player can find world parent
    print("Player spawned at ", player.global_position)

    # Run tests
    set_process(true)


func _process(delta: float) -> void:
    if not player:
        return
    test_timer += delta
    # Periodically print player state
    if int(test_timer * 2) > test_step:
        test_step = int(test_timer * 2)
        print("t=%.1f pos=%s vel=%s hp=%d/%d selected=%s" % [
            test_timer,
            player.global_position,
            player.velocity,
            player.health, player.max_health,
            player.get_selected_item()
        ])
        # Print tile under player
        var tile := WorldData.world_to_tile_pos(player.global_position)
        print("  tile_under: ", world.get_tile(tile.x, tile.y + 1))
    if test_timer > 5.0:
        print("=== TestPlayer DONE ===")
        get_tree().quit()
